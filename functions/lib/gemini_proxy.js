// The Gemini key lives only on the server (Secret Manager). The app sends its
// normal Gemini request here instead of to Google; this checks who is asking,
// limits how much, and forwards it with the key. Nothing is stored except a
// per-day request counter.
const crypto = require("crypto");

const GEMINI_HOST = "https://generativelanguage.googleapis.com";

/** Models the app is allowed to use through the proxy. */
const ALLOWED_MODELS = ["gemini-3.5-flash"];

/** Requests per person per day (a scan is a few requests: detect, assess, translate). */
const DAILY_LIMIT_SIGNED_IN = 300;
/** Per device address, for people not signed in (the app also limits guests to 5 uses a day). */
const DAILY_LIMIT_GUEST = 40;

/** Images are compressed by the app; this stops anything much bigger. */
const MAX_BODY_BYTES = 8 * 1024 * 1024;
const MAX_OUTPUT_TOKENS = 4096;
const UPSTREAM_TIMEOUT_MS = 100 * 1000;

// Only these parts of a request are passed on (no tools, no code execution).
const ALLOWED_BODY_KEYS = [
  "contents",
  "systemInstruction",
  "generationConfig",
  "safetySettings",
];

const PATH = /^\/v1beta\/models\/([a-z0-9.\-]+):generateContent$/;

function reply(status, message) {
  return {
    status,
    body: JSON.stringify({ error: { code: status, message } }),
  };
}

function dayKey(now) {
  return new Date(now).toISOString().slice(0, 10).replace(/-/g, "");
}

function callerIp(req) {
  const forwarded = req.headers && req.headers["x-forwarded-for"];
  const first = forwarded ? String(forwarded).split(",")[0].trim() : "";
  return first || req.ip || "unknown";
}

/**
 * Counts one request against today's allowance for [who]. Returns false when
 * the allowance is used up.
 */
async function takeAllowance(db, who, limit, now) {
  const ref = db.doc(`geminiUsage/${who}_${dayKey(now)}`);
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const used = snap.exists ? snap.get("count") || 0 : 0;
    if (used >= limit) return false;
    t.set(ref, { count: used + 1, day: dayKey(now) }, { merge: true });
    return true;
  });
}

/**
 * Handles one proxied request. Returns { status, body } (body is JSON text).
 * [fetchImpl] and [now] are replaceable for tests.
 */
async function handleGeminiProxy({
  db,
  auth,
  req,
  apiKey,
  fetchImpl = fetch,
  now = Date.now(),
}) {
  if (req.method !== "POST") return reply(405, "Use POST.");
  if (!apiKey) return reply(500, "The AI service is not set up.");

  const match = PATH.exec(req.path || "");
  if (!match || !ALLOWED_MODELS.includes(match[1])) {
    return reply(400, "That request is not allowed.");
  }

  const raw = req.rawBody;
  if (!raw || raw.length === 0) return reply(400, "Empty request.");
  if (raw.length > MAX_BODY_BYTES) return reply(413, "Request too large.");

  let body;
  try {
    body = JSON.parse(raw.toString("utf8"));
  } catch (_) {
    return reply(400, "Invalid request.");
  }
  if (!body || typeof body !== "object" || !Array.isArray(body.contents)) {
    return reply(400, "Invalid request.");
  }

  // Who is asking: a signed-in person (their sign-in token), or a guest
  // (counted by device address).
  let who;
  let limit;
  const header = (req.headers && req.headers.authorization) || "";
  if (header) {
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    try {
      const decoded = await auth.verifyIdToken(token);
      who = `u_${decoded.uid}`;
      limit = DAILY_LIMIT_SIGNED_IN;
    } catch (_) {
      return reply(401, "Please sign in again.");
    }
  } else {
    who = `g_${crypto.createHash("sha256").update(callerIp(req)).digest("hex").slice(0, 24)}`;
    limit = DAILY_LIMIT_GUEST;
  }

  if (!(await takeAllowance(db, who, limit, now))) {
    return reply(429, "Daily limit reached. Please try again tomorrow.");
  }

  const forwarded = {};
  for (const key of ALLOWED_BODY_KEYS) {
    if (body[key] !== undefined) forwarded[key] = body[key];
  }
  const config = forwarded.generationConfig;
  if (config && typeof config === "object") {
    const max = Number(config.maxOutputTokens);
    if (!Number.isFinite(max) || max > MAX_OUTPUT_TOKENS) {
      config.maxOutputTokens = MAX_OUTPUT_TOKENS;
    }
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const upstream = await fetchImpl(
      `${GEMINI_HOST}/v1beta/models/${match[1]}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify(forwarded),
        signal: controller.signal,
      }
    );
    return { status: upstream.status, body: await upstream.text() };
  } catch (_) {
    return reply(504, "The AI service did not answer. Please try again.");
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  handleGeminiProxy,
  ALLOWED_MODELS,
  DAILY_LIMIT_SIGNED_IN,
  DAILY_LIMIT_GUEST,
  MAX_BODY_BYTES,
  MAX_OUTPUT_TOKENS,
};
