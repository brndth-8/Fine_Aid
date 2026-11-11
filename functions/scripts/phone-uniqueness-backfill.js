#!/usr/bin/env node
/*
 * One account per phone number: reserves the `phones/{+639XXXXXXXXX}`
 * documents for accounts that signed up before the rule existed. NOT RUN YET
 * (needs a service-account key and your go-ahead).
 *
 *   node scripts/phone-uniqueness-backfill.js
 *       DRY RUN (default). Lists every number shared by more than one account
 *       and which account would keep the reservation. Writes and deletes
 *       NOTHING. Numbers are masked (last 4 digits); add --show-phones to
 *       print them in full on your own screen.
 *
 *   node scripts/phone-uniqueness-backfill.js --apply
 *       Creates a reservation for every distinct number (never overwrites
 *       one that exists). When several accounts share a number, the best
 *       account keeps the reservation: a completed registration first, then
 *       one whose phone was verified, then the OLDEST (by createdAt). An
 *       abandoned, unfinished sign-up never wins over a real account. The
 *       others are left
 *       exactly as they are: no change to their profile, no deletion, no
 *       merging. They keep working; they just can't be the target of a new
 *       sign-up, and if one of them changes its number it can't change back
 *       to the shared one.
 *
 * Numbers are compared in the standard +639XXXXXXXXX form, so 09171234567,
 * 9171234567 and +63 917 123 4567 count as the same number. The stored value
 * on the profile is NOT rewritten.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it; delete it afterwards). --project overrides
 * the project id.
 *
 * Run this BEFORE deploying the new rules and app build: until a number is
 * reserved, a new sign-up could still take it.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const SHOW = args.includes("--show-phones");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

/** Who keeps a shared number: completed, then verified, then oldest. */
const rank = (a, b) =>
  Number(b.complete) - Number(a.complete) ||
  Number(b.verified) - Number(a.verified) ||
  a.createdMs - b.createdMs ||
  a.uid.localeCompare(b.uid);

/** +639XXXXXXXXX from the usual ways of writing it, or null. */
function normalizePhone(raw) {
  const digits = typeof raw === "string" ? raw.replace(/\D/g, "") : "";
  let national = null;
  if (digits.length === 12 && digits.startsWith("63")) national = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) national = digits.slice(1);
  else if (digits.length === 10) national = digits;
  return national && /^9\d{9}$/.test(national) ? `+63${national}` : null;
}

const mask = (p) => (SHOW ? p : `+63 ******${p.slice(-4)}`);

(async () => {
  const snap = await db.collection("users").get();
  const byPhone = new Map(); // +63… -> [{uid, username, createdMs, verified}]
  const unusable = [];
  let withPhone = 0;

  for (const d of snap.docs) {
    const stored = d.get("phoneNumber");
    if (typeof stored !== "string" || stored.trim() === "") continue;
    withPhone++;
    const key = normalizePhone(stored);
    if (!key) {
      unusable.push({ uid: d.id, username: d.get("username") });
      continue;
    }
    const created = d.get("createdAt");
    if (!byPhone.has(key)) byPhone.set(key, []);
    byPhone.get(key).push({
      uid: d.id,
      username: d.get("username"),
      createdMs: created && created.toMillis ? created.toMillis() : Number.MAX_SAFE_INTEGER,
      verified: d.get("phoneVerified") === true,
      complete: d.get("registrationComplete") === true,
    });
  }

  const groups = [...byPhone.entries()];
  const duplicates = groups.filter(([, v]) => v.length > 1);

  console.log(
    `Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written)"}`
  );
  console.log(`Profiles: ${snap.size}; with a phone number: ${withPhone}`);
  console.log(`Distinct numbers: ${groups.length}`);
  console.log(`\nSHARED NUMBERS: ${duplicates.length}`);
  for (const [phone, list] of duplicates) {
    list.sort(rank);
    console.log(`  ${mask(phone)} is used by ${list.length} accounts:`);
    list.forEach((r, i) => {
      console.log(
        `    - ${r.username ?? "?"} (${r.complete ? "complete" : "NOT complete"}${r.verified ? ", verified" : ""})${i === 0 ? "  <- keeps the reservation" : ""}`
      );
    });
  }
  if (unusable.length) {
    console.log(`\nNumbers that aren't a valid PH mobile number: ${unusable.length}`);
    for (const r of unusable) console.log(`    - ${r.username ?? "?"}`);
  }

  let created = 0;
  let already = 0;
  for (const [phone, list] of groups) {
    list.sort(rank);
    const winner = list[0];
    const ref = db.doc(`phones/${phone}`);
    const existing = await ref.get();
    if (existing.exists) {
      already++;
      if (existing.get("uid") !== winner.uid) {
        console.log(`  note ${mask(phone)}: already reserved for a different account, left as is`);
      }
      continue;
    }
    if (APPLY) await ref.create({ uid: winner.uid });
    created++;
  }

  console.log(
    `\n${APPLY ? "Created" : "Would create"} ${created} reservation(s); ${already} already reserved.`
  );
  console.log(
    `${duplicates.length} shared number(s): the oldest account keeps each reservation; ` +
      "the other accounts were not touched. Nothing was deleted, merged or rewritten."
  );
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
