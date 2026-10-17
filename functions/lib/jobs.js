// Business logic for account deactivation and scheduled notifications.
//
// Kept apart from index.js so it can be tested against the emulator: every
// function takes its dependencies (db, auth, messaging) as arguments. The
// Cloud Function exports in index.js are thin wrappers around these.
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");
const { buildAuditEntry } = require("./audit");

const DEACTIVATION_GRACE_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_SEND_ATTEMPTS = 3;
// A claimed ("sending") notification that never finished is treated as
// failed after this long, rather than sent again — a duplicate announcement
// to every user is worse than one the admin can see failed and resend.
const SENDING_TIMEOUT_MS = 15 * 60 * 1000;

const Timestamp = admin.firestore.Timestamp;
const FieldValue = admin.firestore.FieldValue;

/** Throws unless the caller signed in and has an admins/{uid} document. */
async function requireAdmin(db, request) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const snap = await db.collection("admins").doc(request.auth.uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Only admins can do this.");
  }
  return snap.data() || {};
}

function adminName(adminData) {
  return adminData.displayName || adminData.email || null;
}

function requireString(value, message) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", message);
  }
  return value.trim();
}

function inAppNotice(title, body) {
  return {
    title,
    body,
    type: "system",
    read: false,
    entryId: null,
    createdAt: FieldValue.serverTimestamp(),
  };
}

/** Lets HttpsErrors through; hides anything else behind a clear message. */
function asClearError(err, message) {
  if (err instanceof HttpsError) return err;
  console.error(message, err);
  return new HttpsError("internal", message);
}

// Account deactivation

/**
 * Admin-only. Warns first, deactivates later. In ONE transaction it writes
 * the notice into the user's in-app inbox, stamps `deactivateAt`, and adds
 * the audit entry — so a failed notice means nothing is scheduled at all, and
 * two admins clicking together can't produce two notices.
 *
 * `writeNotice` is injectable only so the failure case can be tested.
 */
async function scheduleDeactivation({
  db,
  request,
  uid,
  nowMs = Date.now(),
  writeNotice = (tx, ref, notice) => tx.set(ref, notice),
}) {
  const adminData = await requireAdmin(db, request);
  const userRef = db.collection("users").doc(
    requireString(uid, "A user id is required.")
  );
  const deactivateAt = Timestamp.fromMillis(
    nowMs + DEACTIVATION_GRACE_DAYS * DAY_MS
  );
  const dateText = deactivateAt.toDate().toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "Asia/Manila",
  });

  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That user no longer exists.");
      }
      const user = snap.data();
      if (user.deactivated === true) {
        throw new HttpsError(
          "failed-precondition",
          "This account is already deactivated."
        );
      }
      if (user.deactivateAt) {
        return {
          deactivateAt: user.deactivateAt.toMillis(),
          alreadyScheduled: true,
        };
      }

      writeNotice(
        tx,
        userRef.collection("notifications").doc(),
        inAppNotice(
          "Your account will be deactivated",
          "An administrator has scheduled your Fine Aid account to be " +
            `deactivated on ${dateText}. After that date you will no longer ` +
            "be able to sign in. If you think this is a mistake, please " +
            "contact support before then."
        )
      );
      tx.update(userRef, {
        deactivateAt,
        deactivationRequestedBy: request.auth.uid,
        deactivationRequestedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: `Scheduled account deactivation: ${user.username || userRef.id}`,
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "user",
          targetId: userRef.id,
          targetName: user.username,
          reason: "grace_period_started",
        })
      );
      return { deactivateAt: deactivateAt.toMillis(), alreadyScheduled: false };
    });
  } catch (err) {
    throw asClearError(
      err,
      "The user could not be notified, so nothing was scheduled. " +
        "Please try again."
    );
  }
}

/** Admin-only. Cancels a pending deactivation and tells the user. */
async function cancelDeactivation({ db, request, uid }) {
  const adminData = await requireAdmin(db, request);
  const userRef = db.collection("users").doc(
    requireString(uid, "A user id is required.")
  );
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That user no longer exists.");
      }
      const user = snap.data();
      if (!user.deactivateAt) return { cancelled: false };

      tx.set(
        userRef.collection("notifications").doc(),
        inAppNotice(
          "Your account will stay active",
          "The scheduled deactivation of your Fine Aid account has been " +
            "cancelled. No action is needed."
        )
      );
      tx.update(userRef, {
        deactivateAt: FieldValue.delete(),
        deactivationRequestedBy: FieldValue.delete(),
        deactivationRequestedAt: FieldValue.delete(),
      });
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: `Cancelled scheduled deactivation: ${user.username || userRef.id}`,
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "user",
          targetId: userRef.id,
          targetName: user.username,
          reason: "deactivation_cancelled",
        })
      );
      return { cancelled: true };
    });
  } catch (err) {
    throw asClearError(err, "Could not cancel the deactivation. Please try again.");
  }
}

