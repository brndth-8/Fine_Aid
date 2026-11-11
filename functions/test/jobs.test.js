// Emulator tests for lib/jobs.js (deactivation + scheduled notifications).
//   cd functions && npm test
const { test, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  admin,
  db,
  auth,
  resetEmulators,
  makeAdmin,
  makeAdminWithoutClaim,
  asNonAdmin,
  makeUser,
  collectionDocs,
  expectCode,
  signIn,
} = require("./helpers");
const jobs = require("../lib/jobs");

const Timestamp = admin.firestore.Timestamp;
const NOW = Date.now();
const HOUR = 60 * 60 * 1000;

beforeEach(resetEmulators);

const notices = (uid) => collectionDocs(`users/${uid}/notifications`);
const audits = () => collectionDocs("auditLogs");

//admin checks 

test("a signed-out caller is rejected", async () => {
  await expectCode(jobs.requireAdmin(db, {}), "unauthenticated");
});

test("a signed-in non-admin is rejected by every admin function", async () => {
  await makeUser("u1");
  const request = asNonAdmin();
  await expectCode(
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
    "permission-denied"
  );
  await expectCode(
    jobs.cancelDeactivation({ db, request, uid: "u1" }),
    "permission-denied"
  );
  await expectCode(
    jobs.reactivateAccount({ db, auth, request, uid: "u1" }),
    "permission-denied"
  );
  await expectCode(
    jobs.cancelScheduledNotification({ db, request, notificationId: "n1" }),
    "permission-denied"
  );
  assert.equal((await notices("u1")).length, 0);
  assert.equal((await audits()).length, 0);
});

//schedule deactivation 

test("schedule: notifies first, schedules, and logs, all together", async () => {
  const request = await makeAdmin();
  await makeUser("u1");

  const res = await jobs.scheduleDeactivation({ db, request, uid: "u1", nowMs: NOW });
  assert.equal(res.alreadyScheduled, false);

  const user = (await db.doc("users/u1").get()).data();
  assert.equal(
    user.deactivateAt.toMillis(),
    NOW + jobs.DEACTIVATION_GRACE_DAYS * 24 * HOUR
  );
  assert.equal(user.deactivationRequestedBy, "admin1");

  const n = await notices("u1");
  assert.equal(n.length, 1);
  assert.equal(n[0].title, "Your account will be deactivated");

  const logs = await audits();
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorUid, "admin1");
  assert.equal(logs[0].actorName, "Test Admin");
  assert.equal(logs[0].targetId, "u1");
  assert.equal(logs[0].result, "success");
});

test("schedule: a repeat or simultaneous call sends only one notice", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  await Promise.all([
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
  ]);
  const again = await jobs.scheduleDeactivation({ db, request, uid: "u1" });
  assert.equal(again.alreadyScheduled, true);
  assert.equal((await notices("u1")).length, 1);
  assert.equal((await audits()).length, 1);
});

test("schedule: if the notice fails, nothing is scheduled and the admin gets a clear error", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  const err = await expectCode(
    jobs.scheduleDeactivation({
      db,
      request,
      uid: "u1",
      writeNotice: () => {
        throw new Error("simulated notice failure");
      },
    }),
    "internal"
  );
  assert.match(err.message, /nothing was scheduled/);
  const user = (await db.doc("users/u1").get()).data();
  assert.equal(user.deactivateAt, undefined);
  assert.equal((await notices("u1")).length, 0);
  assert.equal((await audits()).length, 0);
});

test("schedule: already-deactivated and missing users are refused", async () => {
  const request = await makeAdmin();
  await makeUser("u1", { deactivated: true });
  await expectCode(
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
    "failed-precondition"
  );
  await expectCode(
    jobs.scheduleDeactivation({ db, request, uid: "ghost" }),
    "not-found"
  );
});

//cancel deactivation

test("cancel: removes the schedule, tells the user, and logs it", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  await jobs.scheduleDeactivation({ db, request, uid: "u1" });

  const res = await jobs.cancelDeactivation({ db, request, uid: "u1" });
  assert.equal(res.cancelled, true);
  const user = (await db.doc("users/u1").get()).data();
  assert.equal(user.deactivateAt, undefined);
  assert.equal((await notices("u1")).length, 2);
  assert.equal((await audits()).length, 2);

  const again = await jobs.cancelDeactivation({ db, request, uid: "u1" });
  assert.equal(again.cancelled, false);
});

//the hourly sweep

async function scheduleInPast(uid, request) {
  await jobs.scheduleDeactivation({
    db,
    request,
    uid,
    nowMs: NOW - (jobs.DEACTIVATION_GRACE_DAYS * 24 + 1) * HOUR,
  });
}

test("sweep: disables the Auth account, flags the profile, logs once, and the user cannot sign in", async () => {
  const request = await makeAdmin();
  await makeUser("u1", {}, { withAuth: true });
  assert.equal((await signIn("u1@fineaid.app", "Passw0rd!x")).ok, true);
  await scheduleInPast("u1", request);

  const res = await jobs.processDueDeactivations({ db, auth, nowMs: NOW });
  assert.equal(res.deactivated, 1);

  assert.equal((await auth.getUser("u1")).disabled, true);
  const user = (await db.doc("users/u1").get()).data();
  assert.equal(user.deactivated, true);
  assert.equal(user.deactivateAt, undefined);
  assert.ok(user.deactivatedAt);

  const attempt = await signIn("u1@fineaid.app", "Passw0rd!x");
  assert.equal(attempt.ok, false);
  assert.match(attempt.body.error.message, /USER_DISABLED/);

  const logs = (await audits()).filter((l) => l.reason === "grace_period_elapsed");
  assert.equal(logs.length, 1);
});

test("sweep: safe to run twice, and leaves accounts that are not due alone", async () => {
  const request = await makeAdmin();
  await makeUser("due", {}, { withAuth: true });
  await makeUser("later", {}, { withAuth: true });
  await scheduleInPast("due", request);
  await jobs.scheduleDeactivation({ db, request, uid: "later", nowMs: NOW });

  await jobs.processDueDeactivations({ db, auth, nowMs: NOW });
  const second = await jobs.processDueDeactivations({ db, auth, nowMs: NOW });
  assert.equal(second.deactivated, 0);

  const logs = (await audits()).filter((l) => l.reason === "grace_period_elapsed");
  assert.equal(logs.length, 1);
  assert.equal((await auth.getUser("later")).disabled, false);
  assert.equal((await db.doc("users/later").get()).data().deactivated, undefined);
});

