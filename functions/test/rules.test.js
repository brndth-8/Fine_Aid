// Firestore rules tests. Run against the emulator only:
//   cd functions && npm test
// (firebase emulators:exec starts auth + firestore + functions, runs
// `node --test test/`, then shuts them down). Nothing here touches production.
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-fineaid-rules",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "..", "firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("admins/admin1").set({ email: "a@example.com" });
    await db.doc("auditLogs/log1").set({ action: "Seeded", type: "UPDATE" });
    await db.doc("users/user1").set({ username: "user1" });
    await db.doc("users/user1/journalEntries/e1").set({ title: "Entry" });
  });
});

// An admin is signed in with the server-set `admin` claim (and has an admins doc).
const asAdmin = () => env.authenticatedContext("admin1", { admin: true }).firestore();
const asUser = () => env.authenticatedContext("user1").firestore();
const asGuest = () => env.unauthenticatedContext().firestore();

// ---- Part 5: audit log integrity ------------------------------------------

test("audit log: an admin can read entries", async () => {
  await assertSucceeds(asAdmin().doc("auditLogs/log1").get());
});

test("audit log: a normal user cannot read entries", async () => {
  await assertFails(asUser().doc("auditLogs/log1").get());
});

test("audit log: a signed-out visitor cannot read entries", async () => {
  await assertFails(asGuest().doc("auditLogs/log1").get());
});

test("audit log: even an admin cannot create an entry from the client", async () => {
  await assertFails(
    asAdmin().collection("auditLogs").add({ action: "Forged", type: "UPDATE" })
  );
});

test("audit log: nobody can update an entry", async () => {
  await assertFails(asAdmin().doc("auditLogs/log1").update({ action: "Edited" }));
  await assertFails(asUser().doc("auditLogs/log1").update({ action: "Edited" }));
});

test("audit log: nobody can delete an entry", async () => {
  await assertFails(asAdmin().doc("auditLogs/log1").delete());
  await assertFails(asUser().doc("auditLogs/log1").delete());
});

// ---- Part 2: feedback responses -------------------------------------------

async function seedFeedback(extra = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc("feedback/f1")
      .set({ userId: "user1", message: "Hi", ...extra });
  });
}

const goodResponse = {
  response: "Thanks for the report.",
  respondedBy: "admin1",
  respondedByName: "Admin",
};

test("feedback: an admin can save a first response", async () => {
  await seedFeedback();
  await assertSucceeds(asAdmin().doc("feedback/f1").update(goodResponse));
});

test("feedback: a response must be credited to the admin saving it", async () => {
  await seedFeedback();
  await assertFails(
    asAdmin()
      .doc("feedback/f1")
      .update({ ...goodResponse, respondedBy: "someone-else" })
  );
});

test("feedback: empty and over-long responses are rejected", async () => {
  await seedFeedback();
  await assertFails(
    asAdmin().doc("feedback/f1").update({ ...goodResponse, response: "" })
  );
  await assertFails(
    asAdmin()
      .doc("feedback/f1")
      .update({ ...goodResponse, response: "x".repeat(1001) })
  );
  await assertSucceeds(
    asAdmin()
      .doc("feedback/f1")
      .update({ ...goodResponse, response: "x".repeat(1000) })
  );
});

test("feedback: a saved response cannot be edited, but status still can", async () => {
  await seedFeedback(goodResponse);
  await assertFails(
    asAdmin().doc("feedback/f1").update({ response: "Changed" })
  );
  await assertSucceeds(
    asAdmin().doc("feedback/f1").update({ status: "resolved" })
  );
});

test("feedback: a normal user cannot read or respond", async () => {
  await seedFeedback();
  await assertFails(asUser().doc("feedback/f1").get());
  await assertFails(asUser().doc("feedback/f1").update(goodResponse));
});

// ---- Part 6: journal photos stay private ----------------------------------

test("photos: the owner can read and write their journal photos", async () => {
  const ref = asUser().doc("users/user1/journalEntries/e1/photos/p1");
  await assertSucceeds(ref.set({ storagePath: "users/user1/journal/e1/a.jpg" }));
  await assertSucceeds(ref.get());
});