/**
 * Scheduled sweep: turns every due `deactivateAt` into a real deactivation —
 * the Firebase Auth account is disabled and its sessions revoked (so the
 * user cannot sign in on any client, not just the Fine Aid app), and the
 * profile gets `deactivated: true`. Safe to run twice or concurrently: the
 * Auth update is idempotent and the record flips inside a transaction that
 * re-checks the account is still due, so there is one audit entry per
 * account. One failing account doesn't stop the rest; it stays pending and
 * is retried on the next run.
 */
async function processDueDeactivations({ db, auth, nowMs = Date.now() }) {
  const due = await db
    .collection("users")
    .where("deactivateAt", "<=", Timestamp.fromMillis(nowMs))
    .get();
  const result = { deactivated: 0, skipped: 0, failed: 0 };

  for (const doc of due.docs) {
    try {
      // Re-read right before acting: an admin may have cancelled since the
      // query ran.
      const fresh = await doc.ref.get();
      const pre = fresh.data();
      if (!pre || !pre.deactivateAt || pre.deactivateAt.toMillis() > nowMs) {
        result.skipped++;
        continue;
      }

      try {
        await auth.updateUser(doc.id, { disabled: true });
        await auth.revokeRefreshTokens(doc.id);
      } catch (err) {
        // No Auth account left: nothing to disable, still record it.
        if (!err || err.code !== "auth/user-not-found") throw err;
      }

      const flipped = await db.runTransaction(async (tx) => {
        const snap = await tx.get(doc.ref);
        const data = snap.data();
        if (!data || !data.deactivateAt || data.deactivateAt.toMillis() > nowMs) {
          return false; // Cancelled (or already processed) in the meantime.
        }
        tx.update(doc.ref, {
          deactivated: true,
          deactivatedAt: data.deactivateAt,
          deactivateAt: FieldValue.delete(),
        });
        tx.set(
          db.collection("auditLogs").doc(),
          buildAuditEntry({
            action: `Account deactivated (scheduled): ${data.username || doc.id}`,
            actorUid: data.deactivationRequestedBy,
            targetType: "user",
            targetId: doc.id,
            targetName: data.username,
            reason: "grace_period_elapsed",
          })
        );
        return true;
      });

      if (flipped) {
        result.deactivated++;
      } else {
        // Cancelled during the tiny window after sign-in was disabled: undo.
        await auth.updateUser(doc.id, { disabled: false }).catch(() => {});
        result.skipped++;
      }
    } catch (err) {
      console.error(`Deactivation failed for ${doc.id}, will retry:`, err);
      result.failed++;
    }
  }
  return result;
}

/**
 * Admin-only. Reverses a finished deactivation: re-enables the Firebase Auth
 * account and clears the flags. Needed because deactivation now disables the
 * Auth account itself, so flipping only the profile flag would leave the user
 * locked out.
 */
async function reactivateAccount({ db, auth, request, uid }) {
  const adminData = await requireAdmin(db, request);
  const userRef = db.collection("users").doc(
    requireString(uid, "A user id is required.")
  );
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "That user no longer exists.");
  }
  const user = snap.data();
  try {
    await auth.updateUser(userRef.id, { disabled: false });
  } catch (err) {
    if (!err || err.code !== "auth/user-not-found") {
      throw asClearError(err, "Could not re-enable the account. Please try again.");
    }
  }
  const batch = db.batch();
  batch.update(userRef, {
    deactivated: false,
    deactivatedAt: FieldValue.delete(),
    deactivateAt: FieldValue.delete(),
    deactivationRequestedBy: FieldValue.delete(),
    deactivationRequestedAt: FieldValue.delete(),
  });
  batch.set(
    db.collection("auditLogs").doc(),
    buildAuditEntry({
      action: `Account reactivated: ${user.username || userRef.id}`,
      actorUid: request.auth.uid,
      actorName: adminName(adminData),
      targetType: "user",
      targetId: userRef.id,
      targetName: user.username,
      reason: "reactivated_by_admin",
    })
  );
  await batch.commit();
  return { reactivated: true };
}

