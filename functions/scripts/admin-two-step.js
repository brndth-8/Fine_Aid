#!/usr/bin/env node
/*
 * Recovery tool for admin two-step verification (authenticator codes).
 *
 * Two-step verification is enrolled by each admin in the portal (System
 * Security) and switched on for everyone with the "Require" switch there. If
 * an admin loses their phone, or the requirement locks someone out, an owner
 * with a service-account key can fix it from here. Nothing is changed without
 * --apply.
 *
 *   node scripts/admin-two-step.js
 *       STATUS (default). Shows whether the requirement is on and, for every
 *       admins/{uid} account, whether an authenticator app is enrolled.
 *
 *   node scripts/admin-two-step.js --off --apply
 *       Stops requiring authenticator codes (appConfig/adminAuth). Admins can
 *       sign in with just their password again. Use this if the requirement
 *       locked everyone out.
 *
 *   node scripts/admin-two-step.js --reset <email-or-uid> --apply
 *       Removes that admin's enrolled authenticator app(s) and signs them out
 *       everywhere. They sign in with their password and set up a new one. If
 *       the requirement is on, switch it off first (--off) or they can't get
 *       back in to enrol.
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

admin.initializeApp({ projectId });
const db = admin.firestore();
const auth = admin.auth();

const userFor = (idOrEmail) =>
  idOrEmail.includes("@") ? auth.getUserByEmail(idOrEmail) : auth.getUser(idOrEmail);

const enrolled = (user) =>
  ((user.multiFactor && user.multiFactor.enrolledFactors) || []).filter(
    (f) => f.factorId === "totp"
  );

async function status() {
  const cfg = await db.doc("appConfig/adminAuth").get();
  console.log(
    `Project ${projectId}: authenticator code ${
      cfg.exists && cfg.get("requireTotp") === true ? "REQUIRED" : "not required"
    } for admins.`
  );
  const admins = await db.collection("admins").get();
  for (const doc of admins.docs) {
    try {
      const user = await auth.getUser(doc.id);
      const factors = enrolled(user);
      console.log(
        `  ${user.email} (${user.uid}): ${
          factors.length ? `authenticator enrolled (${factors.length})` : "NOT enrolled"
        }`
      );
    } catch (e) {
      console.log(`  ${doc.id}: no sign-in account (${e.code || e.message})`);
    }
  }
}

async function off() {
  console.log(`${APPLY ? "Turning off" : "Would turn off"} the authenticator requirement.`);
  if (!APPLY) return console.log("DRY RUN: nothing changed. Add --apply.");
  await db.doc("appConfig/adminAuth").set(
    {
      requireTotp: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: "recovery-script",
    },
    { merge: true }
  );
  console.log("Done. Admins can sign in with their password again.");
}

async function reset(idOrEmail) {
  const user = await userFor(idOrEmail);
  const factors = enrolled(user);
  console.log(
    `${APPLY ? "Resetting" : "Would reset"} ${user.email} (${user.uid}): ` +
      `${factors.length} authenticator app(s) enrolled.`
  );
  if (!APPLY) return console.log("DRY RUN: nothing changed. Add --apply.");
  const keep = ((user.multiFactor && user.multiFactor.enrolledFactors) || [])
    .filter((f) => f.factorId !== "totp")
    .map((f) => ({ ...f.toJSON() }));
  await auth.updateUser(user.uid, {
    multiFactor: { enrolledFactors: keep.length ? keep : null },
  });
  await auth.revokeRefreshTokens(user.uid);
  console.log("Done. They are signed out everywhere and can enrol a new authenticator app.");
}

(async () => {
  if (val("--reset")) return reset(val("--reset"));
  if (args.includes("--off")) return off();
  return status();
})().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