test("photos: an admin is denied, by direct read, list and collection-group query", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc("users/user1/journalEntries/e1/photos/p1")
      .set({ storagePath: "users/user1/journal/e1/a.jpg" });
  });
  await assertFails(asAdmin().doc("users/user1/journalEntries/e1/photos/p1").get());
  await assertFails(asAdmin().collection("users/user1/journalEntries/e1/photos").get());
  await assertFails(asAdmin().collectionGroup("photos").get());
  await assertFails(
    asAdmin().doc("users/user1/journalEntries/e1/photos/p2").set({ storagePath: "x" })
  );
});

test("photos: another user is denied", async () => {
  const other = env.authenticatedContext("user2").firestore();
  await assertFails(other.doc("users/user1/journalEntries/e1/photos/p1").get());
});

// ---- Part 9: scan counters --------------------------------------------------

test("scan stats: an admin can read the counters group, a user cannot read others'", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("users/user1/aiScanStats/summary").set({ total: 3, failed: 1 });
  });
  await assertSucceeds(asAdmin().collectionGroup("aiScanStats").get());
  await assertFails(env.authenticatedContext("user2").firestore().collectionGroup("aiScanStats").get());
  await assertSucceeds(asUser().doc("users/user1/aiScanStats/summary").get());
});

// ---- One account per email ---------------------------------------------------

const asUser2 = () => env.authenticatedContext("user2").firestore();

/** Saves a profile and its email reservation the way the app does. */
function saveWithEmail(db, uid, email, { reserve = email, existingProfile = true } = {}) {
  const batch = db.batch();
  const profile = db.doc(`users/${uid}`);
  if (existingProfile) batch.update(profile, { recoveryEmail: email });
  else batch.set(profile, { username: uid, recoveryEmail: email });
  if (reserve) batch.set(db.doc(`emails/${reserve}`), { uid });
  return batch.commit();
}

async function seedReservation(uid, email) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${uid}`).set({ username: uid, recoveryEmail: email });
    await db.doc(`emails/${email}`).set({ uid });
  });
}

test("email: a profile can take an address by reserving it in the same write", async () => {
  await assertSucceeds(saveWithEmail(asUser(), "user1", "juan@example.com"));
});

test("email: a profile cannot hold an address it hasn't reserved", async () => {
  await assertFails(
    saveWithEmail(asUser(), "user1", "juan@example.com", { reserve: null })
  );
});

test("email: a second account cannot take an address already reserved", async () => {
  await seedReservation("user1", "juan@example.com");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("users/user2").set({ username: "user2" });
  });
  await assertFails(saveWithEmail(asUser2(), "user2", "juan@example.com"));
});

test("email: the check ignores letter case", async () => {
  await seedReservation("user1", "juan@example.com");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("users/user2").set({ username: "user2" });
  });
  // Different case, so a different document id, but the profile's address
  // lower-cases to the one already reserved for user1.
  await assertFails(saveWithEmail(asUser2(), "user2", "Juan@Example.com", { reserve: "Juan@Example.com" }));
  await assertFails(saveWithEmail(asUser2(), "user2", "Juan@Example.com", { reserve: null }));
});

test("email: a new sign-up with a free address works, with a taken one it fails", async () => {
  await seedReservation("user1", "juan@example.com");
  await assertSucceeds(
    saveWithEmail(asUser2(), "user2", "maria@example.com", { existingProfile: false })
  );
  const user3 = env.authenticatedContext("user3").firestore();
  await assertFails(
    saveWithEmail(user3, "user3", "juan@example.com", { existingProfile: false })
  );
});

test("email: changing it moves the reservation; an unchanged email needs nothing", async () => {
  await seedReservation("user1", "old@example.com");
  // Other profile edits don't touch the email (also true for older accounts
  // that have no reservation yet).
  await assertSucceeds(asUser().doc("users/user1").update({ username: "renamed" }));
  const batch = asUser().batch();
  batch.update(asUser().doc("users/user1"), { recoveryEmail: "new@example.com" });
  batch.set(asUser().doc("emails/new@example.com"), { uid: "user1" });
  batch.delete(asUser().doc("emails/old@example.com"));
  await assertSucceeds(batch.commit());
});

test("email: a reservation can't be dropped while the profile still uses the address", async () => {
  await seedReservation("user1", "juan@example.com");
  await assertFails(asUser().doc("emails/juan@example.com").delete());
  // Removing the address and the reservation together is fine.
  const batch = asUser().batch();
  batch.update(asUser().doc("users/user1"), {
    recoveryEmail: require("firebase/compat/app").default.firestore.FieldValue.delete(),
  });
  batch.delete(asUser().doc("emails/juan@example.com"));
  await assertSucceeds(batch.commit());
});

test("email: reservations can be checked one at a time but not listed", async () => {
  await seedReservation("user1", "juan@example.com");
  await assertSucceeds(asUser2().doc("emails/juan@example.com").get());
  await assertFails(asGuest().doc("emails/juan@example.com").get());
  await assertFails(asUser2().collection("emails").get());
});

test("email: an admin can set a user's address only through a reservation", async () => {
  await assertFails(
    saveWithEmail(asAdmin(), "user1", "set-by-admin@example.com", { reserve: null })
  );
  const batch = asAdmin().batch();
  batch.update(asAdmin().doc("users/user1"), { recoveryEmail: "set-by-admin@example.com" });
  batch.set(asAdmin().doc("emails/set-by-admin@example.com"), { uid: "user1" });
  await assertSucceeds(batch.commit());
});

// ---- phone numbers: one account per number ---------------------------------

const PHONE = "+639171234567";

/** Saves a profile and its phone reservation the way the app does. */
function saveWithPhone(db, uid, phone, { reserve = phone, existingProfile = true } = {}) {
  const batch = db.batch();
  const profile = db.doc(`users/${uid}`);
  if (existingProfile) batch.update(profile, { phoneNumber: phone });
  else batch.set(profile, { username: uid, phoneNumber: phone });
  if (reserve) batch.set(db.doc(`phones/${reserve}`), { uid });
  return batch.commit();
}

/** Turns the phone check on (it is off until appConfig/phoneUniqueness says so). */
async function enforcePhones() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("appConfig/phoneUniqueness").set({ enforce: true });
  });
}

async function seedPhone(uid, phone) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${uid}`).set({ username: uid, phoneNumber: phone });
    await db.doc(`phones/${phone}`).set({ uid });
  });
}