test("sweep: a cancelled deactivation is not carried out", async () => {
  const request = await makeAdmin();
  await makeUser("u1", {}, { withAuth: true });
  await scheduleInPast("u1", request);
  await jobs.cancelDeactivation({ db, request, uid: "u1" });

  await jobs.processDueDeactivations({ db, auth, nowMs: NOW });
  assert.equal((await auth.getUser("u1")).disabled, false);
  assert.equal((await db.doc("users/u1").get()).data().deactivated, undefined);
});

test("sweep: one failing account does not stop the others", async () => {
  const request = await makeAdmin();
  await makeUser("bad", {}, { withAuth: true });
  await makeUser("good", {}, { withAuth: true });
  await scheduleInPast("bad", request);
  await scheduleInPast("good", request);

  const flaky = {
    updateUser: (uid, props) => {
      if (uid === "bad") return Promise.reject(new Error("auth outage"));
      return auth.updateUser(uid, props);
    },
    revokeRefreshTokens: (uid) => auth.revokeRefreshTokens(uid),
  };
  const res = await jobs.processDueDeactivations({ db, auth: flaky, nowMs: NOW });
  assert.equal(res.failed, 1);
  assert.equal(res.deactivated, 1);
  assert.equal((await auth.getUser("good")).disabled, true);
  // The failed one is still pending (retried next run), not half-done.
  const bad = (await db.doc("users/bad").get()).data();
  assert.ok(bad.deactivateAt);
  assert.equal(bad.deactivated, undefined);
});

test("reactivate: re-enables sign-in and clears the flags", async () => {
  const request = await makeAdmin();
  await makeUser("u1", {}, { withAuth: true });
  await scheduleInPast("u1", request);
  await jobs.processDueDeactivations({ db, auth, nowMs: NOW });

  await jobs.reactivateAccount({ db, auth, request, uid: "u1" });
  assert.equal((await auth.getUser("u1")).disabled, false);
  const user = (await db.doc("users/u1").get()).data();
  assert.equal(user.deactivated, false);
  assert.equal((await signIn("u1@fineaid.app", "Passw0rd!x")).ok, true);
});

//scheduled notifications

function fakeMessaging({ failTimes = 0, deadTokens = [], multicastDown = false } = {}) {
  const sent = [];
  const multicasts = [];
  let failures = failTimes;
  return {
    sent,
    multicasts,
    send: async (message) => {
      if (failures > 0) {
        failures--;
        throw new Error("fcm down");
      }
      sent.push(message);
    },
    // Push to specific devices: tokens listed in deadTokens come back as
    // "not registered", the way FCM answers for an expired token.
    sendEachForMulticast: async (message) => {
      if (multicastDown) throw new Error("fcm down");
      multicasts.push(message);
      return {
        responses: message.tokens.map((t) =>
          deadTokens.includes(t)
            ? {
                success: false,
                error: { code: "messaging/registration-token-not-registered" },
              }
            : { success: true }
        ),
      };
    },
  };
}

async function addNotification(status, minutesFromNow, extra = {}) {
  const ref = await db.collection("systemNotifications").add({
    title: "Reminder",
    body: "Hello",
    status,
    scheduledFor: Timestamp.fromMillis(NOW + minutesFromNow * 60 * 1000),
    ...extra,
  });
  return ref.id;
}

test("notifications: a due one is sent exactly once, even across repeated runs", async () => {
  const id = await addNotification("scheduled", -1);
  const messaging = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });

  assert.equal(messaging.sent.length, 1);
  // Announcements are broadcast to the "all_users" topic by design.
  assert.equal(messaging.sent[0].topic, "all_users");
  const doc = (await db.doc(`systemNotifications/${id}`).get()).data();
  assert.equal(doc.status, "sent");
  assert.ok(doc.sentAt);
});

test("notifications: overlapping runs do not double-send", async () => {
  await addNotification("scheduled", -1);
  const messaging = fakeMessaging();
  await Promise.all([
    jobs.processDueNotifications({ db, messaging, nowMs: NOW }),
    jobs.processDueNotifications({ db, messaging, nowMs: NOW }),
  ]);
  assert.equal(messaging.sent.length, 1);
});

test("notifications: future ones wait, cancelled ones never send", async () => {
  const future = await addNotification("scheduled", 60);
  const request = await makeAdmin();
  const due = await addNotification("scheduled", -1);
  await jobs.cancelScheduledNotification({ db, request, notificationId: due });

  const messaging = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  assert.equal(messaging.sent.length, 0);
  assert.equal((await db.doc(`systemNotifications/${future}`).get()).data().status, "scheduled");

  const cancelled = (await db.doc(`systemNotifications/${due}`).get()).data();
  assert.equal(cancelled.status, "cancelled");
  assert.equal(cancelled.cancelledBy, "admin1");
  assert.ok(cancelled.cancelledAt);
  assert.ok(cancelled.title, "the record is kept, not deleted");
});

test("cancel notification: only pending ones, and only once", async () => {
  const request = await makeAdmin();
  const pending = await addNotification("scheduled", 30);
  await jobs.cancelScheduledNotification({ db, request, notificationId: pending });
  await expectCode(
    jobs.cancelScheduledNotification({ db, request, notificationId: pending }),
    "failed-precondition"
  );
  const sent = await addNotification("sent", -5);
  const err = await expectCode(
    jobs.cancelScheduledNotification({ db, request, notificationId: sent }),
    "failed-precondition"
  );
  assert.match(err.message, /already been sent/);
  await expectCode(
    jobs.cancelScheduledNotification({ db, request, notificationId: "ghost" }),
    "not-found"
  );
  const logs = (await audits()).filter((l) => l.reason === "cancelled_before_send");
  assert.equal(logs.length, 1);
});

test("notifications race: cancel and send at the same moment never do both", async () => {
  const request = await makeAdmin();
  for (let i = 0; i < 5; i++) {
    const id = await addNotification("scheduled", -1);
    const messaging = fakeMessaging();
    const [cancel] = await Promise.allSettled([
      jobs.cancelScheduledNotification({ db, request, notificationId: id }),
      jobs.processDueNotifications({ db, messaging, nowMs: NOW }),
    ]);
    const status = (await db.doc(`systemNotifications/${id}`).get()).data().status;
    if (cancel.status === "fulfilled") {
      assert.equal(status, "cancelled");
      assert.equal(messaging.sent.length, 0, "cancelled yet still sent");
    } else {
      assert.equal(status, "sent");
      assert.equal(messaging.sent.length, 1);
    }
    await db.doc(`systemNotifications/${id}`).delete();
  }
});

