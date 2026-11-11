#!/usr/bin/env node
/*
 * Switches on authenticator-app (TOTP) codes for the project. The Firebase
 * console only offers SMS multi-factor; authenticator codes are turned on
 * through the Admin API, which is what this does. It keeps whatever is already
 * set (e.g. SMS multi-factor) and only adds the authenticator provider.
 *
 *   node scripts/enable-totp.js
 *       DRY RUN (default). Shows the current multi-factor setting and what it
 *       would become. Changes nothing.
 *
 *   node scripts/enable-totp.js --apply
 *       Adds TOTP (codes are accepted for the current 30-second window plus
 *       one either side, to allow for clock drift). Turning this on does NOT
 *       make anyone use it: each admin enrols, and "Require a code" is a
 *       separate switch in the admin portal.
 *
 *   node scripts/enable-totp.js --remove --apply
 *       Takes TOTP out again (admins with an enrolled app can't use it).
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key (never
 * commit it; delete it afterwards). --project overrides the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const REMOVE = args.includes("--remove");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const manager = admin.auth().projectConfigManager();

(async () => {
  const config = await manager.getProjectConfig();
  const mfa = config.multiFactorConfig || { state: "DISABLED" };
  console.log(`Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is changed)"}`);
  console.log("Current multi-factor setting:");
  console.log(JSON.stringify(mfa, null, 2));

  const others = (mfa.providerConfigs || []).filter((p) => !p.totpProviderConfig);
  const hadTotp = (mfa.providerConfigs || []).some((p) => p.totpProviderConfig);
  const providerConfigs = REMOVE
    ? others
    : [
        ...others,
        { state: "ENABLED", totpProviderConfig: { adjacentIntervals: 1 } },
      ];
  const next = {
    state: "ENABLED",
    // Keep the factors already switched on (e.g. "phone" for SMS).
    ...(mfa.factorIds && mfa.factorIds.length ? { factorIds: mfa.factorIds } : {}),
    ...(providerConfigs.length ? { providerConfigs } : {}),
  };
  console.log(REMOVE ? "After removing TOTP:" : "After adding TOTP:");
  console.log(JSON.stringify(next, null, 2));

  if (!REMOVE && hadTotp && mfa.state === "ENABLED") {
    return console.log("TOTP is already enabled. Nothing to do.");
  }
  if (!APPLY) return console.log("DRY RUN: nothing changed. Add --apply.");
  await manager.updateProjectConfig({ multiFactorConfig: next });
  console.log(REMOVE ? "Done. TOTP removed." : "Done. Authenticator codes are enabled.");
})().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
