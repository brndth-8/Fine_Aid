#!/usr/bin/env node
/*
 * Journal photo privacy migration (Part 6). NOT RUN YET: needs approval, and
 * the user app must first be updated to read photos from the new place.
 *
 * Problem: each journal entry stores its photo as a tokenized download URL in
 * `imageUrls`. Admins can read entry documents, so they can read those URLs,
 * and a token URL works for anyone who has it. Rules can't hide one field, so
 * the photos move into a private subcollection and the old URLs are killed:
 *
 *   users/{uid}/journalEntries/{entryId}/photos/{photoId}   (owner-only rule)
 *     { storagePath, bucket, createdAt, migratedFrom: "imageUrls" }
 *
 * Steps (every step is a dry run unless --apply / --strip is given):
 *   1. node scripts/migrate-journal-photos.js
 *        Dry run. Lists what would change; writes nothing.
 *   2. node scripts/migrate-journal-photos.js --apply
 *        Writes backup-<time>.json FIRST (aborts if it can't), then creates
 *        the photos docs. Entries keep `imageUrls`, so the current app keeps
 *        working. Safe to re-run (photo ids are deterministic).
 *   3. (ship the app update that reads photos/ and stops writing imageUrls)
 *   4. node scripts/migrate-journal-photos.js --strip --backup-file backup-X.json
 *        Dry run of the strip. Add --apply to really do it: removes
 *        `imageUrls` from the entries and rotates each file's download token,
 *        which kills every old URL.
 *   Rollback: node scripts/migrate-journal-photos.js --rollback backup-X.json --apply
 *        Restores `imageUrls` (with fresh working URLs) and deletes the
 *        photos docs this script created.
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it). Use --project to override the project id.
 */
const fs = require("node:fs");
const crypto = require("node:crypto");
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const value = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const APPLY = flag("--apply");
const projectId = value("--project") || "fine-aid-9e0a9";

admin.initializeApp({ projectId });
const db = admin.firestore();
const storage = admin.storage();

/** users/{uid}/journal/{entry}/{file}, from a Firebase download URL. */
function parseDownloadUrl(url) {
  try {
    const u = new URL(url);
    const m = u.pathname.match(/\/v0\/b\/([^/]+)\/o\/(.+)$/);
    if (!m) return null;
    return { bucket: m[1], path: decodeURIComponent(m[2]) };
  } catch (_) {
    return null;
  }
}

const photoId = (entryPath, url) =>
  crypto.createHash("sha1").update(`${entryPath}|${url}`).digest("hex").slice(0, 20);

async function allEntriesWithPhotos() {
  const snap = await db.collectionGroup("journalEntries").get();
  return snap.docs.filter((d) => {
    const urls = d.get("imageUrls");
    return Array.isArray(urls) && urls.length > 0;
  });
}

async function urlFor(bucket, path) {
  const file = storage.bucket(bucket).file(path);
  const [meta] = await file.getMetadata();
  let token = (meta.metadata || {}).firebaseStorageDownloadTokens;
  token = token ? String(token).split(",")[0] : null;
  if (!token) {
    token = crypto.randomUUID();
    await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  }
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function plan() {
  const docs = await allEntriesWithPhotos();
  const items = [];
  for (const d of docs) {
    for (const url of d.get("imageUrls")) {
      const parsed = parseDownloadUrl(url);
      items.push({ entryPath: d.ref.path, url, parsed });
    }
  }
  return items;
}

async function runMigrate() {
  const items = await plan();
  const bad = items.filter((i) => !i.parsed);
  console.log(`${items.length} photo URL(s) across entries; ${bad.length} not recognised.`);
  for (const b of bad) console.log("  skip (unrecognised URL):", b.entryPath);
  const good = items.filter((i) => i.parsed);
  if (!APPLY) {
    for (const i of good.slice(0, 20)) {
      console.log(`  would create ${i.entryPath}/photos/${photoId(i.entryPath, i.url)} -> ${i.parsed.path}`);
    }
    if (good.length > 20) console.log(`  ... and ${good.length - 20} more`);
    console.log("DRY RUN: nothing written. Re-run with --apply to migrate.");
    return;
  }
  const backupFile = `backup-${new Date().toISOString().replace(/[:.]/g, "-")}.json`;
  fs.writeFileSync(
    backupFile,
    JSON.stringify(
      good.map(({ entryPath, url, parsed }) => ({ entryPath, url, ...parsed })),
      null,
      2
    ),
    { flag: "wx" }
  );
  console.log(`Backup written: ${backupFile}`);
  for (const i of good) {
    await db
      .doc(`${i.entryPath}/photos/${photoId(i.entryPath, i.url)}`)
      .set({
        storagePath: i.parsed.path,
        bucket: i.parsed.bucket,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        migratedFrom: "imageUrls",
      });
  }
  console.log(`Created ${good.length} photo document(s). Entries still have imageUrls.`);
}

async function runStrip() {
  const file = value("--backup-file");
  if (!file) throw new Error("--strip needs --backup-file <backup.json>");
  const backup = JSON.parse(fs.readFileSync(file, "utf8"));
  const entries = [...new Set(backup.map((b) => b.entryPath))];
  console.log(`${entries.length} entr(ies) / ${backup.length} file(s) from ${file}.`);
  if (!APPLY) {
    console.log("DRY RUN: would remove imageUrls and rotate download tokens. Add --apply.");
    return;
  }
  for (const entryPath of entries) {
    await db.doc(entryPath).update({ imageUrls: admin.firestore.FieldValue.delete() });
  }
  for (const b of backup) {
    await storage
      .bucket(b.bucket)
      .file(b.path)
      .setMetadata({ metadata: { firebaseStorageDownloadTokens: crypto.randomUUID() } });
  }
  console.log("Stripped imageUrls and rotated tokens: old URLs no longer work.");
}

async function runRollback() {
  const file = value("--rollback");
  const backup = JSON.parse(fs.readFileSync(file, "utf8"));
  const byEntry = new Map();
  for (const b of backup) {
    if (!byEntry.has(b.entryPath)) byEntry.set(b.entryPath, []);
    byEntry.get(b.entryPath).push(b);
  }
  console.log(`Rollback of ${byEntry.size} entr(ies) from ${file}.`);
  if (!APPLY) {
    console.log("DRY RUN: would restore imageUrls and delete migrated photo docs. Add --apply.");
    return;
  }
  for (const [entryPath, files] of byEntry) {
    const urls = [];
    for (const f of files) urls.push(await urlFor(f.bucket, f.path));
    await db.doc(entryPath).set({ imageUrls: urls }, { merge: true });
    for (const f of files) {
      await db.doc(`${entryPath}/photos/${photoId(entryPath, f.url)}`).delete();
    }
  }
  console.log("Rolled back: imageUrls restored (with fresh URLs), photo docs removed.");
}

(async () => {
  if (value("--rollback")) await runRollback();
  else if (flag("--strip")) await runStrip();
  else await runMigrate();
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