test("notifications: a failed push is retried, then marked failed after 3 tries", async () => {
  const id = await addNotification("scheduled", -1);
  const messaging = fakeMessaging({ failTimes: 99 });
  for (let i = 0; i < 4; i++) {
    await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  }
  const doc = (await db.doc(`systemNotifications/${id}`).get()).data();
  assert.equal(doc.status, "failed");
  assert.equal(doc.sendAttempts, 3);
  assert.equal(messaging.sent.length, 0);
});

test("notifications: a claim that never finished is marked failed, not re-sent", async () => {
  const id = await addNotification("sending", -60, {
    claimedAt: Timestamp.fromMillis(NOW - 30 * 60 * 1000),
  });
  const messaging = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  const doc = (await db.doc(`systemNotifications/${id}`).get()).data();
  assert.equal(doc.status, "failed");
  assert.equal(doc.failedReason, "interrupted");
  assert.equal(messaging.sent.length, 0);
});

// ---- the admin role needs the claim AND the admins document ----------------

test("a listed admin whose token lacks the admin claim is told to refresh", async () => {
  const request = await makeAdminWithoutClaim();
  await makeUser("u1");
  const err = await expectCode(
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
    "permission-denied"
  );
  assert.match(err.message, /sign out and sign in again/);
  assert.equal((await notices("u1")).length, 0);
});

test("the admin claim without an admins document is refused", async () => {
  const request = { auth: { uid: "ghost-admin", token: { admin: true } } };
  await makeUser("u1");
  const err = await expectCode(
    jobs.scheduleDeactivation({ db, request, uid: "u1" }),
    "permission-denied"
  );
  assert.match(err.message, /Only admins/);
});

// ---- admin sign-in events in the audit log -----------------------------------

const loginLogs = async () =>
  (await audits()).filter((l) => l.type === "LOGIN");

test("sign-in: an admin's sign-in is logged as a success, with their name", async () => {
  const request = await makeAdmin();
  await jobs.recordAdminSignIn({ db, request });
  const [entry] = await loginLogs();
  assert.equal(entry.action, "Admin signed in");
  assert.equal(entry.result, "success");
  assert.equal(entry.actorUid, "admin1");
  assert.equal(entry.actorName, "Test Admin");
});

test("sign-in: a normal user who reaches the portal is logged as refused", async () => {
  await makeUser("u1");
  await jobs.recordAdminSignIn({ db, request: asNonAdmin("u1") });
  const [entry] = await loginLogs();
  assert.equal(entry.result, "failure");
  assert.equal(entry.reason, "not_an_admin");
  assert.equal(entry.actorUid, "u1");
});

test("sign-in: an admin whose token has no claim is logged as claim_missing", async () => {
  const request = await makeAdminWithoutClaim();
  await jobs.recordAdminSignIn({ db, request });
  const [entry] = await loginLogs();
  assert.equal(entry.result, "failure");
  assert.equal(entry.reason, "claim_missing");
});

test("sign-in: the outcome comes from the server, and signed-out callers are rejected", async () => {
  await expectCode(jobs.recordAdminSignIn({ db, request: {} }), "unauthenticated");
  assert.equal((await loginLogs()).length, 0);
});

test("sign-in: repeated calls inside a few seconds log only once", async () => {
  const request = await makeAdmin();
  await jobs.recordAdminSignIn({ db, request, nowMs: NOW });
  await jobs.recordAdminSignIn({ db, request, nowMs: NOW + 1000 });
  assert.equal((await loginLogs()).length, 1);
  await jobs.recordAdminSignIn({ db, request, nowMs: NOW + 10000 });
  assert.equal((await loginLogs()).length, 2);
});

async function adminWithAuthAccount() {
  await makeAdmin("admin1");
  await auth.createUser({ uid: "admin1", email: "admin1@example.com", password: "Passw0rd!x" });
  await makeUser("plain", {}, { withAuth: true });
}

test("failed sign-in: logged for an admin's email, with the reason", async () => {
  await adminWithAuthAccount();
  const res = await jobs.recordAdminSignInFailure({
    db,
    auth,
    data: { email: "  Admin1@Example.com ", reason: "wrong_password" },
  });
  assert.deepEqual(res, { ok: true });
  const [entry] = await loginLogs();
  assert.equal(entry.action, "Failed admin sign-in attempt");
  assert.equal(entry.result, "failure");
  assert.equal(entry.reason, "wrong_password");
  assert.equal(entry.actorUid, "admin1");
});

test("failed sign-in: unknown emails and non-admins leave no trace and look identical", async () => {
  await adminWithAuthAccount();
  const unknown = await jobs.recordAdminSignInFailure({ db, auth, data: { email: "nobody@example.com" } });
  const nonAdmin = await jobs.recordAdminSignInFailure({ db, auth, data: { email: "plain@fineaid.app" } });
  const junk = await jobs.recordAdminSignInFailure({ db, auth, data: { email: 42 } });
  assert.deepEqual(unknown, { ok: true });
  assert.deepEqual(nonAdmin, { ok: true });
  assert.deepEqual(junk, { ok: true });
  assert.equal((await loginLogs()).length, 0);
});

test("failed sign-in: at most one entry per admin every 30 seconds", async () => {
  await adminWithAuthAccount();
  const data = { email: "admin1@example.com" };
  for (let i = 0; i < 5; i++) {
    await jobs.recordAdminSignInFailure({ db, auth, data, nowMs: NOW + i * 1000 });
  }
  assert.equal((await loginLogs()).length, 1);
  await jobs.recordAdminSignInFailure({ db, auth, data, nowMs: NOW + 40000 });
  assert.equal((await loginLogs()).length, 2);
});

// ---- security settings (idle timeout) ----------------------------------------

const settingsDoc = async () => (await db.doc("adminSettings/security").get()).data();

test("security settings: an admin saves the switch and minutes, and it is audit-logged", async () => {
  const request = await makeAdmin();
  const res = await jobs.updateSecuritySettings({
    db,
    request,
    data: { idleTimeoutEnabled: false, idleTimeoutMinutes: 30 },
  });
  assert.equal(res.idleTimeoutEnabled, false);
  assert.equal(res.idleTimeoutMinutes, 30);
  // The lockout setting wasn't sent, so it still reports its default.
  assert.equal(res.lockoutEnabled, true);
  assert.equal(res.lockoutMaxAttempts, 5);
  const saved = await settingsDoc();
  assert.equal(saved.idleTimeoutEnabled, false);
  assert.equal(saved.idleTimeoutMinutes, 30);
  assert.equal(saved.updatedBy, "admin1");
  const logs = (await audits()).filter((l) => l.targetId === "idleTimeout");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, "Idle session timeout turned off");
  assert.equal(logs[0].actorUid, "admin1");
});