// Scheduled announcements (systemNotifications)

/**
 * Admin-only. Cancels an announcement that has not gone out yet. The status
 * check and the write happen in one transaction, and the scheduler claims a
 * notification in a transaction too, so exactly one of "cancelled" or "sent"
 * can win — a notification can't be cancelled after it fires, nor cancelled
 * twice. The record is kept (status "cancelled") for history.
 */
async function cancelScheduledNotification({ db, request, notificationId }) {
  const adminData = await requireAdmin(db, request);
  const ref = db
    .collection("systemNotifications")
    .doc(requireString(notificationId, "A notification id is required."));
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That notification no longer exists.");
      }
      const data = snap.data();
      if (data.status !== "scheduled") {
        const why =
          data.status === "cancelled"
            ? "This notification was already cancelled."
            : "This notification has already been sent, or is being sent " +
              "right now, so it can no longer be cancelled.";
        throw new HttpsError("failed-precondition", why);
      }
      tx.update(ref, {
        status: "cancelled",
        cancelledBy: request.auth.uid,
        cancelledByName: adminName(adminData),
        cancelledAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: `Cancelled scheduled notification "${data.title || ""}"`,
          type: "UPDATE",
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "notification",
          targetId: ref.id,
          targetName: data.title,
          reason: "cancelled_before_send",
        })
      );
      return { cancelled: true };
    });
  } catch (err) {
    throw asClearError(err, "Could not cancel the notification. Please try again.");
  }
}

/**
 * Scheduled every few minutes. Each due announcement is first CLAIMED in a
 * transaction (scheduled -> sending), which is what makes overlapping runs
 * and a last-second cancel safe: only one party can win the claim. A failed
 * push goes back to "scheduled" for a retry (up to MAX_SEND_ATTEMPTS, then
 * "failed"); a claim that never finishes is marked "failed", never re-sent.
 */
async function processDueNotifications({ db, messaging, nowMs = Date.now() }) {
  const col = db.collection("systemNotifications");
  const result = { sent: 0, skipped: 0, retried: 0, failed: 0 };

  const due = await col
    .where("status", "==", "scheduled")
    .where("scheduledFor", "<=", Timestamp.fromMillis(nowMs))
    .get();

  for (const doc of due.docs) {
    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      const data = snap.data();
      if (!data || data.status !== "scheduled") return null; // cancelled / taken
      tx.update(doc.ref, {
        status: "sending",
        claimedAt: FieldValue.serverTimestamp(),
        sendAttempts: FieldValue.increment(1),
      });
      return data;
    });
    if (!claimed) {
      result.skipped++;
      continue;
    }

    try {
      await messaging.send({
        topic: "all_users",
        notification: {
          title: claimed.title || "Fine Aid Update",
          body: claimed.body || "",
        },
        android: { priority: "high" },
      });
      await doc.ref.update({
        status: "sent",
        sentAt: FieldValue.serverTimestamp(),
      });
      result.sent++;
    } catch (err) {
      const attempts = (claimed.sendAttempts || 0) + 1;
      const giveUp = attempts >= MAX_SEND_ATTEMPTS;
      await doc.ref.update(
        giveUp
          ? {
              status: "failed",
              failedReason: String((err && err.message) || err).slice(0, 200),
            }
          : { status: "scheduled" }
      );
      if (giveUp) result.failed++;
      else result.retried++;
    }
  }

  // Claims that never finished (the function was killed mid-send).
  const stuck = await col.where("status", "==", "sending").get();
  for (const doc of stuck.docs) {
    const claimedAt = doc.data().claimedAt;
    if (claimedAt && nowMs - claimedAt.toMillis() < SENDING_TIMEOUT_MS) continue;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      if (!snap.exists || snap.data().status !== "sending") return;
      tx.update(doc.ref, { status: "failed", failedReason: "interrupted" });
    });
    result.failed++;
  }
  return result;
}

module.exports = {
  DEACTIVATION_GRACE_DAYS,
  requireAdmin,
  scheduleDeactivation,
  cancelDeactivation,
  processDueDeactivations,
  reactivateAccount,
  cancelScheduledNotification,
  processDueNotifications,
};
