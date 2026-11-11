#!/usr/bin/env node
/*
 * The on/off switch for the SMS-verification rules in firestore.rules.
 *
 *   node scripts/sms-verification-switch.js          show whether it is on
 *   node scripts/sms-verification-switch.js --on     turn enforcement ON
 *   node scripts/sms-verification-switch.js --off    turn it OFF again
 *
 * It writes one document, appConfig/smsVerification = { enforce: true|false }.
 * While it is off (the default), older app builds can still keep their own
 * verification code in `otpVerifications` and mark themselves verified. Turn
 * it ON only once the new app build (which asks the Cloud Functions to send
 * and check the code) is out: from then on `otpVerifications` is closed to the
 * app and only the server can set `phoneVerified` (see "SMS VERIFICATION" in
 * firestore.rules). Turning it OFF again is always safe.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it; delete it afterwards). --project overrides
 * the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";
if (args.includes("--on") && args.includes("--off")) {
  console.error("Choose --on or --off, not both.");
  process.exit(1);
}

admin.initializeApp({ projectId });
const ref = admin.firestore().doc("appConfig/smsVerification");

(async () => {
  const snap = await ref.get();
  const current = snap.exists && snap.get("enforce") === true;
  console.log(`Project ${projectId}: SMS-verification rules are currently ${current ? "ON" : "OFF"}.`);
  if (args.includes("--on") || args.includes("--off")) {
    const want = args.includes("--on");
    await ref.set({ enforce: want }, { merge: true });
    console.log(`Switched ${want ? "ON" : "OFF"}.`);
  } else {
    console.log("(No change made. Use --on or --off.)");
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
