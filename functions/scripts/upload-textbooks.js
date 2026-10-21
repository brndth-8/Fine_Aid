#!/usr/bin/env node
/*
 * One-time textbook upload. NOT RUN YET: it writes to the live project
 * (fine-aid-9e0a9 is the only one), so it needs your explicit go.
 *
 * What it does, for every PDF in assets/pdfs/:
 *   1. uploads it to Firebase Storage at   textbooks/<original file name>
 *   2. creates/updates the Firestore doc    textbooks/<id>
 *        { title, subject, fileName, storagePath, fileSize, uploadedAt,
 *          sortOrder }
 *
 * Every step is a dry run unless --apply is given:
 *   node scripts/upload-textbooks.js            dry run: lists what it would do
 *   node scripts/upload-textbooks.js --apply    uploads + writes the documents
 *
 * Safe to re-run: a file already in Storage with the same size is skipped
 * (add --force to upload it again), and a document is simply overwritten.
 * Nothing is ever deleted.
 *
 * Other options:
 *   --dir <folder>      where the PDFs are (default: ../assets/pdfs)
 *   --project <id>      Firebase project id (default: fine-aid-9e0a9)
 *   --bucket <name>     Storage bucket (default: <project>.firebasestorage.app)
 *
 * Needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key for
 * the project (never commit it), or `gcloud auth application-default login`.
 *
 * Adding a book later: put the PDF in the folder, add a line to BOOKS below
 * and run again (or just upload it in the console and add its document).
 */
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const value = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const APPLY = flag("--apply");
const FORCE = flag("--force");
const projectId = value("--project") || "fine-aid-9e0a9";
const bucketName = value("--bucket") || `${projectId}.firebasestorage.app`;
const dir = path.resolve(value("--dir") || path.join(__dirname, "..", "..", "assets", "pdfs"));

// file name -> what the app shows. sortOrder is the order of the carousel.
const BOOKS = {
  "SJA-First-Aid-Reference-Guide-English.pdf": {
    title: "First Aid Reference Guide",
    subject: "First Aid",
    sortOrder: 1,
  },
  "E-AG-5.5-First-Aid-Vision-2030.pdf": {
    title:
      "IFRC International First Aid, Resuscitation and Education Guidelines 2025",
    subject: "First Aid",
    sortOrder: 2,
  },
  "Philippine Red Cross First Aid Support.pdf": {
    title: "Philippine Red Cross First Aid Support",
    subject: "First Aid",
    sortOrder: 3,
  },
  "First Aid Pocket Guide.pdf": {
    title: "First Aid Pocket Guide",
    subject: "First Aid",
    sortOrder: 4,
  },
  "FA-CPR-AED-Part-Manual.pdf": {
    title: "First Aid Hand book Manual",
    subject: "First Aid, CPR & AED",
    sortOrder: 5,
  },
};

/** Document id from the file name: lower-case letters, digits and dashes. */
const docId = (fileName) =>
  fileName
    .replace(/\.pdf$/i, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

const mb = (bytes) => `${(bytes / 1024 / 1024).toFixed(1)} MB`;

async function main() {
  if (!fs.existsSync(dir)) {
    console.error(`Folder not found: ${dir}`);
    process.exit(1);
  }
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.toLowerCase().endsWith(".pdf"))
    .sort();
  if (files.length === 0) {
    console.error(`No PDFs in ${dir}`);
    process.exit(1);
  }

  console.log(`${APPLY ? "APPLY" : "DRY RUN"} - project ${projectId}, bucket ${bucketName}`);
  console.log(`Folder: ${dir}\n`);

  // Files with no entry in BOOKS are reported, never guessed at.
  const unknown = files.filter((f) => !BOOKS[f]);
  for (const f of unknown) {
    console.log(`SKIP  ${f}  (no entry in BOOKS - add one to upload it)`);
  }
  const todo = files.filter((f) => BOOKS[f]);

  let bucket = null;
  let db = null;
  if (APPLY) {
    admin.initializeApp({ projectId, storageBucket: bucketName });
    bucket = admin.storage().bucket();
    db = admin.firestore();
  }

  for (const fileName of todo) {
    const info = BOOKS[fileName];
    const localPath = path.join(dir, fileName);
    const size = fs.statSync(localPath).size;
    const storagePath = `textbooks/${fileName}`;
    const id = docId(fileName);

    let uploadNote = "upload";
    if (APPLY) {
      const remote = bucket.file(storagePath);
      const [exists] = await remote.exists();
      let sameSize = false;
      if (exists) {
        const [meta] = await remote.getMetadata();
        sameSize = Number(meta.size) === size;
      }
      if (exists && sameSize && !FORCE) {
        uploadNote = "already in Storage (same size) - skipped";
      } else {
        await bucket.upload(localPath, {
          destination: storagePath,
          metadata: { contentType: "application/pdf" },
        });
        uploadNote = "uploaded";
      }
      await db.collection("textbooks").doc(id).set({
        title: info.title,
        subject: info.subject,
        fileName,
        storagePath,
        fileSize: size,
        sortOrder: info.sortOrder,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    console.log(`${APPLY ? "DONE " : "WOULD"} ${fileName}  ${mb(size)}`);
    console.log(`        -> Storage ${storagePath}  (${uploadNote})`);
    console.log(`        -> Firestore textbooks/${id}  "${info.title}"`);
  }

  console.log(
    APPLY
      ? `\nDone: ${todo.length} book(s).`
      : `\nDry run only - nothing was written. Add --apply to do it.`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