test("phone: a profile can take a number by reserving it in the same write", async () => {
  await assertSucceeds(saveWithPhone(asUser(), "user1", PHONE));
});

test("phone: while the switch is off, profiles save a number without a reservation (older app versions)", async () => {
  await assertSucceeds(saveWithPhone(asUser(), "user1", "09171234567", { reserve: null }));
});

test("phone: a profile cannot hold a number it hasn't reserved", async () => {
  await enforcePhones();
  await assertFails(saveWithPhone(asUser(), "user1", PHONE, { reserve: null }));
});

test("phone: the number must be in the standard +63 form", async () => {
  await enforcePhones();
  await assertFails(saveWithPhone(asUser(), "user1", "09171234567"));
  await assertFails(saveWithPhone(asUser(), "user1", "+63 917 123 4567"));
});

test("phone: a number another account holds cannot be taken", async () => {
  await enforcePhones();
  await seedPhone("user2", PHONE);
  await assertFails(saveWithPhone(asUser(), "user1", PHONE));
  // ...nor by overwriting their reservation.
  await assertFails(asUser().doc(`phones/${PHONE}`).set({ uid: "user1" }));
});

test("phone: changing it moves the reservation; an unchanged number needs nothing", async () => {
  await enforcePhones();
  await seedPhone("user1", "+639170000001");
  // Other profile edits don't touch the number (also true for older accounts
  // that have no reservation yet).
  await assertSucceeds(asUser().doc("users/user1").update({ username: "renamed" }));
  const batch = asUser().batch();
  batch.update(asUser().doc("users/user1"), { phoneNumber: "+639170000002" });
  batch.set(asUser().doc("phones/+639170000002"), { uid: "user1" });
  batch.delete(asUser().doc("phones/+639170000001"));
  await assertSucceeds(batch.commit());
});

test("phone: a reservation can't be dropped while the profile still uses the number", async () => {
  await seedPhone("user1", PHONE);
  await assertFails(asUser().doc(`phones/${PHONE}`).delete());
});

test("phone: reservations can be checked one at a time but not listed", async () => {
  await seedPhone("user1", PHONE);
  await assertSucceeds(asUser2().doc(`phones/${PHONE}`).get());
  await assertFails(asGuest().doc(`phones/${PHONE}`).get());
  await assertFails(asUser2().collection("phones").get());
});

