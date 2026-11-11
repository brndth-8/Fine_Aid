// Tests for lib/sms_otp.js (the Semaphore SMS code, sent from the server). They
// use an in-memory stand-in for Firestore and a fake Semaphore, so they need
// no emulator and no key:
//   node --test test/sms_otp.test.js
const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  sendAccountVerificationOtpSms,
  formatPhilippineNumber,
  isMobileNumber,
  COOLDOWN_MS,
  MAX_SENDS_PER_HOUR,
} = require("../lib/sms_otp");

function fakeDb(initial = {}) {
  const docs = new Map(Object.entries(initial));
  return {
    docs,
    doc(path) {
      return {
        async get() {
          const data = docs.get(path);
          return { exists: data !== undefined, data: () => data };
        },
        async set(data) {
          docs.set(path, data);
        },
      };
    },
  };
}

function fakeSemaphore(status = 200, body = [{ status: "Pending" }]) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    return { ok: status >= 200 && status < 300, status, json: async () => body };
  };
  return { calls, impl };
}

function run(db, semaphore, extra = {}) {
  return sendAccountVerificationOtpSms({
    db,
    uid: "u1",
    phoneNumber: undefined,
    apiKey: "SECRET-FROM-SERVER",
    fetchImpl: semaphore.impl,
    now: 1_000_000_000_000,
    generateCode: () => "123456",
    timestampFromMillis: (ms) => ({ ms }),
    serverTime: () => "now",
    ...extra,
  });
}

async function rejects(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code);
    return true;
  });
}

test("number helpers", () => {
  assert.equal(formatPhilippineNumber("+639171234567"), "09171234567");
  assert.equal(formatPhilippineNumber("9171234567"), "09171234567");
  assert.equal(formatPhilippineNumber("09171234567"), "09171234567");
  assert.ok(isMobileNumber("09171234567"));
  assert.ok(isMobileNumber("08111234567"));
  assert.ok(!isMobileNumber("0281234567"));
  assert.ok(!isMobileNumber("0917123456"));
  assert.ok(!isMobileNumber("09171234abc"));
});

test("texts the number on the account, stores the code, sends the key from the server", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore();
  assert.deepEqual(await run(db, sem), { sent: true });

  assert.equal(sem.calls.length, 1);
  assert.equal(sem.calls[0].url, "https://api.semaphore.co/api/v4/otp");
  const sent = sem.calls[0].init.body;
  assert.equal(sent.get("apikey"), "SECRET-FROM-SERVER");
  assert.equal(sent.get("number"), "09171234567");
  assert.equal(sent.get("code"), "123456");
  assert.equal(sent.get("sendername"), "FINEAID");

  const stored = db.docs.get("accountVerificationOtps/u1");
  assert.equal(stored.code, "123456");
  assert.equal(stored.phoneNumber, "09171234567");
  assert.equal(stored.attempts, 0);
  assert.equal(stored.expiresAt.ms, 1_000_000_000_000 + 10 * 60 * 1000);
});

test("a number given by the app (Edit Profile) is used instead", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore();
  await run(db, sem, { phoneNumber: "+639281112222" });
  assert.equal(sem.calls[0].init.body.get("number"), "09281112222");
});

test("a bad number is refused and nothing is sent", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore();
  await rejects(run(db, sem, { phoneNumber: "12345" }), "invalid-argument");
  assert.equal(sem.calls.length, 0);
  assert.equal(db.docs.has("accountVerificationOtps/u1"), false);
});

test("no number anywhere: failed-precondition", async () => {
  const db = fakeDb({ "users/u1": {} });
  await rejects(run(db, fakeSemaphore()), "failed-precondition");
});

test("a second request inside the cooldown is refused", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore();
  await run(db, sem);
  await rejects(run(db, sem, { now: 1_000_000_000_000 + 10_000 }), "resource-exhausted");
  assert.equal(sem.calls.length, 1);
  // after the cooldown it works again
  await run(db, sem, { now: 1_000_000_000_000 + COOLDOWN_MS + 1 });
  assert.equal(sem.calls.length, 2);
});

test("an hourly cap stops SMS-credit drain", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore();
  const start = 1_000_000_000_000;
  for (let i = 0; i < MAX_SENDS_PER_HOUR; i++) {
    await run(db, sem, { now: start + i * (COOLDOWN_MS + 1) });
  }
  await rejects(
    run(db, sem, { now: start + MAX_SENDS_PER_HOUR * (COOLDOWN_MS + 1) }),
    "resource-exhausted"
  );
  assert.equal(sem.calls.length, MAX_SENDS_PER_HOUR);
  // an hour after the first, the window has moved on
  await run(db, sem, { now: start + 60 * 60 * 1000 + MAX_SENDS_PER_HOUR * COOLDOWN_MS });
  assert.equal(sem.calls.length, MAX_SENDS_PER_HOUR + 1);
});

test("Semaphore refusing (bad key, no credit) is an internal error with no key in it", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = fakeSemaphore(403, { message: "invalid" });
  await assert.rejects(run(db, sem), (err) => {
    assert.equal(err.code, "internal");
    assert.ok(!String(err.message).includes("SECRET-FROM-SERVER"));
    return true;
  });
});

test("an odd Semaphore answer (empty list / unknown status) is not treated as sent", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  await rejects(run(db, fakeSemaphore(200, [])), "internal");
  await rejects(
    run(fakeDb({ "users/u1": { phoneNumber: "+639171234567" } }), fakeSemaphore(200, [{ status: "Failed" }])),
    "internal"
  );
});

test("a network failure is an internal error", async () => {
  const db = fakeDb({ "users/u1": { phoneNumber: "+639171234567" } });
  const sem = { impl: async () => { throw new Error("offline"); } };
  await rejects(run(db, sem), "internal");
});
