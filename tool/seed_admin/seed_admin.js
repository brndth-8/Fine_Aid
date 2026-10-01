#!/usr/bin/env node
/**
 * One-off script to create (or repair) the default Fine Aid admin account.
 * Not deployed anywhere — run it locally, once, whenever you need a new
 * default admin. Idempotent: safe to re-run against an account that
 * already exists (it will not touch an existing password or reset an
 * already-cleared mustChangePassword flag).
 *
 * Setup:
 *   1. Firebase Console -> Project settings -> Service accounts ->
 *      Generate new private key. Save the downloaded file as
 *      tool/seed_admin/serviceAccountKey.json (gitignored), or set
 *      GOOGLE_APPLICATION_CREDENTIALS to point at it instead.
 *   2. cp tool/seed_admin/.env.example tool/seed_admin/.env
 *      and fill in ADMIN_EMAIL / ADMIN_PASSWORD.
 *   3. cd tool/seed_admin && npm install && npm run seed
 *
 * This uses the Firebase Admin SDK, which authenticates as a trusted
 * server credential and bypasses Firestore security rules entirely —
 * that's expected and is why this script must stay local/manual rather
 * than something a client can trigger. Never commit the service account
 * key or the .env file (both are gitignored).
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const admin = require('firebase-admin');

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

if (!ADMIN_EMAIL) {
  fail(
    'ADMIN_EMAIL is not set. Copy tool/seed_admin/.env.example to ' +
      'tool/seed_admin/.env and fill it in.',
  );
}
if (!ADMIN_PASSWORD) {
  fail(
    'ADMIN_PASSWORD is not set. Copy tool/seed_admin/.env.example to ' +
      'tool/seed_admin/.env and fill it in.',
  );
}
if (ADMIN_PASSWORD.length < 8) {
  fail('ADMIN_PASSWORD must be at least 8 characters.');
}

function initializeAdminApp() {
  const keyPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.join(__dirname, 'serviceAccountKey.json');

  let credential;
  try {
    credential = admin.credential.cert(require(keyPath));
  } catch (error) {
    fail(
      `Could not load a service account key from "${keyPath}".\n` +
        '  Download one from Firebase Console -> Project settings -> ' +
        'Service accounts -> Generate new private key, save it as ' +
        'tool/seed_admin/serviceAccountKey.json, or set ' +
        'GOOGLE_APPLICATION_CREDENTIALS to its path.',
    );
  }
  admin.initializeApp({ credential });
}

async function main() {
  initializeAdminApp();
  const auth = admin.auth();
  const db = admin.firestore();

  let userRecord;
  let isNewUser = false;
  try {
    userRecord = await auth.getUserByEmail(ADMIN_EMAIL);
    console.log(
      `Found an existing Auth user for ${ADMIN_EMAIL} (${userRecord.uid}). ` +
        'Leaving its password untouched.',
    );
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    userRecord = await auth.createUser({
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      emailVerified: true,
    });
    isNewUser = true;
    console.log(`Created a new Auth user for ${ADMIN_EMAIL} (${userRecord.uid}).`);
  }

  const adminDocRef = db.collection('admins').doc(userRecord.uid);
  const adminDoc = await adminDocRef.get();

  if (!adminDoc.exists) {
    await adminDocRef.set({
      role: 'admin',
      email: ADMIN_EMAIL,
      // Only force a password change for an account this run actually
      // created — never re-arm it for one that already existed.
      mustChangePassword: isNewUser,
      seededAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('Created the admins/{uid} Firestore doc.');
  } else {
    // Never touch password/mustChangePassword for a doc that already
    // exists — only backfill display metadata the Admin Accounts screen
    // needs, and only if it's actually missing.
    const data = adminDoc.data();
    if (!data.email) {
      await adminDocRef.update({ email: ADMIN_EMAIL });
      console.log('admins/{uid} doc existed but had no email — backfilled it.');
    } else {
      console.log('admins/{uid} doc already exists — left it untouched.');
    }
  }

  console.log('\n✔ Admin account is ready.');
  console.log(`  Email: ${ADMIN_EMAIL}`);
  if (isNewUser) {
    console.log(
      '  It will be forced to set a new password the first time it signs ' +
        'in to the admin portal.',
    );
  }
  console.log(
    '\n  Delete tool/seed_admin/.env and serviceAccountKey.json when ' +
      "you're done — never commit either.\n",
  );
  process.exit(0);
}

main().catch((error) => {
  console.error('\n✖ Failed to seed admin account:', error);
  process.exit(1);
});
