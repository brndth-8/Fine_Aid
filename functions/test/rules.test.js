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

const asAdmin = () => env.authenticatedContext("admin1").firestore();
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

// ---- guard rails that must keep working -----------------------------------

test("journal: the owner reads their entry, an admin reads via the group query", async () => {
  await assertSucceeds(asUser().doc("users/user1/journalEntries/e1").get());
  await assertSucceeds(
    asAdmin().collectionGroup("journalEntries").limit(1).get()
  );
});