test("security settings: turning it back on reads back correctly (persists)", async () => {
  const request = await makeAdmin();
  await jobs.updateSecuritySettings({ db, request, data: { idleTimeoutEnabled: false, idleTimeoutMinutes: 15 } });
  await jobs.updateSecuritySettings({ db, request, data: { idleTimeoutEnabled: true, idleTimeoutMinutes: 10 } });
  const saved = await settingsDoc();
  assert.equal(saved.idleTimeoutEnabled, true);
  assert.equal(saved.idleTimeoutMinutes, 10);
  const logs = (await audits()).filter((l) => l.targetId === "idleTimeout");
  assert.equal(logs.length, 2);
});

test("security settings: invalid values are refused and nothing is written", async () => {
  const request = await makeAdmin();
  for (const data of [
    { idleTimeoutEnabled: "yes", idleTimeoutMinutes: 15 },
    { idleTimeoutEnabled: true, idleTimeoutMinutes: 7 },
    { idleTimeoutEnabled: true, idleTimeoutMinutes: "15" },
    { idleTimeoutEnabled: true },
    null,
  ]) {
    await expectCode(jobs.updateSecuritySettings({ db, request, data }), "invalid-argument");
  }
  assert.equal(await settingsDoc(), undefined);
  assert.equal((await audits()).length, 0);
});

test("security settings: only admins can change them", async () => {
  const data = { idleTimeoutEnabled: false, idleTimeoutMinutes: 15 };
  await expectCode(jobs.updateSecuritySettings({ db, request: asNonAdmin(), data }), "permission-denied");
  const noClaim = await makeAdminWithoutClaim();
  await expectCode(jobs.updateSecuritySettings({ db, request: noClaim, data }), "permission-denied");
  await expectCode(jobs.updateSecuritySettings({ db, request: {}, data }), "unauthenticated");
  assert.equal(await settingsDoc(), undefined);
});

// ---- editing a user's profile -------------------------------------------------

async function seedProfile(uid, extra = {}) {
  await db.doc(`users/${uid}`).set({
    username: uid,
    email: `${uid}@fineaid.app`,
    firstName: "Old",
    lastName: "Name",
    phoneNumber: "+639171234567",
    underageAcknowledged: true,
    ...extra,
  });
  await db.doc(`usernames/${uid}`).set({ email: `${uid}@fineaid.app`, uid, usernameExact: uid });
}

const edit = (request, uid, changes) =>
  jobs.updateUserProfile({ db, request, data: { uid, changes } });

test("profile edit: changes only what was sent, stamps updatedAt, logs field names not values", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  const res = await edit(request, "u1", { firstName: "Juan", lastName: "Dela Cruz", gender: "male", phone: "0917 765 4321" });
  assert.deepEqual(res.updated.sort(), ["firstName", "gender", "lastName", "phoneNumber"]);
  const user = (await db.doc("users/u1").get()).data();
  assert.equal(user.firstName, "Juan");
  assert.equal(user.phoneNumber, "+639177654321");
  assert.equal(user.underageAcknowledged, true, "read-only fields untouched");
  assert.ok(user.updatedAt);
  const logs = (await audits()).filter((l) => l.reason && l.reason.startsWith("fields:"));
  assert.equal(logs.length, 1);
  assert.ok(!JSON.stringify(logs[0]).includes("Dela Cruz"), "values must not be logged");
});

test("profile edit: an unchanged save writes nothing", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  const res = await edit(request, "u1", { firstName: "Old", username: "u1" });
  assert.deepEqual(res.updated, []);
  assert.equal((await audits()).length, 0);
});

test("profile edit: invalid values are refused", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  for (const changes of [
    { firstName: "J0hn" },
    { lastName: "" },
    { username: "ab" },
    { username: "bad name!" },
    { gender: "robot" },
    { phone: "12345" },
    { email: "not-an-email" },
    { dateOfBirthMs: Date.now() + 86400000 },
    { dateOfBirthMs: "yesterday" },
  ]) {
    await expectCode(edit(request, "u1", changes), "invalid-argument");
  }
  assert.equal((await db.doc("users/u1").get()).data().firstName, "Old");
});

test("profile edit: renaming moves the username reservation and frees the old name", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  await edit(request, "u1", { username: "Juan_2" });
  assert.equal((await db.doc("users/u1").get()).data().username, "Juan_2");
  assert.equal((await db.doc("usernames/u1").get()).exists, false);
  const fresh = (await db.doc("usernames/Juan_2").get()).data();
  assert.equal(fresh.uid, "u1");
  assert.equal(fresh.email, "u1@fineaid.app", "sign-in address is unchanged");
  // The old name is free for someone else now.
  await seedProfile("u2");
  await edit(request, "u2", { username: "u1" });
  assert.equal((await db.doc("usernames/u1").get()).data().uid, "u2");
});

test("profile edit: a phone number another account already has is refused", async () => {
  const request = await makeAdmin();
  await seedProfile("u1", { phoneNumber: "+639171111111" });
  await seedProfile("u2", { phoneNumber: "+639172222222" });
  await db.doc("phones/+639171111111").set({ uid: "u1" });
  await db.doc("phones/+639172222222").set({ uid: "u2" });
  await expectCode(edit(request, "u2", { phone: "0917 111 1111" }), "already-exists");
  assert.equal((await db.doc("users/u2").get()).data().phoneNumber, "+639172222222");
});

test("profile edit: changing the phone moves its reservation and frees the old number", async () => {
  const request = await makeAdmin();
  await seedProfile("u1", { phoneNumber: "+639171111111" });
  await db.doc("phones/+639171111111").set({ uid: "u1" });
  await edit(request, "u1", { phone: "+63 917 333 3333" });
  assert.equal((await db.doc("phones/+639171111111").get()).exists, false);
  assert.equal((await db.doc("phones/+639173333333").get()).data().uid, "u1");
  // The freed number can go to someone else.
  await seedProfile("u2", { phoneNumber: "+639174444444" });
  await edit(request, "u2", { phone: "09171111111" });
  assert.equal((await db.doc("phones/+639171111111").get()).data().uid, "u2");
});

