#!/usr/bin/env node
/*
 * Frees phone numbers and emails that are reserved by GHOST accounts, so the
 * people who own those numbers can register.
 *
 *   node scripts/release-ghost-reservations.js            dry run: lists them
 *   node scripts/release-ghost-reservations.js --apply    frees them
 *
 * A reservation (phones/{+63...} or emails/{address}) is a ghost when its
 * holder
 *   - no longer exists (no profile), or
 *   - never finished signing up (and its sign-in account is gone or more than
 *     an hour old), or
 *   - finished signing up but its profile no longer uses that number/address.
 * A finished, in-use account is never touched. Only the reservation is
 * deleted and, if the unfinished profile still names it, that one field is
 * removed from that profile. Nothing else is deleted, and no account is
 * removed. The decision is the same one the app's `releaseStaleContact` cloud
 * function makes (lib/jobs.js).
 *
 * Numbers and emails are masked in the output. Needs
 * GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for the
 * project (never commit it; delete it afterwards). --project overrides the
 * project id.
 */
const admin = require("firebase-admin");
const jobs = require("../lib/jobs");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();
const auth = admin.auth();

const maskPhone = (p) => `+63 ******${p.slice(-4)}`;
const maskEmail = (e) => {
  const [name, domain] = e.split("@");
  return `${name[0]}***@${domain ?? "?"}`;
};

async function main() {
  console.log(`Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written)"}\n`);
  let ghosts = 0;
  let freed = 0;
  for (const [kind, collection] of [
    ["phone", "phones"],
    ["email", "emails"],
  ]) {
    const snap = await db.collection(collection).get();
    console.log(`${collection.toUpperCase()}: ${snap.size} reservation(s)`);
    for (const doc of snap.docs) {
      const key = doc.id;
      const holder = doc.get("uid");
      const isGhost = await jobs.isGhostHolder({ db, auth, kind, key, holder });
      if (!isGhost) continue;
      ghosts++;
      const profile = holder ? await db.collection("users").doc(holder).get() : null;
      const why = !profile || !profile.exists
        ? "holder no longer exists"
        : profile.get("registrationComplete") === true
          ? "holder's profile no longer uses it"
          : "sign-up never finished";
      const label = kind === "phone" ? maskPhone(key) : maskEmail(key);
      if (APPLY) {
        const r = await jobs.releaseStaleContact({
          db,
          auth,
          request: { auth: { uid: "cleanup-script" } },
          data: { kind, value: key },
        });
        if (r.released) freed++;
        console.log(`  ${label.padEnd(24)} ${why} -> ${r.released ? "FREED" : "kept (" + r.reason + ")"}`);
      } else {
        console.log(`  ${label.padEnd(24)} ${why} -> would be freed`);
      }
    }
  }
  console.log(
    APPLY
      ? `\nDone: ${freed} of ${ghosts} ghost reservation(s) freed.`
      : `\n${ghosts} ghost reservation(s). Dry run only - nothing was written. Add --apply to free them.`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
