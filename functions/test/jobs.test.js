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

function fakeMessaging({ failTimes = 0 } = {}) {
  const sent = [];
  let failures = failTimes;
  return {
    sent,
    send: async (message) => {
      if (failures > 0) {
        failures--;
        throw new Error("fcm down");
      }
      sent.push(message);
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