test("profile edit: a taken username is refused (exact case and older lower-case records)", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  await seedProfile("u2");
  await expectCode(edit(request, "u1", { username: "u2" }), "already-exists");
  await db.doc("usernames/legacyname").set({ uid: "u2", email: "x@fineaid.app", usernameExact: "LegacyName" });
  await expectCode(edit(request, "u1", { username: "LegacyName" }), "already-exists");
  assert.equal((await db.doc("users/u1").get()).data().username, "u1");
});

test("profile edit: email is stored lower-case, reserved, and cannot duplicate another account's", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  await seedProfile("u2");
  await edit(request, "u1", { email: "  Juan@Example.COM " });
  assert.equal((await db.doc("users/u1").get()).data().recoveryEmail, "juan@example.com");
  assert.equal((await db.doc("emails/juan@example.com").get()).data().uid, "u1");

  await expectCode(edit(request, "u2", { email: "JUAN@example.com" }), "already-exists");
  assert.equal((await db.doc("users/u2").get()).data().recoveryEmail, undefined);

  // Changing it releases the old address for others.
  await edit(request, "u1", { email: "new@example.com" });
  assert.equal((await db.doc("emails/juan@example.com").get()).exists, false);
  await edit(request, "u2", { email: "juan@example.com" });
  assert.equal((await db.doc("emails/juan@example.com").get()).data().uid, "u2");

  // Clearing removes it and frees the reservation.
  await edit(request, "u2", { email: "" });
  assert.equal((await db.doc("users/u2").get()).data().recoveryEmail, undefined);
  assert.equal((await db.doc("emails/juan@example.com").get()).exists, false);
});

test("profile edit: date of birth is saved from a day", async () => {
  const request = await makeAdmin();
  await seedProfile("u1");
  const ms = new Date(2008, 5, 15).getTime();
  await edit(request, "u1", { dateOfBirthMs: ms });
  assert.equal((await db.doc("users/u1").get()).data().dateOfBirth.toMillis(), ms);
});

test("profile edit: only admins, and a missing user is reported", async () => {
  await seedProfile("u1");
  await expectCode(edit(asNonAdmin(), "u1", { firstName: "X" }), "permission-denied");
  await expectCode(edit(await makeAdminWithoutClaim(), "u1", { firstName: "X" }), "permission-denied");
  const request = await makeAdmin();
  await expectCode(edit(request, "ghost", { firstName: "X" }), "not-found");
});

// ---- notification to one user ---------------------------------------------------

test("targeted notice: lands only in that user's private inbox and is audit-logged", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedProfile("maria");
  const res = await jobs.sendNotificationToUser({
    db,
    request,
    data: { username: "juan", title: "Hello Juan", body: "Please update your profile." },
  });
  assert.equal(res.sent, true);
  assert.equal(res.username, "juan");
  assert.equal(res.count, 1);
  const mine = await notices("juan");
  assert.equal(mine.length, 1);
  assert.equal(mine[0].title, "Hello Juan");
  assert.equal(mine[0].read, false);
  assert.equal((await notices("maria")).length, 0, "nobody else gets it");
  assert.equal((await collectionDocs("systemNotifications")).length, 0, "nothing in the public collection");
  const logs = (await audits()).filter((l) => l.reason === "targeted_notification");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].targetName, "juan");
  assert.ok(!JSON.stringify(logs[0]).includes("Please update"), "message text is not logged");
});

test("targeted notice: unknown username, missing title and non-admins are refused", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await expectCode(jobs.sendNotificationToUser({ db, request, data: { username: "nobody", title: "Hi" } }), "not-found");
  await expectCode(jobs.sendNotificationToUser({ db, request, data: { username: "juan", title: "  " } }), "invalid-argument");
  await expectCode(jobs.sendNotificationToUser({ db, request, data: { username: "juan" } }), "invalid-argument");
  await expectCode(
    jobs.sendNotificationToUser({ db, request: asNonAdmin(), data: { username: "juan", title: "Hi" } }),
    "permission-denied"
  );
  assert.equal((await notices("juan")).length, 0);
});

test("security settings: the lockout is saved, mirrored publicly for the sign-in screen, and audit-logged", async () => {
  const request = await makeAdmin();
  const res = await jobs.updateSecuritySettings({
    db,
    request,
    data: { lockoutEnabled: true, lockoutMaxAttempts: 3, lockoutMinutes: 30 },
  });
  assert.equal(res.lockoutMaxAttempts, 3);
  assert.equal(res.lockoutMinutes, 30);
  assert.equal(res.idleTimeoutEnabled, true, "the idle setting is untouched");
  const saved = await settingsDoc();
  assert.equal(saved.lockoutMaxAttempts, 3);
  const mirror = (await db.doc("appConfig/loginSecurity").get()).data();
  assert.deepEqual(
    [mirror.lockoutEnabled, mirror.lockoutMaxAttempts, mirror.lockoutMinutes],
    [true, 3, 30]
  );
  const logs = (await audits()).filter((l) => l.targetId === "loginLockout");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, "Failed login lockout turned on (3 attempts, 30 minutes)");
});

test("security settings: turning the lockout off is saved and logged", async () => {
  const request = await makeAdmin();
  await jobs.updateSecuritySettings({
    db,
    request,
    data: { lockoutEnabled: false, lockoutMaxAttempts: 5, lockoutMinutes: 15 },
  });
  assert.equal((await db.doc("appConfig/loginSecurity").get()).data().lockoutEnabled, false);
  const logs = (await audits()).filter((l) => l.targetId === "loginLockout");
  assert.equal(logs[0].action, "Failed login lockout turned off");
});

test("security settings: both groups at once, and incomplete or invalid lockout values are refused", async () => {
  const request = await makeAdmin();
  await jobs.updateSecuritySettings({
    db,
    request,
    data: {
      idleTimeoutEnabled: false, idleTimeoutMinutes: 15,
      lockoutEnabled: true, lockoutMaxAttempts: 10, lockoutMinutes: 5,
    },
  });
  const saved = await settingsDoc();
  assert.equal(saved.idleTimeoutEnabled, false);
  assert.equal(saved.lockoutMaxAttempts, 10);
  for (const data of [
    { lockoutEnabled: true },
    { lockoutEnabled: true, lockoutMaxAttempts: 4, lockoutMinutes: 15 },
    { lockoutEnabled: true, lockoutMaxAttempts: 5, lockoutMinutes: 7 },
    { lockoutEnabled: "yes", lockoutMaxAttempts: 5, lockoutMinutes: 15 },
  ]) {
    await expectCode(jobs.updateSecuritySettings({ db, request, data }), "invalid-argument");
  }
  await expectCode(
    jobs.updateSecuritySettings({
      db,
      request: asNonAdmin(),
      data: { lockoutEnabled: false, lockoutMaxAttempts: 5, lockoutMinutes: 15 },
    }),
    "permission-denied"
  );
});

