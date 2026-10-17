// HTTP-level tests of the deployed-shape callables, through the Functions
// emulator. `npm test` starts it; nothing here reaches production.
const { test, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  PROJECT,
  db,
  auth,
  resetEmulators,
  makeAdmin,
  collectionDocs,
  signIn,
} = require("./helpers");

beforeEach(resetEmulators);

async function call(name, data, idToken) {
  const res = await fetch(
    `http://127.0.0.1:5001/${PROJECT}/us-central1/${name}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
      },
      body: JSON.stringify({ data }),
    }
  );
  return { status: res.status, body: await res.json() };
}

async function tokenFor(uid) {
  await auth.createUser({ uid, email: `${uid}@example.com`, password: "Passw0rd!x" });
  const { body } = await signIn(`${uid}@example.com`, "Passw0rd!x");
  return body.idToken;
}

test("writeAuditLog: an admin's entry is stamped with their identity, not the request's", async () => {
  await makeAdmin("admin1");
  const token = await tokenFor("admin1");
  const res = await call(
    "writeAuditLog",
    {
      action: "Updated article",
      type: "UPDATE",
      actorUid: "someone-else", // must be ignored
      actorName: "Forged Name", // must be ignored
      targetType: "content",
      targetName: "Burn care",
    },
    token
  );
  assert.equal(res.status, 200);
  const [entry] = await collectionDocs("auditLogs");
  assert.equal(entry.actorUid, "admin1");
  assert.equal(entry.actorName, "Test Admin");
  assert.equal(entry.targetName, "Burn care");
  assert.ok(entry.timestamp);
});

test("writeAuditLog: a non-admin and a signed-out caller are rejected", async () => {
  const token = await tokenFor("regular-user");
  const nonAdmin = await call("writeAuditLog", { action: "x" }, token);
  assert.equal(nonAdmin.status, 403);
  const anonymous = await call("writeAuditLog", { action: "x" });
  assert.equal(anonymous.status, 401);
  assert.equal((await collectionDocs("auditLogs")).length, 0);
});

test("writeAuditLog: an entry with no action is rejected", async () => {
  await makeAdmin("admin1");
  const token = await tokenFor("admin1");
  const res = await call("writeAuditLog", { action: "   " }, token);
  assert.equal(res.status, 400);
});

test("admin callables reject non-admins end to end", async () => {
  await db.doc("users/u1").set({ username: "u1" });
  await db.collection("systemNotifications").doc("n1").set({ status: "scheduled" });
  const token = await tokenFor("regular-user");
  for (const [name, data] of [
    ["scheduleAccountDeactivation", { uid: "u1" }],
    ["cancelAccountDeactivation", { uid: "u1" }],
    ["reactivateAccount", { uid: "u1" }],
    ["cancelScheduledNotification", { notificationId: "n1" }],
  ]) {
    const res = await call(name, data, token);
    assert.equal(res.status, 403, `${name} should reject non-admins`);
  }
  assert.equal(
    (await db.doc("systemNotifications/n1").get()).data().status,
    "scheduled"
  );
});
