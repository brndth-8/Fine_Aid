// releaseStaleContact (lib/jobs.js): frees a phone number / email held by a
// "ghost" account. These tests use a tiny in-memory fake of Firestore and
// Auth, so they run with plain `node --test test/stale_contact.test.js`, no
// emulator needed.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const jobs = require("../lib/jobs");

const HOUR = 60 * 60 * 1000;
const NOW = Date.UTC(2026, 10, 11, 12, 0, 0);
const isDelete = (v) => v && v.constructor && v.constructor.name === "DeleteTransform";

function makeDb(initial) {
  const docs = new Map(Object.entries(initial));
  const snap = (path) => ({
    exists: docs.has(path),
    get: (f) => (docs.has(path) ? docs.get(path)[f] : undefined),
  });
  const ref = (path) => ({ path, get: async () => snap(path) });
  return {
    docs,
    collection: (c) => ({ doc: (id) => ref(`${c}/${id}`) }),
    runTransaction: async (fn) => {
      const tx = {
        get: async (r) => snap(r.path),
        delete: (r) => docs.delete(r.path),
        update: (r, patch) => {
          const cur = { ...docs.get(r.path) };
          for (const [k, v] of Object.entries(patch)) {
            if (isDelete(v)) delete cur[k];
            else cur[k] = v;
          }
          docs.set(r.path, cur);
        },
      };
      return fn(tx);
    },
  };
}

const makeAuth = (users) => ({
  getUser: async (uid) => {
    if (!(uid in users)) {
      const e = new Error("no user");
      e.code = "auth/user-not-found";
      throw e;
    }
    return { metadata: { creationTime: new Date(users[uid]).toUTCString() } };
  },
});

const call = (db, auth, data, uid = "newbie") =>
  jobs.releaseStaleContact({ db, auth, request: { auth: { uid } }, data, nowMs: NOW });

const PHONE = "+639171234567";

test("a number whose holder no longer exists is released", async () => {
  const db = makeDb({ [`phones/${PHONE}`]: { uid: "gone" } });
  const r = await call(db, makeAuth({}), { kind: "phone", value: "09171234567" });
  assert.deepEqual(r, { released: true });
  assert.equal(db.docs.has(`phones/${PHONE}`), false);
});

test("an unfinished sign-up that is more than an hour old is released, and its profile loses the number", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "ghost" },
    "users/ghost": { registrationComplete: false, phoneNumber: PHONE, username: "g" },
  });
  const r = await call(db, makeAuth({ ghost: NOW - 2 * HOUR }), { kind: "phone", value: PHONE });
  assert.equal(r.released, true);
  assert.equal(db.docs.has(`phones/${PHONE}`), false);
  assert.equal("phoneNumber" in db.docs.get("users/ghost"), false);
  assert.equal(db.docs.get("users/ghost").username, "g"); // nothing else touched
});

test("an unfinished sign-up whose sign-in account is gone is released", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "ghost" },
    "users/ghost": { registrationComplete: false, phoneNumber: PHONE },
  });
  const r = await call(db, makeAuth({}), { kind: "phone", value: PHONE });
  assert.equal(r.released, true);
});

test("someone still signing up (under an hour) keeps their number", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "busy" },
    "users/busy": { registrationComplete: false, phoneNumber: PHONE },
  });
  const r = await call(db, makeAuth({ busy: NOW - 10 * 60 * 1000 }), { kind: "phone", value: PHONE });
  assert.deepEqual(r, { released: false, reason: "in-use" });
  assert.equal(db.docs.has(`phones/${PHONE}`), true);
});

test("a finished account is never touched", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "real" },
    "users/real": { registrationComplete: true, phoneNumber: PHONE },
  });
  const r = await call(db, makeAuth({ real: NOW - 90 * 24 * HOUR }), { kind: "phone", value: PHONE });
  assert.deepEqual(r, { released: false, reason: "in-use" });
  assert.equal(db.docs.has(`phones/${PHONE}`), true);
  assert.equal(db.docs.get("users/real").phoneNumber, PHONE);
});

test("an old profile without the flag but with progress is a real account", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "legacy" },
    "users/legacy": { phoneNumber: PHONE, phoneVerified: true },
  });
  const r = await call(db, makeAuth({ legacy: NOW - 400 * 24 * HOUR }), { kind: "phone", value: PHONE });
  assert.equal(r.released, false);
});

test("a finished account that changed its number no longer holds the old one", async () => {
  const db = makeDb({
    [`phones/${PHONE}`]: { uid: "mover" },
    "users/mover": { registrationComplete: true, phoneNumber: "+639189999999" },
  });
  const r = await call(db, makeAuth({ mover: NOW - 30 * 24 * HOUR }), { kind: "phone", value: PHONE });
  assert.equal(r.released, true);
  assert.equal(db.docs.get("users/mover").phoneNumber, "+639189999999"); // not wiped
});

test("your own reservation is left alone", async () => {
  const db = makeDb({ [`phones/${PHONE}`]: { uid: "newbie" } });
  const r = await call(db, makeAuth({}), { kind: "phone", value: PHONE }, "newbie");
  assert.deepEqual(r, { released: false, reason: "yours" });
});

test("nothing reserved: nothing to release", async () => {
  const r = await call(makeDb({}), makeAuth({}), { kind: "phone", value: PHONE });
  assert.deepEqual(r, { released: true });
});

test("emails work the same way (any capitals)", async () => {
  const db = makeDb({
    "emails/ghost@example.com": { uid: "gone" },
  });
  const r = await call(db, makeAuth({}), { kind: "email", value: " Ghost@Example.com " });
  assert.equal(r.released, true);
  assert.equal(db.docs.has("emails/ghost@example.com"), false);
});

test("08 numbers are understood", async () => {
  const db = makeDb({ "phones/+638132468013": { uid: "gone" } });
  const r = await call(db, makeAuth({}), { kind: "phone", value: "0813 246 8013" });
  assert.equal(r.released, true);
});

test("bad input and signed-out callers are refused", async () => {
  const db = makeDb({});
  await assert.rejects(
    jobs.releaseStaleContact({ db, auth: makeAuth({}), request: {}, data: { kind: "phone", value: PHONE } }),
    { code: "unauthenticated" }
  );
  await assert.rejects(call(db, makeAuth({}), { kind: "username", value: "x" }), {
    code: "invalid-argument",
  });
  await assert.rejects(call(db, makeAuth({}), { kind: "phone", value: "12345" }), {
    code: "invalid-argument",
  });
  await assert.rejects(call(db, makeAuth({}), { kind: "email", value: "nope" }), {
    code: "invalid-argument",
  });
});
