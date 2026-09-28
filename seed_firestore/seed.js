/**
 * Seeds the Fine Aid `firstAidContent` Firestore collection from
 * firstAidContent.json (chunks extracted from the first aid reference PDFs).
 *
 * Usage:
 *   1. npm install
 *   2. Download a Firebase service account key for the fine-aid-9e0a9
 *      project (Firebase Console -> Project settings -> Service accounts ->
 *      Generate new private key) and save it next to this script as
 *      serviceAccountKey.json (already gitignored below -- do NOT commit it).
 *   3. node seed.js
 *
 * Safe to re-run: each chunk is written with a stable id (chunk_0001, ...),
 * so re-running overwrites the same documents instead of duplicating them.
 *
 * Options:
 *   node seed.js --dry-run      Parse + validate only, don't write anything.
 *   node seed.js --collection=someOtherName   Override target collection.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const DATA_FILE = path.join(__dirname, "firstAidContent.json");
const SERVICE_ACCOUNT_FILE = path.join(__dirname, "serviceAccountKey.json");

const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const collectionArg = args.find((a) => a.startsWith("--collection="));
const COLLECTION = collectionArg
  ? collectionArg.split("=")[1]
  : "firstAidContent";

function loadServiceAccount() {
  if (!fs.existsSync(SERVICE_ACCOUNT_FILE)) {
    console.error(
      `\nMissing service account key at ${SERVICE_ACCOUNT_FILE}\n` +
        "Download one from Firebase Console -> Project settings -> Service accounts\n" +
        "-> Generate new private key, and save it as serviceAccountKey.json in this folder.\n"
    );
    process.exit(1);
  }
  return require(SERVICE_ACCOUNT_FILE);
}

function loadChunks() {
  if (!fs.existsSync(DATA_FILE)) {
    console.error(`Missing data file: ${DATA_FILE}`);
    process.exit(1);
  }
  const raw = fs.readFileSync(DATA_FILE, "utf8");
  const chunks = JSON.parse(raw);
  if (!Array.isArray(chunks)) {
    console.error("firstAidContent.json must contain a JSON array of chunks.");
    process.exit(1);
  }
  return chunks;
}

function validateChunk(chunk, index) {
  const required = ["title", "content", "topic", "keywords", "source"];
  for (const field of required) {
    if (chunk[field] === undefined || chunk[field] === null) {
      throw new Error(`Chunk at index ${index} (id=${chunk.id}) missing required field "${field}"`);
    }
  }
  if (!Array.isArray(chunk.keywords)) {
    throw new Error(`Chunk at index ${index} (id=${chunk.id}) "keywords" must be an array`);
  }
}

async function main() {
  const chunks = loadChunks();
  console.log(`Loaded ${chunks.length} chunks from ${DATA_FILE}`);

  chunks.forEach(validateChunk);
  console.log("All chunks passed validation.");

  if (isDryRun) {
    console.log("--dry-run set: not writing to Firestore. Sample chunk:");
    console.log(JSON.stringify(chunks[0], null, 2));
    return;
  }

  const serviceAccount = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  const db = admin.firestore();

  console.log(`Writing to Firestore collection "${COLLECTION}" ...`);

  // Firestore batches are capped at 500 writes.
  const BATCH_SIZE = 450;
  let written = 0;

  for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
    const slice = chunks.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const chunk of slice) {
      const { id, ...data } = chunk;
      const docId = id || db.collection(COLLECTION).doc().id;
      const ref = db.collection(COLLECTION).doc(docId);
      batch.set(ref, {
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    written += slice.length;
    console.log(`  committed ${written}/${chunks.length}`);
  }

  console.log(`\nDone. Wrote ${written} documents to "${COLLECTION}".`);
  process.exit(0);
}

main().catch((err) => {
  console.error("Seed script failed:", err);
  process.exit(1);
});
