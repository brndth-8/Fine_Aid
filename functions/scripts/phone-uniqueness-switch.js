#!/usr/bin/env node
/*
 * The on/off switch for the phone-number rule in firestore.rules.
 *
 *   node scripts/phone-uniqueness-switch.js          show whether it is on
 *   node scripts/phone-uniqueness-switch.js --on     turn enforcement ON
 *   node scripts/phone-uniqueness-switch.js --off    turn it OFF again
 *
 * It writes one document, appConfig/phoneUniqueness = { enforce: true|false }.
 * While it is off (the default), profiles can be saved with a phone number
 * without a reservation, so app versions that don't know about phone
 * reservations keep working. The new app reserves numbers either way.
 * Turn it ON once most people have updated: from then on the server refuses a
 * profile that sets or changes a phone number it doesn't hold the reservation
 * for (see "PHONE UNIQUENESS" in firestore.rules). Turning it OFF again is
 * always safe.
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
const ref = admin.firestore().doc("appConfig/phoneUniqueness");

(async () => {
  const snap = await ref.get();
  const current = snap.exists && snap.get("enforce") === true;
  console.log(`Project ${projectId}: phone-number rule is currently ${current ? "ON" : "OFF"}.`);
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
