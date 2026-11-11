#!/usr/bin/env node
/*
 * Removes the accounts YOU NAME (test accounts, duplicates) together with the
 * phone/email reservations they hold. Dry run by default.
 *
 *   node scripts/remove-unused-duplicate-accounts.js --usernames bob,rhei
 *       DRY RUN. Shows, for each named account, exactly what would be
 *       deleted, which accounts are skipped by the safety checks, and what
 *       would happen to each phone/email reservation they held. Writes and
 *       deletes NOTHING. Usernames are case-sensitive (Bob is not bob).
 *
 *   node scripts/remove-unused-duplicate-accounts.js --usernames bob,rhei --apply
 *       Does it. First writes a backup of every document it is about to
 *       delete to ./remove-accounts-backup-<time>.json (it stops if it can't).
 *       The backup holds personal data (phone, email, names): keep it private
 *       and delete it when you no longer need it. A sign-in (Auth) account
 *       can NOT be restored from it, so deleting one is permanent.
 *
 * SAFETY CHECKS, re-run at the moment of deleting. An account is SKIPPED
 * (left completely untouched) unless ALL of these hold:
 *   - exactly one profile has that username
 *   - it is not an admin
 *   - its phone is NOT verified and onboarding is NOT complete
 *   - it has 0 journal entries
 * i.e. only accounts that were never really used are removed by default.
 *
 *   --include-used
 *       Lifts the last two checks (verified phone / completed onboarding /
 *       journal entries) for the accounts you named, so a USED account is
 *       removed together with its journal entries. Use it only for accounts
 *       you are sure are tests. Admins are still never removed. The dry run
 *       prints what would be lost (entry counts) so you can check first.
 *
 * For each removed account it deletes: the sign-in account, the profile and
 * everything under it (journal entries, notifications etc.), its username
 * record(s), and its verification-code record. It does NOT delete files in
 * Storage (eg journal photos), audit-log entries, feedback or anything else
 * that mentions the user, and it does not touch any other account.
 *
 * Reservations: a phone/email reservation held by a removed account is
 * handed to the best remaining account that has the same number/address
 * (completed, then verified, then with journal entries, then oldest), or
 * deleted if none remains (which frees the number/address).
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it; delete it afterwards). --project overrides
 * the project id.
 */
const fs = require("node:fs");
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const INCLUDE_USED = args.includes("--include-used");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

const ui = args.indexOf("--usernames");
const names = ui >= 0 && args[ui + 1] && !args[ui + 1].startsWith("--")
  ? [...new Set(args[ui + 1].split(",").map((n) => n.trim()).filter(Boolean))]
  : [];
if (names.length === 0) {
  console.error(
    "Name the accounts to remove, eg:\n" +
      "  node scripts/remove-unused-duplicate-accounts.js --usernames bob,rhei\n" +
      "(usernames are case-sensitive, separated by commas, no spaces)"
  );
  process.exit(1);
}
const TARGETS = names.map((n) => ["-", n]);

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
const normalizeEmail = (raw) =>
  typeof raw === "string" && raw.trim() ? raw.trim().toLowerCase() : null;
const maskPhone = (p) => `+63 ******${p.slice(-4)}`;
const maskEmail = (e) => `${e[0]}***@${e.split("@")[1]}`;

async function journalCount(uid) {
  return (await db.collection(`users/${uid}/journalEntries`).count().get()).data().count;
}