// ---- Admin response to feedback ---------------------------------------------

async function seedFeedback(id, fields = {}) {
  await db.doc(`feedback/${id}`).set({
    userId: "u1",
    message: "The app is great but the buttons are small.",
    rating: 4,
    status: "open",
    submittedAt: Timestamp.fromMillis(NOW),
    ...fields,
  });
}

test("feedback response: saved, marked responded, delivered to the user's inbox, audit-logged", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  await db.doc("users/u1").set({ username: "juan" }, { merge: true });
  await seedFeedback("f1");
  const res = await jobs.respondToFeedback({
    db,
    request,
    data: { feedbackId: "f1", response: "Thanks! We are making the buttons bigger." },
  });
  assert.deepEqual(res, { sent: true, delivered: true });

  const fb = (await db.doc("feedback/f1").get()).data();
  assert.equal(fb.response, "Thanks! We are making the buttons bigger.");
  assert.equal(fb.status, "responded");
  assert.equal(fb.respondedBy, "admin1");
  assert.ok(fb.respondedAt, "the response time is kept");

  const mine = await notices("u1");
  assert.equal(mine.length, 1);
  assert.equal(mine[0].title, "Reply to your feedback");
  assert.equal(mine[0].body, "Thanks! We are making the buttons bigger.");
  assert.equal(mine[0].feedbackId, "f1", "linked to the original feedback");
  assert.equal(mine[0].read, false);

  const logs = (await audits()).filter((l) => l.targetId === "f1");
  assert.equal(logs.length, 1);
  assert.ok(!JSON.stringify(logs[0]).includes("buttons bigger"), "the reply text is not logged");
});

test("feedback response: it can only be sent once, and never to a resolved item", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  await seedFeedback("f1");
  await seedFeedback("f2", { status: "resolved" });
  const data = { feedbackId: "f1", response: "First reply." };
  await jobs.respondToFeedback({ db, request, data });
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "f1", response: "Second reply." } }),
    "failed-precondition"
  );
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "f2", response: "Too late." } }),
    "failed-precondition"
  );
  assert.equal((await notices("u1")).length, 1, "the user got exactly one reply");
  assert.equal((await db.doc("feedback/f1").get()).get("response"), "First reply.");
  assert.equal((await db.doc("feedback/f2").get()).get("response"), undefined);
});

test("feedback response: a short reply is fine, a blank or oversized one is refused, non-admins are refused", async () => {
  const request = await makeAdmin();
  await makeUser("u1");
  await seedFeedback("f1");
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "f1", response: "   " } }),
    "invalid-argument"
  );
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "f1", response: "x".repeat(1001) } }),
    "invalid-argument"
  );
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "nope", response: "Hi" } }),
    "not-found"
  );
  await expectCode(
    jobs.respondToFeedback({ db, request: asNonAdmin(), data: { feedbackId: "f1", response: "Hi" } }),
    "permission-denied"
  );
  assert.equal((await db.doc("feedback/f1").get()).get("status"), "open", "nothing was marked sent");
  assert.equal((await notices("u1")).length, 0);
  // A short answer is allowed (no 60-character minimum on the admin side).
  const ok = await jobs.respondToFeedback({ db, request, data: { feedbackId: "f1", response: "Thanks!" } });
  assert.equal(ok.sent, true);
});

test("feedback response: feedback with no account is saved, and the result says nobody was notified", async () => {
  const request = await makeAdmin();
  await seedFeedback("g1", { userId: null });
  const res = await jobs.respondToFeedback({ db, request, data: { feedbackId: "g1", response: "Thanks!" } });
  assert.deepEqual(res, { sent: true, delivered: false });
  assert.equal((await db.doc("feedback/g1").get()).get("status"), "responded");
});

// ---- Two-step verification (authenticator code) for admins -------------------

/** The token of an admin who signed in with an authenticator code. */
const withSecondFactor = (request) => ({
  auth: {
    ...request.auth,
    token: { ...request.auth.token, firebase: { sign_in_second_factor: "totp" } },
  },
});

test("two-step: not required by default, so admins work exactly as before", async () => {
  const request = await makeAdmin();
  assert.equal(await jobs.adminTwoStepRequired(db), false);
  const row = await jobs.requireAdmin(db, request);
  assert.equal(row.displayName, "Test Admin");
});

test("two-step: when required, an admin signed in without a code is refused by every admin function", async () => {
  const request = await makeAdmin();
  await seedFeedback("f1");
  await makeUser("u1");
  await db.doc("appConfig/adminAuth").set({ requireTotp: true });
  await expectCode(jobs.requireAdmin(db, request), "permission-denied");
  await expectCode(
    jobs.respondToFeedback({ db, request, data: { feedbackId: "f1", response: "Hi" } }),
    "permission-denied"
  );
  // ...and the same admin signed in with a code is fine.
  const ok = await jobs.respondToFeedback({
    db,
    request: withSecondFactor(request),
    data: { feedbackId: "f1", response: "Hi" },
  });
  assert.equal(ok.sent, true);
});

test("two-step: only an admin who signed in with a code can switch it on (no self-lockout)", async () => {
  const request = await makeAdmin();
  await expectCode(
    jobs.setAdminTwoStepRequired({ db, request, data: { required: true } }),
    "failed-precondition"
  );
  assert.equal(await jobs.adminTwoStepRequired(db), false);

  const res = await jobs.setAdminTwoStepRequired({
    db,
    request: withSecondFactor(request),
    data: { required: true },
  });
  assert.deepEqual(res, { required: true });
  assert.equal(await jobs.adminTwoStepRequired(db), true);
  const logs = (await audits()).filter((l) => l.targetId === "adminTwoStep");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, "Two-step verification turned on for admins");

  // Turning it off needs the code too once it is required (requireAdmin).
  await expectCode(
    jobs.setAdminTwoStepRequired({ db, request, data: { required: false } }),
    "permission-denied"
  );
  await jobs.setAdminTwoStepRequired({
    db,
    request: withSecondFactor(request),
    data: { required: false },
  });
  assert.equal(await jobs.adminTwoStepRequired(db), false);
});

