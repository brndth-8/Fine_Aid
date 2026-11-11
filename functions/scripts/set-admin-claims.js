#!/usr/bin/env node
/*
 * Admin role = a server-set `admin: true` claim in the sign-in token PLUS a
 * document in admins/{uid}. Both are needed (Firestore rules and every admin
 * Cloud Function check both), and neither can be granted from a browser: only
 * this script (or tool/seed_admin) running with a service-account key can set
 * a claim. That is also the bootstrap and recovery path: a locked-out first
 * admin is fixed by running --apply again.
 *
 *   node scripts/set-admin-claims.js
 *       DRY RUN (default). Lists every admins/{uid} account and whether its
 *       sign-in account already has the claim. Writes nothing.
 *
 *   node scripts/set-admin-claims.js --apply
 *       Sets admin:true on every account listed in `admins` (other claims are
 *       kept). Admins pick it up the next time they sign in; the admin portal
 *       also refreshes the token on load.
 *
 *   node scripts/set-admin-claims.js --revoke <email-or-uid> --apply
 *       Removes the claim and signs that account out everywhere (refresh
 *       tokens revoked). To end someone's admin access fully, also delete
 *       their admins/{uid} document.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key (never
 * commit it; delete it afterwards). --project overrides the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const val = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const projectId = val("--project") || "fine-aid-9e0a9";
const revoke = val("--revoke");

admin.initializeApp({ projectId });
const db = admin.firestore();
const auth = admin.auth();

async function userFor(idOrEmail) {
  return idOrEmail.includes("@")
    ? auth.getUserByEmail(idOrEmail)
    : auth.getUser(idOrEmail);
}

async function runRevoke() {
  const user = await userFor(revoke);
  const claims = { ...(user.customClaims || {}) };
  console.log(
    `${APPLY ? "Revoking" : "Would revoke"} admin claim for ${user.email} (${user.uid}); ` +
      `claim currently ${claims.admin === true ? "set" : "NOT set"}.`
  );
  if (!APPLY) return console.log("DRY RUN: nothing changed. Add --apply.");
  delete claims.admin;
  await auth.setCustomUserClaims(user.uid, claims);
  await auth.revokeRefreshTokens(user.uid);
  console.log(
    "Done. They are signed out everywhere. Delete admins/" +
      user.uid +
      " as well to remove the rest of their access."
  );
}

async function runGrant() {
  const snap = await db.collection("admins").get();
  console.log(
    `Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written)"}`
  );
  console.log(`admins documents: ${snap.size}\n`);
  let changed = 0;
  for (const doc of snap.docs) {
    let user;
    try {
      user = await auth.getUser(doc.id);
    } catch (e) {
      console.log(`  ! admins/${doc.id}: no sign-in account with this uid (skipped)`);
      continue;
    }
    const has = user.customClaims && user.customClaims.admin === true;
    console.log(`  ${has ? "has claim " : "NEEDS claim"}  ${user.email}`);
    if (has) continue;
    changed++;
    if (APPLY) {
      await auth.setCustomUserClaims(user.uid, {
        ...(user.customClaims || {}),
        admin: true,
      });
    }
  }
  console.log(
    `\n${APPLY ? "Set" : "Would set"} the claim on ${changed} account(s). ` +
      (APPLY
        ? "Admins get it on their next sign-in (or portal reload)."
        : "Re-run with --apply.")
  );
}

(revoke ? runRevoke() : runGrant()).then(
  () => process.exit(0),
  (e) => {
    console.error(e);
    process.exit(1);
  }
);
