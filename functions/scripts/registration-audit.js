#!/usr/bin/env node
/*
 * Sign-up completeness audit + backfill. NOT RUN YET: needs your approval.
 *
 * Background: sign-up used to be several separate writes, so a failed attempt
 * could leave a sign-in account, a `users/{uid}` profile and/or a
 * `usernames/{name}` reservation without the others. The app now writes the
 * profile and the username together and marks the profile
 * `registrationComplete: true`; the Admin portal lists only those. Profiles
 * that existed before that need the marker too, or they would disappear from
 * the portal.
 *
 *   node scripts/registration-audit.js
 *       DRY RUN (default). Writes nothing and deletes nothing. Prints:
 *         - HEALTHY profiles that would get the marker (the profile has a
 *           matching username reservation owned by the same uid)
 *         - ORPHANS, which are never touched, only listed:
 *             a) sign-in accounts with no profile
 *             b) profiles with no matching username reservation
 *             c) username reservations whose profile is missing
 *   node scripts/registration-audit.js --apply
 *       Sets `registrationComplete: true` on the HEALTHY profiles only
 *       (merge, nothing else changes). Still deletes nothing.
 *
 * Run order: deploy the new index, run this with --apply, THEN ship the Admin
 * portal / app build that filters on `registrationComplete`. Orphans stay
 * hidden from the portal and are resolved by hand once you have seen the
 * report (the app lets a person continue an unfinished sign-up by signing up
 * again with the same password).
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it). Use --project to override the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const i = args.indexOf("--project");
const projectId = i >= 0 ? args[i + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

async function listAllAuthUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

(async () => {
  console.log(
    `Project ${projectId} - ${APPLY ? "APPLY (marks healthy profiles)" : "DRY RUN (writes nothing)"}\n`
  );

  const [authUsers, profileSnap, nameSnap, adminSnap] = await Promise.all([
    listAllAuthUsers(),
    db.collection("users").get(),
    db.collection("usernames").get(),
    db.collection("admins").get(),
  ]);

  const adminUids = new Set(adminSnap.docs.map((d) => d.id));
  const profiles = new Map(profileSnap.docs.map((d) => [d.id, d.data()]));
  const authUids = new Set(authUsers.map((u) => u.uid));

  // uid -> the reservation doc ids that point at it
  const reservationsByUid = new Map();
  for (const d of nameSnap.docs) {
    const uid = d.data().uid;
    if (!reservationsByUid.has(uid)) reservationsByUid.set(uid, []);
    reservationsByUid.get(uid).push(d.id);
  }

  const healthy = [];
  const alreadyMarked = [];
  const profileNoName = [];
  for (const [uid, data] of profiles) {
    if (data.registrationComplete === true) {
      alreadyMarked.push(uid);
      continue;
    }
    if ((reservationsByUid.get(uid) || []).length > 0) {
      healthy.push(uid);
    } else {
      profileNoName.push(uid);
    }
  }

  const authNoProfile = authUsers.filter(
    (u) => !profiles.has(u.uid) && !adminUids.has(u.uid)
  );
  const nameNoProfile = nameSnap.docs.filter((d) => !profiles.has(d.data().uid));

  const label = (uid) => {
    const p = profiles.get(uid) || {};
    const a = authUsers.find((u) => u.uid === uid);
    return `${uid}  username=${p.username ?? "?"}  auth=${a ? "yes" : "NO"}  phoneVerified=${p.phoneVerified === true}`;
  };

  console.log(`Sign-in accounts: ${authUsers.length}  Profiles: ${profiles.size}  Reservations: ${nameSnap.size}`);
  console.log(`\nHEALTHY, would get the marker: ${healthy.length}`);
  healthy.forEach((u) => console.log("  " + label(u)));
  console.log(`\nAlready marked: ${alreadyMarked.length}`);

  console.log(`\nORPHAN (a) sign-in account with no profile: ${authNoProfile.length}`);
  authNoProfile.forEach((u) =>
    console.log(`  ${u.uid}  ${u.email}  created ${u.metadata.creationTime}`)
  );
  console.log(`\nORPHAN (b) profile with no username reservation: ${profileNoName.length}`);
  profileNoName.forEach((u) => console.log("  " + label(u)));
  console.log(`\nORPHAN (c) username reservation with no profile: ${nameNoProfile.length}`);
  nameNoProfile.forEach((d) =>
    console.log(`  usernames/${d.id}  uid=${d.data().uid}  auth=${authUids.has(d.data().uid) ? "yes" : "NO"}`)
  );

  if (!APPLY) {
    console.log("\nDry run only - nothing was written. Re-run with --apply to mark the HEALTHY profiles.");
    return;
  }

  let n = 0;
  for (let k = 0; k < healthy.length; k += 400) {
    const batch = db.batch();
    for (const uid of healthy.slice(k, k + 400)) {
      batch.set(db.collection("users").doc(uid), { registrationComplete: true }, { merge: true });
      n++;
    }
    await batch.commit();
  }
  console.log(`\nMarked ${n} profiles. Nothing was deleted.`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