test("two-step: bad input and non-admins are refused", async () => {
  const request = await makeAdmin();
  await expectCode(
    jobs.setAdminTwoStepRequired({ db, request, data: { required: "yes" } }),
    "invalid-argument"
  );
  await expectCode(
    jobs.setAdminTwoStepRequired({ db, request: asNonAdmin(), data: { required: false } }),
    "permission-denied"
  );
});

test("two-step: the sign-in audit entry says when a code was used", async () => {
  const request = withSecondFactor(await makeAdmin());
  await jobs.recordAdminSignIn({ db, request, nowMs: NOW });
  const logs = (await audits()).filter((l) => l.action === "Admin signed in");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].reason, "authenticator_code");
});

// ---- Notifications for specific users: schedule, edit, cancel, push ----------------

const IN_AN_HOUR = () => Date.now() + 60 * 60 * 1000;

async function seedDevice(uid, token) {
  await db.doc(`users/${uid}/devices/${token}`).set({ token, platform: "android" });
}

const scheduleFor = (request, extra = {}) =>
  jobs.scheduleNotification({
    db,
    request,
    data: {
      title: "Clinic reminder",
      body: "Please come in on Friday.",
      usernames: ["juan", "maria"],
      scheduledForMs: IN_AN_HOUR(),
      ...extra,
    },
  });

test("schedule for users: saved privately with the users, the Manila timezone and an audit entry", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedProfile("maria");
  const res = await scheduleFor(request);
  assert.equal(res.recipients, 2);

  const doc = (await db.doc(`scheduledNotifications/${res.id}`).get()).data();
  assert.equal(doc.status, "scheduled");
  assert.deepEqual(doc.targetUids, ["juan", "maria"]);
  assert.deepEqual(doc.targetUsernames, ["juan", "maria"]);
  assert.equal(doc.timezone, "Asia/Manila");
  assert.equal(doc.link, "fineaid://notifications");
  assert.ok(doc.scheduledFor);
  assert.equal((await collectionDocs("systemNotifications")).length, 0, "nothing public");
  const logs = (await audits()).filter((l) => l.targetId === res.id);
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, 'Scheduled notification "Clinic reminder" for 2 users');
  assert.ok(!JSON.stringify(logs[0]).includes("come in on Friday"));
});

test("schedule for users: a past time, no users, an unknown user, a bad link and non-admins are refused", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await expectCode(scheduleFor(request, { scheduledForMs: Date.now() - 1000 }), "invalid-argument");
  await expectCode(scheduleFor(request, { scheduledForMs: Date.now() + 10 * 1000 }), "invalid-argument");
  await expectCode(scheduleFor(request, { scheduledForMs: "soon" }), "invalid-argument");
  await expectCode(scheduleFor(request, { usernames: [] }), "invalid-argument");
  await expectCode(scheduleFor(request, { usernames: undefined }), "invalid-argument");
  await expectCode(scheduleFor(request, { usernames: ["juan", "nobody"] }), "not-found");
  await expectCode(scheduleFor(request, { link: "https://evil.example" }), "invalid-argument");
  await expectCode(scheduleFor(request, { title: "  " }), "invalid-argument");
  await expectCode(scheduleFor(asNonAdmin(), { usernames: ["juan"] }), "permission-denied");
  assert.equal((await collectionDocs("scheduledNotifications")).length, 0);
});

test("schedule for users: the same user twice counts once", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  const res = await scheduleFor(request, { usernames: ["juan", "juan", " juan "] });
  assert.equal(res.recipients, 1);
});

test("edit: a pending notification's text, time, link and users can change; a sent or cancelled one cannot", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedProfile("maria");
  const { id } = await scheduleFor(request);
  const later = IN_AN_HOUR() + 2 * 60 * 60 * 1000;
  await jobs.updateScheduledNotification({
    db,
    request,
    data: {
      collection: "scheduledNotifications",
      notificationId: id,
      title: "New title",
      body: "New body",
      scheduledForMs: later,
      usernames: ["maria"],
      link: "fineaid://journal",
    },
  });
  const doc = (await db.doc(`scheduledNotifications/${id}`).get()).data();
  assert.equal(doc.title, "New title");
  assert.equal(doc.scheduledFor.toMillis(), later);
  assert.deepEqual(doc.targetUids, ["maria"]);
  assert.equal(doc.link, "fineaid://journal");
  assert.equal(doc.status, "scheduled");

  await expectCode(
    jobs.updateScheduledNotification({
      db,
      request,
      data: { collection: "scheduledNotifications", notificationId: id, scheduledForMs: Date.now() - 5000 },
    }),
    "invalid-argument"
  );
  await jobs.cancelScheduledNotification({ db, request, notificationId: id, collection: "scheduledNotifications" });
  await expectCode(
    jobs.updateScheduledNotification({
      db,
      request,
      data: { collection: "scheduledNotifications", notificationId: id, title: "Too late" },
    }),
    "failed-precondition"
  );
  assert.equal((await db.doc(`scheduledNotifications/${id}`).get()).get("title"), "New title");
});

test("edit: an all-users announcement can change its text and time, but has no user list", async () => {
  const request = await makeAdmin();
  const id = await addNotification("scheduled", 120);
  const later = IN_AN_HOUR() + 3 * 60 * 60 * 1000;
  await jobs.updateScheduledNotification({
    db,
    request,
    data: { notificationId: id, title: "Edited", scheduledForMs: later },
  });
  const doc = (await db.doc(`systemNotifications/${id}`).get()).data();
  assert.equal(doc.title, "Edited");
  assert.equal(doc.body, "Hello", "editing the title leaves the message alone");
  assert.equal(doc.scheduledFor.toMillis(), later);
  await expectCode(
    jobs.updateScheduledNotification({ db, request, data: { notificationId: id, usernames: ["juan"] } }),
    "invalid-argument"
  );
  await expectCode(
    jobs.updateScheduledNotification({ db, request: asNonAdmin(), data: { notificationId: id, title: "x" } }),
    "permission-denied"
  );
  await expectCode(
    jobs.updateScheduledNotification({ db, request, data: { notificationId: id } }),
    "invalid-argument"
  );
});

test("cancel: works on the selected-users queue, and an unknown queue is refused", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  const { id } = await scheduleFor(request, { usernames: ["juan"] });
  await expectCode(
    jobs.cancelScheduledNotification({ db, request, notificationId: id, collection: "users" }),
    "invalid-argument"
  );
  await jobs.cancelScheduledNotification({ db, request, notificationId: id, collection: "scheduledNotifications" });
  assert.equal((await db.doc(`scheduledNotifications/${id}`).get()).get("status"), "cancelled");
});