// ---- Part 8: the admin role needs the claim AND the admins document ---------

test("admin role: a listed admin whose token has no admin claim is refused", async () => {
  const noClaim = env.authenticatedContext("admin1").firestore();
  await assertFails(noClaim.doc("auditLogs/log1").get());
  await assertFails(noClaim.collection("feedback").get());
});

test("admin role: the claim alone is not enough without an admins document", async () => {
  const claimOnly = env.authenticatedContext("nobody", { admin: true }).firestore();
  await assertFails(claimOnly.doc("auditLogs/log1").get());
});

test("admin role: claim plus admins document works; claim: false does not", async () => {
  await assertSucceeds(asAdmin().doc("auditLogs/log1").get());
  const off = env.authenticatedContext("admin1", { admin: false }).firestore();
  await assertFails(off.doc("auditLogs/log1").get());
});

test("admin role: nobody can create or edit an admins document from a browser", async () => {
  await assertFails(asAdmin().doc("admins/newadmin").set({ email: "x@example.com" }));
  await assertFails(asUser().doc("admins/user1").set({ email: "x@example.com" }));
});
// ---- Feedback: a resolved item takes no response ---------------------------

test("feedback: a resolved item rejects a new response", async () => {
  await seedFeedback({ status: "resolved" });
  await assertFails(asAdmin().doc("feedback/f1").update(goodResponse));
});

test("feedback: a response can't be slipped in while resolving in the same write", async () => {
  await seedFeedback({ status: "open" });
  await assertFails(
    asAdmin().doc("feedback/f1").update({ ...goodResponse, status: "resolved" })
  );
});

test("feedback: reopening makes it answerable again", async () => {
  await seedFeedback({ status: "resolved" });
  await assertSucceeds(asAdmin().doc("feedback/f1").update({ status: "open" }));
  await assertSucceeds(asAdmin().doc("feedback/f1").update(goodResponse));
});

test("feedback: items in any other status behave as before", async () => {
  await seedFeedback({ status: "open" });
  await assertSucceeds(asAdmin().doc("feedback/f1").update(goodResponse));
  await seedFeedback({}); // no status at all (older submissions)
  await assertSucceeds(asAdmin().doc("feedback/f1").update(goodResponse));
});

test("feedback: a resolved item can still be reopened or have its saved response read", async () => {
  await seedFeedback({ status: "resolved", ...goodResponse });
  await assertSucceeds(asAdmin().doc("feedback/f1").get());
  await assertSucceeds(asAdmin().doc("feedback/f1").update({ status: "open" }));
});

// ---- Security settings: only the function writes them ----------------------

test("security settings: admins can read, nobody can write from a browser", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("adminSettings/security").set({ idleTimeoutEnabled: true, idleTimeoutMinutes: 15 });
  });
  await assertSucceeds(asAdmin().doc("adminSettings/security").get());
  await assertFails(asAdmin().doc("adminSettings/security").update({ idleTimeoutEnabled: false }));
  await assertFails(asAdmin().doc("adminSettings/other").set({ x: 1 }));
  await assertFails(asUser().doc("adminSettings/security").get());
  await assertFails(asGuest().doc("adminSettings/security").get());
});

// ---- Dashboard graph: per-day scan error counts ----------------------------

test("scan errors by day: the owner writes only the expected fields; admins read the group", async () => {
  const ref = asUser().doc("users/user1/aiScanDaily/20261023");
  await assertSucceeds(ref.set({ day: new Date(), failed: 1 }));
  await assertSucceeds(ref.set({ day: new Date(), failed: 2, erroneous: 1 }));
  await assertSucceeds(ref.set({ day: new Date(), satisfied: 3 }));
  await assertFails(ref.set({ day: new Date(), failed: 1, note: "free text" }));
  await assertSucceeds(asAdmin().collectionGroup("aiScanDaily").get());
  await assertFails(env.authenticatedContext("user2").firestore().collectionGroup("aiScanDaily").get());
  await assertFails(env.authenticatedContext("user2").firestore().doc("users/user1/aiScanDaily/20261023").set({ day: new Date(), failed: 1 }));
});
// ---- Gemini proxy request counters: server only ---------------------------

