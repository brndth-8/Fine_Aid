// Sending the sign-up / phone-change SMS code. The Semaphore key lives only on
// the server (Secret Manager); the app asks this to send, and the code is
// stored where only the server can read it (accountVerificationOtps/{uid}),
// then checked by verifyAccountVerificationOtp in index.js.
const { HttpsError } = require("firebase-functions/v2/https");

const COLLECTION = "accountVerificationOtps";
const OTP_TTL_MINUTES = 10;
/** The app shows a 60 s "resend" countdown; a little less here absorbs clock drift. */
const COOLDOWN_MS = 55 * 1000;
/** At most this many texts per person per rolling hour (stops SMS-credit drain). */
const MAX_SENDS_PER_HOUR = 5;
const HOUR_MS = 60 * 60 * 1000;
const SEMAPHORE_URL = "https://api.semaphore.co/api/v4/otp";
const SENDER_NAME = "FINEAID";

/** "+639..." / "09..." / "9..." -> "09...". Same rules the app used. */
function formatPhilippineNumber(phoneNumber) {
  if (phoneNumber.startsWith("+63")) return `0${phoneNumber.substring(3)}`;
  if (phoneNumber.startsWith("09")) return phoneNumber;
  if (phoneNumber.startsWith("9") && phoneNumber.length === 10) {
    return `0${phoneNumber}`;
  }
  return phoneNumber;
}

/** A Philippine mobile number in local form: 09xxxxxxxxx (or the 08 ranges). */
function isMobileNumber(formatted) {
  return /^0[89]\d{9}$/.test(formatted);
}

/** Semaphore answers with a list of messages (Pending/Queued/Sent) or an object. */
function semaphoreAccepted(body) {
  if (Array.isArray(body)) {
    if (body.length === 0) return false;
    const status = String(body[0] && body[0].status).toLowerCase();
    return status === "pending" || status === "queued" || status === "sent";
  }
  return body !== null && typeof body === "object";
}

/**
 * Sends a verification code to the signed-in caller.
 *
 * [phoneNumber] is optional: with none, the number on the account is used
 * (sign-up); with one, that number is used (Edit Profile checks a new number
 * before saving it). Either way the code goes to a number the server
 * validated, and the caller is limited by cooldown and an hourly cap.
 *
 * deps: { db, uid, phoneNumber, apiKey, fetchImpl, now, generateCode,
 *         timestampFromMillis, serverTime }
 */
async function sendAccountVerificationOtpSms(deps) {
  const { db, uid, apiKey, fetchImpl, now, generateCode } = deps;

  let number = typeof deps.phoneNumber === "string" ? deps.phoneNumber.trim() : "";
  if (!number) {
    const userDoc = await db.doc(`users/${uid}`).get();
    number = (userDoc.exists && userDoc.data().phoneNumber) || "";
  }
  if (!number) {
    throw new HttpsError(
      "failed-precondition",
      "No phone number on file for this account."
    );
  }
  const formatted = formatPhilippineNumber(number);
  if (!isMobileNumber(formatted)) {
    throw new HttpsError("invalid-argument", "That is not a valid mobile number.");
  }

  const ref = db.doc(`${COLLECTION}/${uid}`);
  const previous = await ref.get();
  const recent = ((previous.exists && previous.data().recentSends) || []).filter(
    (t) => now - t < HOUR_MS
  );
  if (recent.length > 0 && now - Math.max(...recent) < COOLDOWN_MS) {
    throw new HttpsError(
      "resource-exhausted",
      "Please wait a minute before asking for another code."
    );
  }
  if (recent.length >= MAX_SENDS_PER_HOUR) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many codes requested. Please try again in an hour."
    );
  }

  const code = generateCode();
  await ref.set({
    code,
    phoneNumber: formatted,
    createdAt: deps.serverTime(),
    expiresAt: deps.timestampFromMillis(now + OTP_TTL_MINUTES * 60 * 1000),
    attempts: 0,
    recentSends: [...recent, now],
  });

  let ok = false;
  try {
    const response = await fetchImpl(SEMAPHORE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        apikey: apiKey,
        number: formatted,
        message:
          "Your Fine Aid OTP code is {otp}. Valid for 10 minutes. " +
          "Do not share this code.",
        code,
        sendername: SENDER_NAME,
      }),
    });
    if (response.ok) {
      ok = semaphoreAccepted(await response.json());
    } else {
      // Never log the request (it holds the key); the status alone is enough.
      console.error(`sendAccountVerificationOtpSms: Semaphore ${response.status}`);
    }
  } catch (err) {
    console.error("sendAccountVerificationOtpSms: send failed:", err && err.message);
  }
  if (!ok) {
    throw new HttpsError(
      "internal",
      "Failed to send the code. Please check the phone number and try again."
    );
  }
  return { sent: true };
}

module.exports = {
  COLLECTION,
  COOLDOWN_MS,
  MAX_SENDS_PER_HOUR,
  OTP_TTL_MINUTES,
  formatPhilippineNumber,
  isMobileNumber,
  semaphoreAccepted,
  sendAccountVerificationOtpSms,
};
