// Shared setup for the emulator tests. Everything here talks to the local
// Auth/Firestore emulators started by `npm test` (firebase emulators:exec)
// under the throw-away project id "demo-fineaid" — never to production.
const admin = require("firebase-admin");

const PROJECT = process.env.GCLOUD_PROJECT || "demo-fineaid";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "Run these tests with `npm test` (emulators). Refusing to run against " +
      "a real project."
  );
}

if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const auth = admin.auth();

async function resetEmulators() {
  const fs = process.env.FIRESTORE_EMULATOR_HOST;
  const au = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  await fetch(
    `http://${fs}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    { method: "DELETE" }
  );
  await fetch(`http://${au}/emulator/v1/projects/${PROJECT}/accounts`, {
    method: "DELETE",
  });
}

/** An admin caller, shaped like a callable's `request`. */
async function makeAdmin(uid = "admin1", extra = {}) {
  await db.doc(`admins/${uid}`).set({
    email: `${uid}@example.com`,
    displayName: "Test Admin",
    ...extra,
  });
  return { auth: { uid } };
}

const asNonAdmin = (uid = "someone") => ({ auth: { uid } });

async function makeUser(uid, fields = {}, { withAuth = false } = {}) {
  await db.doc(`users/${uid}`).set({ username: uid, ...fields });
  if (withAuth) {
    await auth.createUser({
      uid,
      email: `${uid}@fineaid.app`,
      password: "Passw0rd!x",
    });
  }
}

async function collectionDocs(path) {
  const snap = await db.collection(path).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Rejects unless `promise` fails with an HttpsError of this code. */
async function expectCode(promise, code) {
  try {
    await promise;
  } catch (err) {
    if (err.code !== code) {
      throw new Error(`Expected "${code}" but got "${err.code}": ${err.message}`);
    }
    return err;
  }
  throw new Error(`Expected "${code}" but the call succeeded.`);
}

async function signIn(email, password) {
  const au = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const res = await fetch(
    `http://${au}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  return { ok: res.ok, body: await res.json() };
}

module.exports = {
  PROJECT,
  admin,
  db,
  auth,
  resetEmulators,
  makeAdmin,
  asNonAdmin,
  makeUser,
  collectionDocs,
  expectCode,
  signIn,
};
