#!/usr/bin/env node
/*
 * Read-only report: how much each account that shares a phone number or a
 * recovery email has actually been used, to help decide which are extras.
 *
 *   node scripts/duplicate-accounts-activity-report.js
 *
 * Writes and deletes NOTHING. For every phone number / email shared by more
 * than one account it lists each account with:
 *   - whether registration was completed and the phone verified
 *   - when it was created and when it last signed in
 *   - how many journal entries it has
 * and marks which account holds the reservation (completed, then verified,
 * then oldest - the same rule the backfill used).
 *
 * Phone numbers and emails are masked (last 4 digits / first letter + domain).
 * Usernames are shown. Journal CONTENT is never read, only the count.
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

function normalizePhone(raw) {
  const digits = typeof raw === "string" ? raw.replace(/\D/g, "") : "";
  let national = null;
  if (digits.length === 12 && digits.startsWith("63")) national = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) national = digits.slice(1);
  else if (digits.length === 10) national = digits;
  return national && /^9\d{9}$/.test(national) ? `+63${national}` : null;
}

const maskPhone = (p) => `+63 ******${p.slice(-4)}`;
const maskEmail = (e) => {
  const [name, domain] = e.split("@");
  return `${name[0]}***@${domain}`;
};
const day = (ms) => (ms ? new Date(ms).toISOString().slice(0, 10) : "never");

const rank = (a, b) =>
  Number(b.complete) - Number(a.complete) ||
  Number(b.verified) - Number(a.verified) ||
  a.createdMs - b.createdMs ||
  a.uid.localeCompare(b.uid);

async function listAuthUsers() {
  const map = new Map();
  let token;
  do {
    const page = await admin.auth().listUsers(1000, token);
    for (const u of page.users) map.set(u.uid, u);
    token = page.pageToken;
  } while (token);
  return map;
}

(async () => {
  const [snap, authByUid] = await Promise.all([db.collection("users").get(), listAuthUsers()]);

  const accounts = new Map(); // uid -> info
  for (const d of snap.docs) {
    const au = authByUid.get(d.id);
    const created = d.get("createdAt");
    accounts.set(d.id, {
      uid: d.id,
      username: d.get("username") ?? "?",
      complete: d.get("registrationComplete") === true,
      verified: d.get("phoneVerified") === true,
      deactivated: d.get("deactivated") === true,
      createdMs: created && created.toMillis ? created.toMillis() : Number.MAX_SAFE_INTEGER,
      lastSignInMs: au && au.metadata.lastSignInTime ? Date.parse(au.metadata.lastSignInTime) : 0,
      hasAuth: !!au,
      phone: normalizePhone(d.get("phoneNumber")),
      email: typeof d.get("recoveryEmail") === "string" && d.get("recoveryEmail").trim()
        ? d.get("recoveryEmail").trim().toLowerCase()
        : null,
      entries: null,
    });
  }

  const group = (key) => {
    const m = new Map();
    for (const a of accounts.values()) {
      const k = a[key];
      if (!k) continue;
      if (!m.has(k)) m.set(k, []);
      m.get(k).push(a);
    }
    return [...m.entries()].filter(([, v]) => v.length > 1);
  };
  const phoneGroups = group("phone");
  const emailGroups = group("email");

  // Journal entry counts (a count only; entry content is not read).
  const inGroups = new Set();
  for (const [, v] of [...phoneGroups, ...emailGroups]) v.forEach((a) => inGroups.add(a.uid));
  for (const uid of inGroups) {
    const c = await db.collection(`users/${uid}/journalEntries`).count().get();
    accounts.get(uid).entries = c.data().count;
  }

  const row = (a, keeper) =>
    `    ${keeper ? "*" : " "} ${a.username.padEnd(16)} ` +
    `${(a.complete ? "complete" : "NOT complete").padEnd(12)} ` +
    `${(a.verified ? "verified" : "unverified").padEnd(10)} ` +
    `created ${day(a.createdMs === Number.MAX_SAFE_INTEGER ? 0 : a.createdMs)}  ` +
    `last sign-in ${day(a.lastSignInMs)}  ` +
    `entries ${a.entries}` +
    (a.deactivated ? "  [deactivated]" : "") +
    (a.hasAuth ? "" : "  [no sign-in account]");

  console.log(`Project ${projectId} - READ ONLY. Profiles: ${snap.size}\n`);
  console.log("(* = holds the reservation)\n");

  console.log(`SHARED PHONE NUMBERS: ${phoneGroups.length}`);
  for (const [phone, list] of phoneGroups) {
    list.sort(rank);
    console.log(`  ${maskPhone(phone)} - ${list.length} accounts`);
    list.forEach((a, i) => console.log(row(a, i === 0)));
  }

  console.log(`\nSHARED RECOVERY EMAILS: ${emailGroups.length}`);
  for (const [email, list] of emailGroups) {
    list.sort(rank);
    console.log(`  ${maskEmail(email)} - ${list.length} accounts`);
    list.forEach((a, i) => console.log(row(a, i === 0)));
  }

  // Accounts in a shared group that look unused: no journal entries and
  // either never signed in, or signed in only on the day they were created.
  const keepers = new Set();
  for (const [, v] of [...phoneGroups, ...emailGroups]) {
    v.sort(rank);
    keepers.add(v[0].uid);
  }
  const unused = [...inGroups]
    .map((uid) => accounts.get(uid))
    .filter(
      (a) =>
        a.entries === 0 &&
        (!a.lastSignInMs || day(a.lastSignInMs) === day(a.createdMs))
    )
    .sort((x, y) => x.username.localeCompare(y.username));
  console.log(`\nLOOK UNUSED (in a shared group, 0 journal entries, no sign-in after the day they were created): ${unused.length}`);
  unused.forEach((a) => console.log(row(a, keepers.has(a.uid))));

  console.log("\nRead only - nothing was written or deleted.");
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
