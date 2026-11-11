#!/usr/bin/env node
/*
 * One-off: give older feedback items a status so the Admin portal's "Open"
 * filter lists them. Feedback saved by the app has no `status` field (a
 * missing field can't be filtered on); the markFeedbackOpen function stamps
 * new items "open", and this stamps the existing ones.
 *
 *   node scripts/feedback-status-backfill.js
 *       DRY RUN (default). Counts the items with no status. Writes nothing.
 *   node scripts/feedback-status-backfill.js --apply
 *       Sets status: "open" on items that have NO status. Items that already
 *       have one (open or resolved) are never touched, and nothing is deleted.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key (never
 * commit it; delete it afterwards). --project overrides the project id.
 */
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const pi = args.indexOf("--project");
const projectId = pi >= 0 ? args[pi + 1] : "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();

(async () => {
  const snap = await db.collection("feedback").get();
  const missing = snap.docs.filter((d) => d.get("status") === undefined);
  console.log(
    `Project ${projectId} - ${APPLY ? "APPLY" : "DRY RUN (nothing is written)"}`
  );
  console.log(`Feedback items: ${snap.size}; with no status: ${missing.length}`);
  if (APPLY) {
    let batch = db.batch();
    let inBatch = 0;
    for (const d of missing) {
      batch.update(d.ref, { status: "open" });
      if (++inBatch === 400) {
        await batch.commit();
        batch = db.batch();
        inBatch = 0;
      }
    }
    if (inBatch) await batch.commit();
    console.log(`Set status "open" on ${missing.length} item(s).`);
  } else {
    console.log("Re-run with --apply to set them to open.");
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
