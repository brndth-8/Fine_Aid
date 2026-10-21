#!/usr/bin/env node
/*
 * One account per email: finds existing duplicates and backfills the
 * `emails/{email}` reservations for accounts that signed up before the rule
 * existed. NOT RUN YET (needs a service-account key and your go-ahead).
 *
 *   node scripts/email-uniqueness-backfill.js
 *       DRY RUN (default). Lists every email shared by more than one account
 *       and what --apply would do. Writes and deletes NOTHING.
 *       Addresses are masked (j***@gmail.com); add --show-emails to print them
 *       in full on your own screen so you can resolve them.
 *
 *   node scripts/email-uniqueness-backfill.js --apply
 *       For each address used by exactly ONE account: creates its reservation
 *       (never overwrites one that exists) and, if the stored address isn't
 *       already trimmed + lower-case, rewrites it that way.
 *       Addresses shared by several accounts are NOT touched at all: no
 *       reservation, no rewrite, no deletion, no merging. They stay exactly
 *       as they are for you to resolve by hand (e.g. ask the owners which
 *       account keeps the address, then clear it from the others in the
 *       admin portal's Edit dialog, which frees it).
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it; delete it afterwards). --project overrides
 * the project id.
 *
 * Run this BEFORE deploying the new rules and app build: once the rules are
 * live, an account whose email isn't reserved can still be edited, but only
 * accounts with a reservation are protected from a second sign-up using the
 * same address.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const SHOW = args.includes("--show-emails");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

const normalize = (raw) => raw.trim().toLowerCase();
const mask = (e) => {
  if (SHOW) return e;
  const [name, domain] = e.split("@");
  return `${name[0]}***@${domain}`;
};

(async () => {
  const snap = await db.collection("users").get();
  const byEmail = new Map(); // normalized -> [{uid, username, stored}]
  let withEmail = 0;
  const unusable = [];

  for (const d of snap.docs) {
    const stored = d.get("recoveryEmail");
    if (typeof stored !== "string" || stored.trim() === "") continue;
    withEmail++;
    const key = normalize(stored);
    if (key.includes("/")) {
      unusable.push({ uid: d.id, username: d.get("username") });
      continue;
    }
    if (!byEmail.has(key)) byEmail.set(key, []);
    byEmail.get(key).push({ uid: d.id, username: d.get("username"), stored });
  }

  const duplicates = [...byEmail.entries()].filter(([, v]) => v.length > 1);
  const singles = [...byEmail.entries()].filter(([, v]) => v.length === 1);

  console.log(
    `Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written)"}`
  );
  console.log(`Profiles: ${snap.size}; with an email: ${withEmail}`);
  console.log(`Unique addresses: ${singles.length}`);
  console.log(`\nDUPLICATE EMAILS: ${duplicates.length} address(es) shared`);
  for (const [email, list] of duplicates) {
    console.log(`  ${mask(email)} is used by ${list.length} accounts:`);
    for (const r of list) {
      console.log(`    - ${r.username ?? "?"}  (stored as ${SHOW ? r.stored : "…"})`);
    }
  }
  if (unusable.length) {
    console.log(`\nEmails that can't be reserved (contain "/"): ${unusable.length}`);
    for (const r of unusable) console.log(`    - ${r.username ?? "?"}`);
  }

  let reserved = 0;
  let alreadyReserved = 0;
  let rewritten = 0;
  for (const [email, [only]] of singles) {
    const ref = db.doc(`emails/${email}`);
    const existing = await ref.get();
    const needsReservation = !existing.exists;
    const needsRewrite = only.stored !== email;
    if (existing.exists && existing.get("uid") !== only.uid) {
      console.log(`  skip ${mask(email)}: reserved for a different account`);
      continue;
    }
    if (!needsReservation) alreadyReserved++;
    if (APPLY) {
      if (needsReservation) await ref.create({ uid: only.uid });
      if (needsRewrite) {
        await db.doc(`users/${only.uid}`).update({ recoveryEmail: email });
      }
    }
    if (needsReservation) reserved++;
    if (needsRewrite) rewritten++;
  }

  console.log(
    `\n${APPLY ? "Created" : "Would create"} ${reserved} reservation(s); ` +
      `${APPLY ? "rewrote" : "would rewrite"} ${rewritten} address(es) to ` +
      `lower-case; ${alreadyReserved} already reserved.`
  );
  console.log(
    `${duplicates.length} duplicated address(es) were left untouched for you ` +
      "to resolve manually. Nothing was deleted or merged."
  );
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