test("geminiUsage counters are not readable or writable from the app", async () => {
  await assertFails(asUser().doc("geminiUsage/u_user1_20261030").get());
  await assertFails(asUser().doc("geminiUsage/u_user1_20261030").set({ count: 0 }));
  await assertFails(asAdmin().doc("geminiUsage/u_user1_20261030").get());
});

// ---- guard rails that must keep working -----------------------------------

test("journal: the owner reads their entry, an admin reads via the group query", async () => {
  await assertSucceeds(asUser().doc("users/user1/journalEntries/e1").get());
  await assertSucceeds(
    asAdmin().collectionGroup("journalEntries").limit(1).get()
  );
});

// ---- Failed-login lockout setting (public read-only copy) -----------------

test("appConfig: the sign-in screen can read the lockout setting before sign-in", async () => {
  await assertSucceeds(asGuest().doc("appConfig/loginSecurity").get());
});

test("appConfig: nobody can write the lockout setting from a client, admin included", async () => {
  const data = { lockoutEnabled: false, lockoutMaxAttempts: 10, lockoutMinutes: 5 };
  await assertFails(asGuest().doc("appConfig/loginSecurity").set(data));
  await assertFails(asUser().doc("appConfig/loginSecurity").set(data));
  await assertFails(asAdmin().doc("appConfig/loginSecurity").set(data));
});

// ---- Two-step verification for admins ----------------------------------------

const asAdminWithCode = () =>
  env
    .authenticatedContext("admin1", {
      admin: true,
      firebase: { sign_in_provider: "password", sign_in_second_factor: "totp" },
    })
    .firestore();

test("two-step: switched off (the default), admins read exactly as before", async () => {
  await assertSucceeds(asAdmin().doc("auditLogs/log1").get());
});

test("two-step: when required, an admin without an authenticator code is refused and one with a code is allowed", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("appConfig/adminAuth").set({ requireTotp: true })
  );
  await assertFails(asAdmin().doc("auditLogs/log1").get());
  await assertFails(asAdmin().collection("feedback").get());
  await assertSucceeds(asAdminWithCode().doc("auditLogs/log1").get());
  // Ordinary users and the public flag are unaffected.
  await assertSucceeds(asUser().doc("users/user1").get());
  await assertSucceeds(asGuest().doc("appConfig/adminAuth").get());
});

test("two-step: a flag set to false means no code is needed", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("appConfig/adminAuth").set({ requireTotp: false })
  );
  await assertSucceeds(asAdmin().doc("auditLogs/log1").get());
});

test("two-step: nobody can switch the requirement from a client", async () => {
  await assertFails(asAdmin().doc("appConfig/adminAuth").set({ requireTotp: false }));
  await assertFails(asAdminWithCode().doc("appConfig/adminAuth").set({ requireTotp: true }));
});

// ---- Guest Mode feedback ---------------------------------------------------
// A signed-out visitor may CREATE one feedback item (never read or change it),
// with strict checks. See `validGuestFeedback` in firestore.rules.

const serverNow = () =>
  require("firebase/compat/app").default.firestore.FieldValue.serverTimestamp();
const guestFeedback = (extra = {}) => ({
  userId: null,
  source: "guest",
  message: "Very helpful app",
  rating: 4,
  submittedAt: serverNow(),
  ...extra,
});

test("guest feedback: a guest can send feedback with a rating", async () => {
  await assertSucceeds(asGuest().collection("feedback").add(guestFeedback()));
});

test("guest feedback: a message alone (no rating) is fine", async () => {
  const { rating, ...noRating } = guestFeedback();
  await assertSucceeds(asGuest().collection("feedback").add(noRating));
  await assertSucceeds(
    asGuest().collection("feedback").add(guestFeedback({ rating: null }))
  );
});

test("guest feedback: wrong shape is refused", async () => {
  const f = () => asGuest().collection("feedback");
  // claims to be a real user
  await assertFails(f().add(guestFeedback({ userId: "user1" })));
  // not marked as a guest
  await assertFails(f().add(guestFeedback({ source: "user" })));
  // message empty, over 100, or not text
  await assertFails(f().add(guestFeedback({ message: "" })));
  await assertFails(f().add(guestFeedback({ message: "x".repeat(101) })));
  await assertFails(f().add(guestFeedback({ message: 5 })));
  // rating outside 1-5, or not a whole number
  await assertFails(f().add(guestFeedback({ rating: 0 })));
  await assertFails(f().add(guestFeedback({ rating: 6 })));
  await assertFails(f().add(guestFeedback({ rating: 4.5 })));
  // an extra field, or a client-made timestamp
  await assertFails(f().add(guestFeedback({ status: "resolved" })));
  await assertFails(f().add(guestFeedback({ submittedAt: new Date() })));
  // a missing required field
  const { source, ...noSource } = guestFeedback();
  await assertFails(f().add(noSource));
});