test("scheduler: a due notification for selected users is pushed only to their devices, with the link, and kept in their inboxes", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedProfile("maria");
  await seedProfile("pedro"); // not selected
  await seedDevice("juan", "tok-juan-1");
  await seedDevice("juan", "tok-juan-2");
  await seedDevice("pedro", "tok-pedro");
  // maria has no registered device at all.
  const { id } = await scheduleFor(request, { link: "fineaid://journal" });
  await db.doc(`scheduledNotifications/${id}`).update({ scheduledFor: Timestamp.fromMillis(NOW - 1000) });

  const messaging = fakeMessaging();
  const run = await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  assert.equal(run.sent, 1);

  assert.equal(messaging.sent.length, 0, "no broadcast to everyone");
  assert.equal(messaging.multicasts.length, 1);
  const push = messaging.multicasts[0];
  assert.deepEqual(push.tokens.sort(), ["tok-juan-1", "tok-juan-2"]);
  assert.equal(push.notification.title, "Clinic reminder");
  assert.equal(push.notification.body, "Please come in on Friday.");
  assert.equal(push.data.link, "fineaid://journal");
  assert.equal(push.data.notificationId, id);

  const doc = (await db.doc(`scheduledNotifications/${id}`).get()).data();
  assert.equal(doc.status, "sent");
  assert.ok(doc.sentAt);
  assert.deepEqual(doc.delivery, { recipients: 2, pushed: 2, noDevice: 1, invalidRemoved: 0, failed: 0 });

  assert.equal((await notices("juan")).length, 1);
  assert.equal((await notices("maria")).length, 1, "no device: the inbox notice still arrives");
  assert.equal((await notices("pedro")).length, 0, "not selected: nothing");
  assert.equal((await notices("juan"))[0].link, "fineaid://journal");
});

test("scheduler: it is sent exactly once, and a retry after a push outage does not duplicate the inbox notice", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedDevice("juan", "tok-juan");
  const { id } = await scheduleFor(request, { usernames: ["juan"] });
  await db.doc(`scheduledNotifications/${id}`).update({ scheduledFor: Timestamp.fromMillis(NOW - 1000) });

  const down = fakeMessaging({ multicastDown: true });
  const first = await jobs.processDueNotifications({ db, messaging: down, nowMs: NOW });
  assert.equal(first.retried, 1);
  assert.equal((await db.doc(`scheduledNotifications/${id}`).get()).get("status"), "scheduled");

  const up = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging: up, nowMs: NOW });
  await jobs.processDueNotifications({ db, messaging: up, nowMs: NOW });
  assert.equal(up.multicasts.length, 1);
  assert.equal((await notices("juan")).length, 1, "one inbox notice, not two");
});

test("scheduler: invalid or expired device tokens are removed, the rest still get it", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedDevice("juan", "good");
  await seedDevice("juan", "expired");
  const { id } = await scheduleFor(request, { usernames: ["juan"] });
  await db.doc(`scheduledNotifications/${id}`).update({ scheduledFor: Timestamp.fromMillis(NOW - 1000) });

  await jobs.processDueNotifications({ db, messaging: fakeMessaging({ deadTokens: ["expired"] }), nowMs: NOW });
  const left = (await collectionDocs("users/juan/devices")).map((d) => d.token);
  assert.deepEqual(left, ["good"]);
  const doc = (await db.doc(`scheduledNotifications/${id}`).get()).data();
  assert.equal(doc.delivery.pushed, 1);
  assert.equal(doc.delivery.invalidRemoved, 1);
});

test("scheduler: future and cancelled notifications for users are never sent", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedDevice("juan", "tok");
  const future = await scheduleFor(request, { usernames: ["juan"] });
  const cancelled = await scheduleFor(request, { usernames: ["juan"] });
  await db.doc(`scheduledNotifications/${cancelled.id}`).update({ scheduledFor: Timestamp.fromMillis(NOW - 1000) });
  await jobs.cancelScheduledNotification({
    db,
    request,
    notificationId: cancelled.id,
    collection: "scheduledNotifications",
  });
  const messaging = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  assert.equal(messaging.multicasts.length, 0);
  assert.equal((await db.doc(`scheduledNotifications/${future.id}`).get()).get("status"), "scheduled");
  assert.equal((await notices("juan")).length, 0);
});

test("scheduler: an all-users announcement still goes to the topic, now with a link", async () => {
  await addNotification("scheduled", -1, { link: "fineaid://journal" });
  await addNotification("scheduled", -1);
  const messaging = fakeMessaging();
  await jobs.processDueNotifications({ db, messaging, nowMs: NOW });
  assert.equal(messaging.sent.length, 2);
  assert.ok(messaging.sent.every((m) => m.topic === "all_users"));
  const links = messaging.sent.map((m) => m.data.link).sort();
  assert.deepEqual(links, ["fineaid://journal", "fineaid://notifications"]);
});

test("send now to several users: each gets an inbox notice and a push; one audit entry; no device is fine", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedProfile("maria");
  await seedDevice("juan", "tok-juan");
  const messaging = fakeMessaging();
  const res = await jobs.sendNotificationToUser({
    db,
    request,
    messaging,
    data: { usernames: ["juan", "maria"], title: "Hello all", body: "Body", link: "fineaid://journal" },
  });
  assert.equal(res.sent, true);
  assert.equal(res.count, 2);
  assert.equal(res.pushFailed, false);
  assert.deepEqual(res.delivery, { recipients: 2, pushed: 1, noDevice: 1, invalidRemoved: 0, failed: 0 });
  assert.equal((await notices("juan")).length, 1);
  assert.equal((await notices("maria")).length, 1);
  assert.deepEqual(messaging.multicasts[0].tokens, ["tok-juan"]);
  const logs = (await audits()).filter((l) => l.reason === "targeted_notification");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, 'Sent notification "Hello all" to 2 users');
});

test("send now: if the push service is down the inbox notice is kept and the result says the push failed", async () => {
  const request = await makeAdmin();
  await seedProfile("juan");
  await seedDevice("juan", "tok");
  const res = await jobs.sendNotificationToUser({
    db,
    request,
    messaging: fakeMessaging({ multicastDown: true }),
    data: { username: "juan", title: "Hi" },
  });
  assert.equal(res.sent, true);
  assert.equal(res.pushFailed, true);
  assert.equal((await notices("juan")).length, 1);
});
