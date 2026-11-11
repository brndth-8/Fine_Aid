// Tests for lib/gemini_proxy.js. They use a small in-memory stand-in for
// Firestore and Auth and a fake "Gemini", so they need no emulator or key:
//   node --test test/gemini_proxy.test.js
const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  handleGeminiProxy,
  DAILY_LIMIT_GUEST,
  MAX_OUTPUT_TOKENS,
} = require("../lib/gemini_proxy");

function fakeDb() {
  const docs = new Map();
  return {
    docs,
    doc(path) {
      return { path };
    },
    async runTransaction(fn) {
      return fn({
        async get(ref) {
          const data = docs.get(ref.path);
          return {
            exists: data !== undefined,
            get: (k) => (data ? data[k] : undefined),
          };
        },
        set(ref, data) {
          docs.set(ref.path, { ...(docs.get(ref.path) || {}), ...data });
        },
      });
    },
  };
}

const auth = {
  async verifyIdToken(token) {
    if (token === "good") return { uid: "user1" };
    throw new Error("bad token");
  },
};

function request({
  method = "POST",
  path = "/v1beta/models/gemini-3.5-flash:generateContent",
  body = { contents: [{ role: "user", parts: [{ text: "hi" }] }] },
  headers = {},
  ip = "1.2.3.4",
} = {}) {
  const raw = body === null ? Buffer.alloc(0) : Buffer.from(JSON.stringify(body));
  return { method, path, rawBody: raw, headers, ip };
}

function fakeGemini(status = 200, text = '{"candidates":[]}') {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    return { status, text: async () => text };
  };
  return { calls, impl };
}

const run = (req, extra = {}) =>
  handleGeminiProxy({
    db: extra.db || fakeDb(),
    auth,
    req,
    apiKey: "SERVER_KEY",
    fetchImpl: extra.fetchImpl,
    now: extra.now,
  });

test("a guest request is forwarded with the server key, and the answer comes back as is", async () => {
  const gemini = fakeGemini(200, '{"candidates":[{"x":1}]}');
  const out = await run(request(), { fetchImpl: gemini.impl });
  assert.equal(out.status, 200);
  assert.equal(out.body, '{"candidates":[{"x":1}]}');
  assert.equal(gemini.calls.length, 1);
  assert.equal(
    gemini.calls[0].url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"
  );
  assert.equal(gemini.calls[0].init.headers["x-goog-api-key"], "SERVER_KEY");
});

test("Gemini's own errors pass through with their status", async () => {
  const gemini = fakeGemini(429, '{"error":{"message":"quota"}}');
  const out = await run(request(), { fetchImpl: gemini.impl });
  assert.equal(out.status, 429);
  assert.match(out.body, /quota/);
});

test("only POST, only generateContent on an allowed model", async () => {
  const gemini = fakeGemini();
  assert.equal((await run(request({ method: "GET" }), { fetchImpl: gemini.impl })).status, 405);
  for (const path of [
    "/v1beta/models/gemini-3.5-flash:streamGenerateContent",
    "/v1beta/models/gemini-1.5-pro:generateContent",
    "/v1beta/models/../tunedModels/x:generateContent",
    "/v1beta/files",
    "/",
  ]) {
    const out = await run(request({ path }), { fetchImpl: gemini.impl });
    assert.equal(out.status, 400, path);
  }
  assert.equal(gemini.calls.length, 0);
});

test("a body that is empty, not JSON, or has no contents is refused", async () => {
  const gemini = fakeGemini();
  assert.equal((await run(request({ body: null }), { fetchImpl: gemini.impl })).status, 400);
  const bad = request();
  bad.rawBody = Buffer.from("not json");
  assert.equal((await run(bad, { fetchImpl: gemini.impl })).status, 400);
  assert.equal(
    (await run(request({ body: { nope: 1 } }), { fetchImpl: gemini.impl })).status,
    400
  );
  assert.equal(gemini.calls.length, 0);
});

test("a request that is too large is refused", async () => {
  const gemini = fakeGemini();
  const big = request();
  big.rawBody = Buffer.alloc(9 * 1024 * 1024, 97);
  assert.equal((await run(big, { fetchImpl: gemini.impl })).status, 413);
});

test("a bad sign-in token is refused; a good one is counted per person", async () => {
  const gemini = fakeGemini();
  const db = fakeDb();
  const bad = await run(request({ headers: { authorization: "Bearer nope" } }), {
    db,
    fetchImpl: gemini.impl,
  });
  assert.equal(bad.status, 401);
  const good = await run(request({ headers: { authorization: "Bearer good" } }), {
    db,
    fetchImpl: gemini.impl,
  });
  assert.equal(good.status, 200);
  const keys = [...db.docs.keys()];
  assert.equal(keys.length, 1);
  assert.match(keys[0], /^geminiUsage\/u_user1_\d{8}$/);
});

test("a guest is stopped at the daily limit, then starts again the next day", async () => {
  const gemini = fakeGemini();
  const db = fakeDb();
  const day1 = Date.UTC(2026, 9, 30, 12);
  for (let i = 0; i < DAILY_LIMIT_GUEST; i++) {
    assert.equal((await run(request(), { db, fetchImpl: gemini.impl, now: day1 })).status, 200);
  }
  const over = await run(request(), { db, fetchImpl: gemini.impl, now: day1 });
  assert.equal(over.status, 429);
  assert.equal(gemini.calls.length, DAILY_LIMIT_GUEST);
  const next = await run(request(), { db, fetchImpl: gemini.impl, now: day1 + 24 * 3600 * 1000 });
  assert.equal(next.status, 200);
});

test("two guests on different addresses have separate allowances, and the address is stored hashed", async () => {
  const gemini = fakeGemini();
  const db = fakeDb();
  await run(request({ ip: "1.1.1.1" }), { db, fetchImpl: gemini.impl });
  await run(request({ ip: "2.2.2.2" }), { db, fetchImpl: gemini.impl });
  const keys = [...db.docs.keys()];
  assert.equal(keys.length, 2);
  assert.ok(keys.every((k) => !k.includes("1.1.1.1") && !k.includes("2.2.2.2")));
});

test("only the expected parts are forwarded, and the reply length is capped", async () => {
  const gemini = fakeGemini();
  const req = request({
    body: {
      contents: [{ role: "user", parts: [{ text: "hi" }] }],
      tools: [{ codeExecution: {} }],
      cachedContent: "x",
      generationConfig: { temperature: 0.1, maxOutputTokens: 99999 },
    },
  });
  await run(req, { fetchImpl: gemini.impl });
  const sent = JSON.parse(gemini.calls[0].init.body);
  assert.equal(sent.tools, undefined);
  assert.equal(sent.cachedContent, undefined);
  assert.equal(sent.generationConfig.maxOutputTokens, MAX_OUTPUT_TOKENS);
  assert.equal(sent.generationConfig.temperature, 0.1);
});

test("without a server key it says so and does not call Gemini", async () => {
  const gemini = fakeGemini();
  const out = await handleGeminiProxy({
    db: fakeDb(),
    auth,
    req: request(),
    apiKey: "",
    fetchImpl: gemini.impl,
  });
  assert.equal(out.status, 500);
  assert.equal(gemini.calls.length, 0);
});

test("if Gemini cannot be reached the person gets a clear error", async () => {
  const out = await run(request(), {
    fetchImpl: async () => {
      throw new Error("network");
    },
  });
  assert.equal(out.status, 504);
});