test("guest feedback: a guest cannot read, change or delete feedback", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("feedback/g1").set({ ...guestFeedback(), submittedAt: new Date() })
  );
  await assertFails(asGuest().doc("feedback/g1").get());
  await assertFails(asGuest().collection("feedback").get());
  await assertFails(asGuest().doc("feedback/g1").update({ message: "Edited" }));
  await assertFails(asGuest().doc("feedback/g1").delete());
});

test("guest feedback: a signed-in user still can't send as someone else", async () => {
  await assertFails(
    asUser().collection("feedback").add({
      userId: "someone-else",
      message: "Hi",
      rating: 3,
      submittedAt: serverNow(),
    })
  );
  await assertSucceeds(
    asUser().collection("feedback").add({
      userId: "user1",
      message: "Hi",
      rating: 3,
      submittedAt: serverNow(),
    })
  );
});

test("guest feedback: an admin still reads it", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("feedback/g1").set({ ...guestFeedback(), submittedAt: new Date() })
  );
  await assertSucceeds(asAdmin().doc("feedback/g1").get());
});

// ---- Guest Mode AI-scan counters -------------------------------------------
// A signed-out visitor may only create/update the two guestAiScan counter
// documents, with counts that move by at most 1. See `guestAiScan` in
// firestore.rules. The admin reads them through the existing collection-group
// rules.

const inc = (n) =>
  require("firebase/compat/app").default.firestore.FieldValue.increment(n);
const guestSummary = () => asGuest().doc("guestAiScan/guest/aiScanStats/summary");
const today = () => {
  const d = new Date();
  const key =
    `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}` +
    `${String(d.getDate()).padStart(2, "0")}`;
  return [key, new Date(d.getFullYear(), d.getMonth(), d.getDate())];
};

test("guest scan counters: a guest can add a scan and a rating", async () => {
  await assertSucceeds(guestSummary().set({ total: inc(1), success: inc(1) }, { merge: true }));
  await assertSucceeds(guestSummary().set({ ratedCorrect: inc(1) }, { merge: true }));
  // changing their answer moves the count back down by 1
  await assertSucceeds(
    guestSummary().set({ ratedCorrect: inc(-1), ratedWrong: inc(1) }, { merge: true })
  );
});

test("guest scan counters: a failure with its reason", async () => {
  await assertSucceeds(
    guestSummary().set({ total: inc(1), failed: inc(1), failed_timeout: inc(1) }, { merge: true })
  );
});

test("guest scan counters: a jump of more than 1 is refused", async () => {
  await assertFails(guestSummary().set({ total: inc(50) }, { merge: true }));
  await assertFails(guestSummary().set({ ratedWrong: 1000 }, { merge: true }));
});

test("guest scan counters: never negative, only known fields", async () => {
  await assertFails(guestSummary().set({ ratedWrong: inc(-1) }, { merge: true }));
  await assertFails(guestSummary().set({ total: inc(1), note: "hi" }, { merge: true }));
  await assertFails(guestSummary().set({ total: "1" }, { merge: true }));
});

test("guest scan counters: only the summary document, only this path", async () => {
  await assertFails(
    asGuest().doc("guestAiScan/guest/aiScanStats/other").set({ total: inc(1) }, { merge: true })
  );
  await assertFails(
    asGuest().doc("guestAiScan/someone/aiScanStats/summary").set({ total: inc(1) }, { merge: true })
  );
});

test("guest scan counters: the per-day document", async () => {
  const [key, day] = today();
  const ref = asGuest().doc(`guestAiScan/guest/aiScanDaily/${key}`);
  await assertSucceeds(ref.set({ day, satisfied: inc(1) }, { merge: true }));
  await assertSucceeds(ref.set({ day, erroneous: inc(1) }, { merge: true }));
  await assertFails(ref.set({ day, satisfied: inc(9) }, { merge: true }));
  await assertFails(ref.set({ day, extra: 1 }, { merge: true }));
  // a bad id, or a day far from now
  await assertFails(
    asGuest().doc("guestAiScan/guest/aiScanDaily/abc").set({ day, satisfied: inc(1) }, { merge: true })
  );
  await assertFails(
    ref.set({ day: new Date(2020, 0, 1), satisfied: inc(1) }, { merge: true })
  );
});

