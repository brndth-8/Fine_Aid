#!/usr/bin/env node
/*
 * Read-only: lists every phone-number and email reservation and which account
 * holds it.
 *
 *   node scripts/list-reservations.js
 *
 * Writes and deletes NOTHING. Phone numbers and emails are masked (last 4
 * digits / first letter + domain); usernames are shown. For each reservation
 * it also says whether the holder is a completed registration, whether the
 * holder still has that number/address on its profile, and flags anything
 * odd (a holder that no longer exists, or a profile that no longer uses it).
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it; delete it afterwards). --project overrides
 * the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

const maskPhone = (p) => `+63 ******${p.slice(-4)}`;
const maskEmail = (e) => {
  const [name, domain] = e.split("@");
  return `${name[0]}***@${domain ?? "?"}`;
};

function normalizePhone(raw) {
  const digits = typeof raw === "string" ? raw.replace(/\D/g, "") : "";
  let national = null;
  if (digits.length === 12 && digits.startsWith("63")) national = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) national = digits.slice(1);
  else if (digits.length === 10) national = digits;
  return national && /^9\d{9}$/.test(national) ? `+63${national}` : null;
}
const normalizeEmail = (raw) =>
  typeof raw === "string" && raw.trim() ? raw.trim().toLowerCase() : null;

(async () => {
  const [users, phones, emails] = await Promise.all([
    db.collection("users").get(),
    db.collection("phones").get(),
    db.collection("emails").get(),
  ]);
  const byUid = new Map(users.docs.map((d) => [d.id, d]));

  const describe = (holder) =>
    !holder
      ? "HOLDER NO LONGER EXISTS"
      : `${holder.get("username") ?? "?"} (${
          holder.get("registrationComplete") === true ? "complete" : "NOT complete"
        }${holder.get("phoneVerified") === true ? ", verified" : ""})`;

  let odd = 0;
  const section = (title, snap, mask, stillHas) => {
    console.log(`${title}: ${snap.size}`);
    const rows = snap.docs.map((d) => {
      const holder = byUid.get(d.get("uid"));
      const warn =
        !holder ? "  <-- stale: holder missing" : stillHas(holder, d.id) ? "" : "  <-- stale: profile no longer uses this";
      if (warn) odd++;
      return `  ${mask(d.id).padEnd(24)} ${describe(holder)}${warn}`;
    });
    rows.sort();
    rows.forEach((r) => console.log(r));
    console.log("");
  };

  console.log(`Project ${projectId} - READ ONLY\n`);
  section("PHONE RESERVATIONS", phones, maskPhone, (h, key) => normalizePhone(h.get("phoneNumber")) === key);
  section("EMAIL RESERVATIONS", emails, maskEmail, (h, key) => normalizeEmail(h.get("recoveryEmail")) === key);
  console.log(`${odd} reservation(s) look stale.`);
  console.log("Read only - nothing was written or deleted.");
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
