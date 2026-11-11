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

async function tokenFor(uid, { admin = false } = {}) {
  await auth.createUser({ uid, email: `${uid}@example.com`, password: "Passw0rd!x" });
  // The claim is set server-side, before sign-in, like the real admin setup.
  if (admin) await auth.setCustomUserClaims(uid, { admin: true });
  const { body } = await signIn(`${uid}@example.com`, "Passw0rd!x");
  return body.idToken;
}

test("writeAuditLog: an admin's entry is stamped with their identity, not the request's", async () => {
  await makeAdmin("admin1");
  const token = await tokenFor("admin1", { admin: true });
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
  const token = await tokenFor("admin1", { admin: true });
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

test("an admin with an admins document but no admin claim is rejected end to end", async () => {
  await makeAdmin("admin1");
  const token = await tokenFor("admin1"); // no claim set
  const res = await call("writeAuditLog", { action: "x" }, token);
  assert.equal(res.status, 403);
  assert.equal((await collectionDocs("auditLogs")).length, 0);
});

test("recordAdminSignIn: an admin is logged; a normal user is logged as refused", async () => {
  await makeAdmin("admin1");
  const adminToken = await tokenFor("admin1", { admin: true });
  assert.equal((await call("recordAdminSignIn", {}, adminToken)).status, 200);
  const userToken = await tokenFor("regular-user");
  assert.equal((await call("recordAdminSignIn", {}, userToken)).status, 200);
  const logs = (await collectionDocs("auditLogs")).filter((l) => l.type === "LOGIN");
  assert.deepEqual(logs.map((l) => l.result).sort(), ["failure", "success"]);
});

test("recordAdminSignInFailure works signed out and answers the same for any email", async () => {
  await makeAdmin("admin1");
  await auth.createUser({ uid: "admin1", email: "admin1@example.com", password: "Passw0rd!x" });
  const known = await call("recordAdminSignInFailure", { email: "admin1@example.com", reason: "wrong_password" });
  const unknown = await call("recordAdminSignInFailure", { email: "who@example.com" });
  assert.equal(known.status, 200);
  assert.equal(unknown.status, 200);
  assert.deepEqual(known.body, unknown.body);
  const logs = (await collectionDocs("auditLogs")).filter((l) => l.type === "LOGIN");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorUid, "admin1");
});
