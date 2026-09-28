const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// Set this before deploying:
//   firebase functions:secrets:set SEMAPHORE_API_KEY
const SEMAPHORE_API_KEY = defineSecret("SEMAPHORE_API_KEY");

// Set these before deploying, for the email half of "forgot password":
//   firebase functions:secrets:set SMTP_USER
//   firebase functions:secrets:set SMTP_PASS
// Any SMTP account works (eg a Gmail address with a 16-character "app
// password" generated under Google Account > Security > App passwords —
// not the regular account password). A transactional email provider
// (Resend, SendGrid, Mailgun, etc) works the same way if preferred later;
// only these two secrets and the host/port below would need to change.
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

const OTP_COLLECTION = "passwordResetOtps";
const ACCOUNT_VERIFICATION_COLLECTION = "accountVerificationOtps";
const OTP_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Shared by both email-OTP functions (password reset and account
// verification) — same SMTP secrets, just a different subject/body.
async function sendOtpEmail(to, subject, text) {
  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: SMTP_USER.value(), pass: SMTP_PASS.value() },
  });
  await transporter.sendMail({
    from: `"Fine Aid" <${SMTP_USER.value()}>`,
    to,
    subject,
    text,
  });
}

// Mirrors SemaphoreService._formatNumber on the Flutter side.
function formatPhilippineNumber(phoneNumber) {
  if (phoneNumber.startsWith("+63")) return `0${phoneNumber.substring(3)}`;
  if (phoneNumber.startsWith("09")) return phoneNumber;
  if (phoneNumber.startsWith("9") && phoneNumber.length === 10) {
    return `0${phoneNumber}`;
  }
  return phoneNumber;
}

// Mirrors lib/core/password_requirements.dart on the Flutter side, so a
// password rejected here would have been rejected at signup too.
const COMMON_PASSWORDS = [
  "password",
  "password1",
  "password123",
  "12345678",
  "123456789",
  "1234567890",
  "qwerty123",
  "qwertyui",
  "letmein1",
  "welcome1",
  "admin123",
  "iloveyou",
  "abc12345",
  "87654321",
  "changeme",
];

function isValidPassword(password) {
  if (typeof password !== "string" || password.length < 8) return false;
  if (!/[A-Z]/.test(password)) return false;
  if (!/[a-z]/.test(password)) return false;
  if (!/[0-9]/.test(password)) return false;
  if (!/[!@#$%^&*(),.?":{}|<>_\-+=[\];/\\`~]/.test(password)) return false;
  if (COMMON_PASSWORDS.includes(password.toLowerCase())) return false;
  return true;
}

/**
 * Step 1 of the "forgot password" flow: looks up the account by username,
 * generates a 6-digit OTP, stores it server-side, and sends it via
 * Semaphore SMS to the phone number on file for that account.
 *
 * Always returns { sent: true } even when the username doesn't exist, so
 * the response can't be used to enumerate registered usernames.
 */
exports.sendPasswordResetOtp = onCall(
  { secrets: [SEMAPHORE_API_KEY] },
  async (request) => {
    const username = (request.data && request.data.username || "")
      .trim()
      .toLowerCase();
    if (!username) {
      throw new HttpsError("invalid-argument", "Username is required.");
    }

    const usernameDoc = await db.collection("usernames").doc(username).get();
    if (!usernameDoc.exists) {
      return { sent: true };
    }

    const uid = usernameDoc.data().uid;
    const userDoc = await db.collection("users").doc(uid).get();
    const phoneNumber = userDoc.data() && userDoc.data().phoneNumber;
    if (!phoneNumber) {
      return { sent: true };
    }

    const code = generateCode();
    const formattedNumber = formatPhilippineNumber(phoneNumber);

    await db
      .collection(OTP_COLLECTION)
      .doc(uid)
      .set({
        code,
        username,
        phoneNumber: formattedNumber,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + OTP_TTL_MINUTES * 60 * 1000
        ),
        attempts: 0,
      });

    const response = await fetch("https://api.semaphore.co/api/v4/otp", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        apikey: SEMAPHORE_API_KEY.value(),
        number: formattedNumber,
        message:
          "Your Fine Aid password reset code is {otp}. Valid for 10 " +
          "minutes. Do not share this code.",
        code,
        sendername: "FINEAID",
      }),
    });

    if (!response.ok) {
      throw new HttpsError(
        "internal",
        "Failed to send the reset code. Please try again."
      );
    }

    return { sent: true };
  }
);

