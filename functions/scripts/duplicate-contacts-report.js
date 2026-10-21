#!/usr/bin/env node
/*
 * Read-only report: do any accounts share a phone number or a recovery email?
 *
 *   node scripts/duplicate-contacts-report.js
 *
 * Writes and deletes NOTHING. Numbers and addresses are masked in the output
 * (last 4 digits / first letter + domain) so the report can be shared; the
 * usernames are shown so you can tell which accounts are involved.
 *
 * Phone numbers are compared after normalising +639171234567, 09171234567
 * and 9171234567 to the same value. Emails are compared case-insensitively.
 * Only completed registrations (registrationComplete == true) are counted by
 * default; add --all to include every profile.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it, delete it afterwards). Use --project to
 * override the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const ALL = args.includes("--all");
const i = args.indexOf("--project");
const projectId = i >= 0 ? args[i + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

function normalizePhone(raw) {
  if (typeof raw !== "string") return null;
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("63")) return digits.slice(2);
  if (digits.length === 11 && digits.startsWith("0")) return digits.slice(1);
  if (digits.length === 10) return digits;
  return digits || null;
}

const maskPhone = (p) => `+63 ******${p.slice(-4)}`;
const maskEmail = (e) => {
  const [name, domain] = e.split("@");
  return `${name[0]}***@${domain}`;
};

function groupDuplicates(rows, keyOf) {
  const groups = new Map();
  for (const r of rows) {
    const k = keyOf(r);
    if (!k) continue;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(r);
  }
  return [...groups.entries()].filter(([, v]) => v.length > 1);
}

(async () => {
  const snap = await db.collection("users").get();
  const rows = snap.docs
    .map((d) => ({ uid: d.id, ...d.data() }))
    .filter((r) => ALL || r.registrationComplete === true);

  console.log(
    `Project ${projectId} - READ ONLY. Profiles checked: ${rows.length}${ALL ? " (all)" : " (completed registrations)"}\n`
  );

  const withPhone = rows.filter((r) => normalizePhone(r.phoneNumber)).length;
  const withEmail = rows.filter((r) => (r.recoveryEmail || "").trim()).length;
  console.log(`Profiles with a phone number: ${withPhone}`);
  console.log(`Profiles with a recovery email: ${withEmail}\n`);

  const phoneDupes = groupDuplicates(rows, (r) => normalizePhone(r.phoneNumber));
  console.log(`DUPLICATE PHONE NUMBERS: ${phoneDupes.length} number(s) shared`);
  for (const [phone, list] of phoneDupes) {
    console.log(`  ${maskPhone(phone)} used by ${list.length} accounts:`);
    for (const r of list) {
      console.log(`    - ${r.username ?? "?"}  (phoneVerified=${r.phoneVerified === true})`);
    }
  }

  const emailDupes = groupDuplicates(rows, (r) =>
    (r.recoveryEmail || "").trim().toLowerCase()
  );
  console.log(`\nDUPLICATE RECOVERY EMAILS: ${emailDupes.length} address(es) shared`);
  for (const [email, list] of emailDupes) {
    console.log(`  ${maskEmail(email)} used by ${list.length} accounts:`);
    for (const r of list) {
      console.log(`    - ${r.username ?? "?"}`);
    }
  }

  console.log("\nRead only - nothing was written or deleted.");
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