(async () => {
  console.log(`Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written or deleted)"}\n`);

  const all = await db.collection("users").get();
  const profiles = all.docs.map((d) => ({
    uid: d.id,
    ref: d.ref,
    data: d.data(),
    username: d.get("username"),
  }));

  // ---- 1. resolve and check the targets ---------------------------------
  const go = []; // accounts that pass every check
  for (const [group, name] of TARGETS) {
    const matches = profiles.filter((p) => p.username === name);
    if (matches.length !== 1) {
      console.log(`SKIP ${name}: ${matches.length} profiles have that username`);
      continue;
    }
    const p = matches[0];
    if ((await db.doc(`admins/${p.uid}`).get()).exists) {
      console.log(`SKIP ${name}: this is an admin account - never removed`);
      continue;
    }
    const entries = await journalCount(p.uid);
    const why = [];
    if (p.data.phoneVerified === true) why.push("phone is verified");
    if (p.data.onboardingComplete === true) why.push("onboarding is complete");
    if (entries > 0) why.push(`has ${entries} journal entries`);
    if (why.length && !INCLUDE_USED) {
      console.log(
        `SKIP ${name}: ${why.join(", ")} - left untouched ` +
          "(add --include-used if it really is a test account)"
      );
      continue;
    }
    if (why.length) {
      console.log(`NOTE ${name} is a USED account (${why.join(", ")}) - removing it because of --include-used`);
    }
    go.push({ group, entries, ...p, phone: normalizePhone(p.data.phoneNumber), email: normalizeEmail(p.data.recoveryEmail) });
  }
  const removing = new Set(go.map((a) => a.uid));

  // ---- 2. what each removal would delete --------------------------------
  const plan = [];
  console.log(`\nWOULD REMOVE ${go.length} account(s):`);
  for (const a of go) {
    const nameDocs = (await db.collection("usernames").where("uid", "==", a.uid).get()).docs;
    const otp = await db.doc(`otpVerifications/${a.uid}`).get();
    let authExists = true;
    try { await admin.auth().getUser(a.uid); } catch (_) { authExists = false; }
    plan.push({ a, nameDocs, otp, authExists });
    console.log(
      `  ${a.username.padEnd(16)} sign-in account: ${authExists ? "yes" : "none"}; ` +
        `username records: ${nameDocs.length}; verification-code record: ${otp.exists ? "yes" : "no"}; ` +
        `journal entries that would be deleted: ${a.entries}`
    );
  }

  // ---- 3. reservations held by removed accounts -------------------------
  const rank = (a, b) =>
    Number(b.complete) - Number(a.complete) ||
    Number(b.verified) - Number(a.verified) ||
    Number(b.entries > 0) - Number(a.entries > 0) ||
    a.createdMs - b.createdMs ||
    a.uid.localeCompare(b.uid);

  const reservations = []; // {col, key, label, action, to}
  const seen = new Set();
  for (const a of go) {
    for (const [col, key, mask] of [
      ["phones", a.phone, a.phone && maskPhone(a.phone)],
      ["emails", a.email, a.email && maskEmail(a.email)],
    ]) {
      if (!key || seen.has(`${col}/${key}`)) continue;
      seen.add(`${col}/${key}`);
      const ref = db.doc(`${col}/${key}`);
      const snap = await ref.get();
      if (!snap.exists || !removing.has(snap.get("uid"))) continue;
      const sameKey = (p) =>
        col === "phones"
          ? normalizePhone(p.data.phoneNumber) === key
          : normalizeEmail(p.data.recoveryEmail) === key;
      const cands = [];
      for (const p of profiles) {
        if (removing.has(p.uid) || !sameKey(p)) continue;
        const created = p.data.createdAt;
        cands.push({
          uid: p.uid,
          username: p.username,
          complete: p.data.registrationComplete === true,
          verified: p.data.phoneVerified === true,
          entries: await journalCount(p.uid),
          createdMs: created && created.toMillis ? created.toMillis() : Number.MAX_SAFE_INTEGER,
        });
      }
      cands.sort(rank);
      reservations.push({
        col, key, mask, ref, snap,
        action: cands.length ? "reassign" : "free",
        to: cands[0],
      });
    }
  }
  console.log(`\nRESERVATIONS held by those accounts: ${reservations.length}`);
  for (const r of reservations) {
    console.log(
      r.action === "reassign"
        ? `  ${r.col} ${r.mask}: would be handed to "${r.to.username}"`
        : `  ${r.col} ${r.mask}: would be deleted (nobody else uses it - it becomes free)`
    );
  }

  if (!APPLY) {
    console.log("\nDry run only - nothing was written or deleted. Re-run with --apply to do it.");
    return;
  }

  // ---- 4. backup, then delete -------------------------------------------
  const backup = { projectId, takenAt: new Date().toISOString(), accounts: [], reservations: [] };
  for (const { a, nameDocs, otp } of plan) {
    backup.accounts.push({
      uid: a.uid,
      profile: a.data,
      usernames: nameDocs.map((d) => ({ id: d.id, data: d.data() })),
      verificationRecord: otp.exists ? otp.data() : null,
    });
  }
  for (const r of reservations) {
    backup.reservations.push({ col: r.col, key: r.key, data: r.snap.data() });
  }
  const file = `remove-accounts-backup-${Date.now()}.json`;
  fs.writeFileSync(file, JSON.stringify(backup, null, 2));
  console.log(`\nBackup written to ${file} (contains personal data - keep private).`);

  let removed = 0;
  for (const { a, nameDocs, otp, authExists } of plan) {
    try {
      for (const d of nameDocs) await d.ref.delete();
      if (otp.exists) await otp.ref.delete();
      await db.recursiveDelete(a.ref);
      if (authExists) await admin.auth().deleteUser(a.uid);
      removed++;
      console.log(`  removed ${a.username}`);
    } catch (e) {
      console.log(`  FAILED ${a.username}: ${e.message} (left as is or partly removed - re-run the dry run)`);
    }
  }
  for (const r of reservations) {
    if (r.action === "reassign") await r.ref.set({ uid: r.to.uid });
    else await r.ref.delete();
  }
  console.log(`\nRemoved ${removed} of ${go.length} account(s); ${reservations.length} reservation(s) updated.`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