/**
 * Same as sendPasswordResetOtp above, but for accounts that added a
 * recovery email (users/{uid}.recoveryEmail, set from Edit Profile or at
 * registration — optional, so not every account has one). Writes to the
 * same passwordResetOtps/{uid} doc, so verifyPasswordResetOtp below
 * handles both delivery methods identically once the user has the code.
 *
 * Always returns { sent: true } even when the username doesn't exist or
 * has no recovery email on file, so the response can't be used to
 * enumerate registered usernames or which accounts have added an email.
 */
exports.sendPasswordResetOtpEmail = onCall(
  { secrets: [SMTP_USER, SMTP_PASS] },
  async (request) => {
    const username = (request.data && request.data.username || "")
      .trim()
      .toLowerCase();
    if (!username) {
      throw new HttpsError("invalid-argument", "Username is required.");
    }

    const usernameDoc = await db.collection("usernames").doc(username).get();
    if (!usernameDoc.exists) {
      return { sent: true };
    }

    const uid = usernameDoc.data().uid;
    const userDoc = await db.collection("users").doc(uid).get();
    const recoveryEmail = userDoc.data() && userDoc.data().recoveryEmail;
    if (!recoveryEmail) {
      return { sent: true };
    }

    const code = generateCode();

    await db
      .collection(OTP_COLLECTION)
      .doc(uid)
      .set({
        code,
        username,
        recoveryEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + OTP_TTL_MINUTES * 60 * 1000
        ),
        attempts: 0,
      });

    try {
      await sendOtpEmail(
        recoveryEmail,
        "Your Fine Aid password reset code",
        `Your Fine Aid password reset code is ${code}. It's valid for ` +
          `${OTP_TTL_MINUTES} minutes. Do not share this code with anyone.`
      );
    } catch (err) {
      throw new HttpsError(
        "internal",
        "Failed to send the reset code. Please try again."
      );
    }

    return { sent: true };
  }
);

/**
 * Step 2: verifies the OTP server-side (never trust a client-only check
 * for something this sensitive) and, only if it's valid, uses the Admin
 * SDK to set the account's new password directly — the client SDK has no
 * way to do this without the old password.
 */
exports.verifyPasswordResetOtp = onCall(async (request) => {
  const data = request.data || {};
  const username = (data.username || "").trim().toLowerCase();
  const code = (data.code || "").trim();
  const newPassword = data.newPassword || "";

  if (!username || !code) {
    throw new HttpsError(
      "invalid-argument",
      "Username and code are required."
    );
  }
  if (!isValidPassword(newPassword)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 8 characters and include an uppercase " +
        "letter, a lowercase letter, a number, a special character, and " +
        "must not be a commonly used password."
    );
  }

  const usernameDoc = await db.collection("usernames").doc(username).get();
  if (!usernameDoc.exists) {
    throw new HttpsError("not-found", "Verification failed. Please try again.");
  }
  const uid = usernameDoc.data().uid;

  const otpRef = db.collection(OTP_COLLECTION).doc(uid);
  const otpDoc = await otpRef.get();
  if (!otpDoc.exists) {
    throw new HttpsError(
      "not-found",
      "No reset request found. Please start again."
    );
  }

  const otpData = otpDoc.data();
  if ((otpData.attempts || 0) >= MAX_ATTEMPTS) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many attempts. Please request a new code."
    );
  }

  await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

  const expiresAtMs = otpData.expiresAt && otpData.expiresAt.toMillis
    ? otpData.expiresAt.toMillis()
    : 0;
  if (Date.now() > expiresAtMs) {
    throw new HttpsError(
      "deadline-exceeded",
      "Code has expired. Please request a new one."
    );
  }

  if (otpData.code !== code) {
    throw new HttpsError("permission-denied", "Incorrect code. Please try again.");
  }

  await admin.auth().updateUser(uid, { password: newPassword });
  await otpRef.delete();

  return { success: true };
});

/**
 * Registration's email-verification path (the alternative to the phone
 * OTP flow) — sends a 6-digit code to the account's recoveryEmail, which
 * is required at registration time whenever "Email" was chosen as the
 * verification method. Uses request.auth.uid (the caller is already
 * signed in at this point, right after registering) rather than a
 * username lookup, since this isn't a "forgot password"-style flow where
 * the caller might not be authenticated yet.
 */