test("guest scan counters: nobody can read them except an admin", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("guestAiScan/guest/aiScanStats/summary").set({ total: 3, ratedWrong: 1 })
  );
  await assertFails(guestSummary().get());
  await assertFails(asUser().doc("guestAiScan/guest/aiScanStats/summary").get());
  // the admin's dashboard reads every account's counters as one collection group
  await assertSucceeds(asAdmin().collectionGroup("aiScanStats").get());
});

test("guest scan counters: a signed-in user cannot write them", async () => {
  await assertFails(
    asUser()
      .doc("guestAiScan/guest/aiScanStats/summary")
      .set({ total: inc(1) }, { merge: true })
  );
});

// ---- Push notifications: devices and the private schedule queue ---------------

test("devices: a user can register, read and remove their own device, and nobody else's", async () => {
  const mine = asUser().doc("users/user1/devices/tokA");
  await assertSucceeds(mine.set({ token: "tokA", platform: "android", updatedAt: new Date() }));
  await assertSucceeds(mine.get());
  await assertSucceeds(mine.delete());
  const other = env.authenticatedContext("user2").firestore();
  await assertFails(other.doc("users/user1/devices/tokA").set({ token: "tokA" }));
  await assertFails(asAdmin().doc("users/user1/devices/tokA").get());
  await assertFails(asGuest().doc("users/user1/devices/tokA").set({ token: "tokA" }));
});

test("devices: only a token, a platform and a time can be stored, and the token can't be empty or huge", async () => {
  const ref = asUser().doc("users/user1/devices/tokB");
  await assertFails(ref.set({ token: "tokB", isAdmin: true }));
  await assertFails(ref.set({ token: "" }));
  await assertFails(ref.set({ token: "x".repeat(5000) }));
  await assertFails(ref.set({ platform: "android" }));
  await assertSucceeds(ref.set({ token: "tokB" }));
});

test("scheduled notifications for users: admins can read them, nobody can write them from a client", async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc("scheduledNotifications/n1").set({
      title: "Private",
      targetUids: ["user1"],
      status: "scheduled",
    })
  );
  await assertSucceeds(asAdmin().doc("scheduledNotifications/n1").get());
  await assertFails(asUser().doc("scheduledNotifications/n1").get());
  await assertFails(asGuest().doc("scheduledNotifications/n1").get());
  await assertFails(asAdmin().doc("scheduledNotifications/n1").update({ status: "cancelled" }));
  await assertFails(asAdmin().collection("scheduledNotifications").add({ title: "x" }));
});

// ---- SMS verification moved to the server (staged by appConfig/smsVerification)

async function enforceSms() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("appConfig/smsVerification").set({ enforce: true });
  });
}

test("sms: while the switch is off, older builds keep their own code and verify themselves", async () => {
  await assertSucceeds(asUser().doc("otpVerifications/user1").set({ code: "123456" }));
  await assertSucceeds(asUser().doc("users/user1").update({ phoneVerified: true }));
});

test("sms: once on, the app cannot read or write otpVerifications", async () => {
  await enforceSms();
  await assertFails(asUser().doc("otpVerifications/user1").set({ code: "123456" }));
  await assertFails(asUser().doc("otpVerifications/user1").get());
});

test("sms: once on, the app cannot mark itself verified (create or update)", async () => {
  await enforceSms();
  await assertFails(asUser().doc("users/user1").update({ phoneVerified: true }));
  await assertFails(
    env.authenticatedContext("user9").firestore().doc("users/user9").set({ phoneVerified: true })
  );
  await assertSucceeds(
    env.authenticatedContext("user9").firestore().doc("users/user9").set({ phoneVerified: false })
  );
});

test("sms: once on, other profile edits still work, and an admin can still change the flag", async () => {
  await enforceSms();
  await assertSucceeds(asUser().doc("users/user1").update({ firstName: "Ana" }));
  await assertSucceeds(asAdmin().doc("users/user1").update({ phoneVerified: true }));
});