exports.sendAccountVerificationOtpEmail = onCall(
  { secrets: [SMTP_USER, SMTP_PASS] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    const recoveryEmail = userDoc.data() && userDoc.data().recoveryEmail;
    if (!recoveryEmail) {
      throw new HttpsError(
        "failed-precondition",
        "No email address on file for this account."
      );
    }

    const code = generateCode();
    await db
      .collection(ACCOUNT_VERIFICATION_COLLECTION)
      .doc(uid)
      .set({
        code,
        recoveryEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + OTP_TTL_MINUTES * 60 * 1000
        ),
        attempts: 0,
      });

    try {
      await sendOtpEmail(
        recoveryEmail,
        "Verify your Fine Aid account",
        `Your Fine Aid verification code is ${code}. It's valid for ` +
          `${OTP_TTL_MINUTES} minutes. Do not share this code with anyone.`
      );
    } catch (err) {
      throw new HttpsError(
        "internal",
        "Failed to send the verification code. Please try again."
      );
    }

    return { sent: true };
  }
);

/**
 * Verifies the code from sendAccountVerificationOtpEmail above and, if
 * correct, marks the account verified — reuses the same `phoneVerified`
 * flag AuthGate already checks to gate onboarding, regardless of which
 * channel (SMS or email) actually did the verifying.
 */
exports.verifyAccountVerificationOtp = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const code = ((request.data && request.data.code) || "").trim();
  if (!code) {
    throw new HttpsError("invalid-argument", "Code is required.");
  }

  const otpRef = db.collection(ACCOUNT_VERIFICATION_COLLECTION).doc(uid);
  const otpDoc = await otpRef.get();
  if (!otpDoc.exists) {
    throw new HttpsError(
      "not-found",
      "No verification request found. Please start again."
    );
  }

  const otpData = otpDoc.data();
  if ((otpData.attempts || 0) >= MAX_ATTEMPTS) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many attempts. Please request a new code."
    );
  }

  await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

  const expiresAtMs = otpData.expiresAt && otpData.expiresAt.toMillis
    ? otpData.expiresAt.toMillis()
    : 0;
  if (Date.now() > expiresAtMs) {
    throw new HttpsError(
      "deadline-exceeded",
      "Code has expired. Please request a new one."
    );
  }

  if (otpData.code !== code) {
    throw new HttpsError("permission-denied", "Incorrect code. Please try again.");
  }

  await db.collection("users").doc(uid).update({ phoneVerified: true });
  await otpRef.delete();

  return { success: true };
});

/**
 * Fans a newly-created admin announcement out as a real FCM push
 * notification, so it reaches users even while the app is fully closed —
 * not deployed yet (requires the Blaze plan, same as the OTP functions
 * above), but ready to go once you deploy. The client subscribes every
 * install to the "all_users" topic in NotificationService.initialize(),
 * so no per-device token registry is needed here.
 */
exports.sendSystemNotificationPush = onDocumentCreated(
  "systemNotifications/{notifId}",
  async (event) => {
    const data = event.data && event.data.data();
    if (!data) return;
    // A scheduled-for-later announcement has no sentAt yet — leave it
    // alone here; sendScheduledSystemNotifications below sends it (and
    // stamps sentAt) once it's actually due.
    if (data.status === "scheduled") return;

    const title = data.title || "Fine Aid Update";
    const body = data.body || "";

    await admin.messaging().send({
      topic: "all_users",
      notification: { title, body },
      android: { priority: "high" },
    });
  }
);

/**
 * Runs every 5 minutes looking for admin announcements the "Schedule"
 * button queued for a future time that's now due, stamps them as sent,
 * and sends the push (sendSystemNotificationPush above only fires at
 * document *creation*, before scheduledFor has arrived, so this is the
 * only place a scheduled announcement's push actually goes out).
 */
exports.sendScheduledSystemNotifications = onSchedule(
  "every 5 minutes",
  async () => {
    const db2 = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const dueDocs = await db2
      .collection("systemNotifications")
      .where("status", "==", "scheduled")
      .where("scheduledFor", "<=", now)
      .get();

    if (dueDocs.empty) return;

    await Promise.all(
      dueDocs.docs.map(async (doc) => {
        const data = doc.data();
        await doc.ref.update({
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await admin.messaging().send({
          topic: "all_users",
          notification: {
            title: data.title || "Fine Aid Update",
            body: data.body || "",
          },
          android: { priority: "high" },
        });
      })
    );
  }
);
