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

/**
 * Throws unless the caller is an admin: signed in, carrying the server-set
 * `admin` custom claim in their sign-in token, AND listed in admins/{uid}.
 * Both are required so removing either one revokes access (deleting the
 * document takes effect at once; the claim is removed with
 * scripts/set-admin-claims.js). Clients can't set a claim or write the
 * admins collection, so neither can be self-granted.
 */
async function requireAdmin(db, request) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const snap = await db.collection("admins").doc(request.auth.uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Only admins can do this.");
  }
  if (!(request.auth.token && request.auth.token.admin === true)) {
    // Listed as an admin but the token predates the claim.
    throw new HttpsError(
      "permission-denied",
      "Your admin access needs a refresh. Please sign out and sign in again."
    );
  }
  // When two-step verification is required for admins, the sign-in must have
  // gone through the authenticator code (the token says so, and only Firebase
  // can put that in it).
  if ((await adminTwoStepRequired(db)) && !usedSecondFactor(request)) {
    throw new HttpsError(
      "permission-denied",
      "Sign in again with your authenticator code."
    );
  }
  return snap.data() || {};
}

/**
 * Whether admins must sign in with an authenticator code. Switched on/off by
 * setAdminTwoStepRequired (or scripts/admin-two-step.js); the same flag in
 * appConfig/adminAuth is what the Firestore rules and the portal read.
 */
async function adminTwoStepRequired(db) {
  const snap = await db.doc("appConfig/adminAuth").get();
  return snap.exists && snap.get("requireTotp") === true;
}

/** True when this sign-in went through an authenticator (TOTP) code. */
function usedSecondFactor(request) {
  const firebase = request && request.auth && request.auth.token
    ? request.auth.token.firebase
    : null;
  return !!firebase && firebase.sign_in_second_factor === "totp";
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

// Scheduled notifications. Two queues: "all users" announcements live in
// systemNotifications (public: the app lists them, and a push goes to the
// "all_users" topic); notifications for SELECTED users live in
// scheduledNotifications (admin-only: the recipients and text are private).

const QUEUES = ["systemNotifications", "scheduledNotifications"];

/** Which queue a request means; anything but the two known names is refused. */
function queueName(value) {
  if (value === undefined || value === null || value === "") {
    return "systemNotifications";
  }
  if (!QUEUES.includes(value)) {
    throw new HttpsError("invalid-argument", "Unknown notification list.");
  }
  return value;
}

/**
 * Admin-only. Cancels a notification that has not gone out yet. The status
 * check and the write happen in one transaction, and the scheduler claims a
 * notification in a transaction too, so exactly one of "cancelled" or "sent"
 * can win — a notification can't be cancelled after it fires, nor cancelled
 * twice. The record is kept (status "cancelled") for history. [collection]
 * says which queue (default: the all-users one).
 */
async function cancelScheduledNotification({
  db,
  request,
  notificationId,
  collection,
}) {
  const adminData = await requireAdmin(db, request);
  const ref = db
    .collection(queueName(collection))
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

// Push to specific users

/** Where a tap on a notification can open the app (fixed list, never a URL). */
const NOTIFICATION_LINKS = ["fineaid://notifications", "fineaid://journal"];
const DEFAULT_LINK = NOTIFICATION_LINKS[0];
const MAX_TARGET_USERS = 500;
// Schedules are entered and shown in Philippine time (UTC+8, no daylight
// saving); the instant itself is stored as a normal timestamp.
const SCHEDULE_TIMEZONE = "Asia/Manila";
const MIN_LEAD_MS = 60 * 1000;
const MAX_LEAD_MS = 366 * DAY_MS;
// FCM answers these for a device token that is no longer valid.
const DEAD_TOKEN_CODES = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
];

function cleanLink(value) {
  if (value === undefined || value === null || value === "") return DEFAULT_LINK;
  if (typeof value === "string" && NOTIFICATION_LINKS.includes(value)) return value;
  throw new HttpsError(
    "invalid-argument",
    "Pick where the notification opens from the list."
  );
}

function cleanTitle(value) {
  const title = requireString(value, "A title is required.");
  if (title.length > 120) {
    throw new HttpsError("invalid-argument", "The title can be up to 120 characters.");
  }
  return title;
}

function cleanBody(value) {
  const body = typeof value === "string" ? value.trim() : "";
  if (body.length > 1000) {
    throw new HttpsError("invalid-argument", "The message can be up to 1,000 characters.");
  }
  return body;
}

function cleanMessage(data) {
  return { title: cleanTitle(data && data.title), body: cleanBody(data && data.body) };
}

/** A schedule time that must be in the future (and not absurdly far off). */
function cleanScheduleTime(value, nowMs) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "Pick a date and time to send it.");
  }
  if (value < nowMs + MIN_LEAD_MS) {
    throw new HttpsError(
      "invalid-argument",
      "Pick a time at least a minute in the future."
    );
  }
  if (value > nowMs + MAX_LEAD_MS) {
    throw new HttpsError(
      "invalid-argument",
      "Pick a time within the next year."
    );
  }
  return value;
}

/**
 * Turns the usernames an admin picked into accounts: [{ uid, username }], in
 * the order given, without repeats. At least one, at most MAX_TARGET_USERS,
 * and every one must exist.
 */
async function resolveUsernames(db, usernames) {
  if (!Array.isArray(usernames) || usernames.length === 0) {
    throw new HttpsError("invalid-argument", "Pick at least one user.");
  }
  const names = [
    ...new Set(
      usernames
        .filter((n) => typeof n === "string")
        .map((n) => n.trim())
        .filter(Boolean)
    ),
  ];
  if (names.length === 0) {
    throw new HttpsError("invalid-argument", "Pick at least one user.");
  }
  if (names.length > MAX_TARGET_USERS) {
    throw new HttpsError(
      "invalid-argument",
      `Pick at most ${MAX_TARGET_USERS} users at a time.`
    );
  }
  const found = [];
  for (let i = 0; i < names.length; i += 25) {
    const part = await Promise.all(
      names.slice(i, i + 25).map(async (name) => {
        const uid = await usernameOwnerUid(db, name);
        const user = uid ? await db.collection("users").doc(uid).get() : null;
        return user && user.exists
          ? { uid, username: user.get("username") || name }
          : { missing: name };
      })
    );
    found.push(...part);
  }
  const missing = found.filter((f) => f.missing).map((f) => f.missing);
  if (missing.length) {
    throw new HttpsError(
      "not-found",
      missing.length === 1 && names.length === 1
        ? "No user has that username."
        : `No user has the username: ${missing.slice(0, 5).join(", ")}.`
    );
  }
  const seen = new Set();
  return found.filter((f) => (seen.has(f.uid) ? false : seen.add(f.uid)));
}

/**
 * Puts the notice in each user's private inbox (users/{uid}/notifications,
 * which only they can read): the history the app's Notifications screen
 * shows, and what a user with no registered device still receives. With a
 * [noticeId] the document id is fixed, so retrying a send writes the same
 * notice again instead of a second one.
 */
async function writeInboxNotices(db, uids, { title, body, link, noticeId }) {
  for (let i = 0; i < uids.length; i += 400) {
    const batch = db.batch();
    for (const uid of uids.slice(i, i + 400)) {
      const col = db.collection("users").doc(uid).collection("notifications");
      batch.set(noticeId ? col.doc(noticeId) : col.doc(), {
        ...inAppNotice(title, body),
        link,
      });
    }
    await batch.commit();
  }
}

/**
 * Sends the push to every registered device (users/{uid}/devices) of [uids]:
 * title, body and the link in the payload. A user with no device is simply
 * counted (they still have the inbox notice). Device tokens FCM reports as
 * invalid or expired are deleted. Returns a summary; throws only if FCM
 * itself can't be reached. [messaging] is admin.messaging().
 */
async function pushToUsers({ db, messaging, uids, title, body, link, notificationId }) {
  const summary = {
    recipients: uids.length,
    pushed: 0,
    noDevice: 0,
    invalidRemoved: 0,
    failed: 0,
  };
  if (!messaging) return summary;
  const devices = [];
  for (const uid of uids) {
    const snap = await db.collection("users").doc(uid).collection("devices").get();
    const tokens = snap.docs
      .map((d) => ({ ref: d.ref, token: d.get("token") }))
      .filter((d) => typeof d.token === "string" && d.token);
    if (tokens.length === 0) summary.noDevice++;
    devices.push(...tokens);
  }
  for (let i = 0; i < devices.length; i += 500) {
    const chunk = devices.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk.map((d) => d.token),
      notification: { title, body },
      data: { link, notificationId: notificationId || "" },
      android: { priority: "high" },
    });
    for (let j = 0; j < res.responses.length; j++) {
      const r = res.responses[j];
      if (r.success) {
        summary.pushed++;
      } else if (r.error && DEAD_TOKEN_CODES.includes(r.error.code)) {
        await chunk[j].ref.delete().catch(() => {});
        summary.invalidRemoved++;
      } else {
        summary.failed++;
      }
    }
  }
  return summary;
}

/**
 * Admin-only. Schedules a notification for one or more SPECIFIC users. It is
 * saved in scheduledNotifications (admin-only, so who it is for and what it
 * says stay private) and the scheduler sends it, as a push to those users'
 * devices plus an inbox notice, once it is due. The time must be in the
 * future; times are entered in Philippine time.
 */
async function scheduleNotification({ db, request, data, nowMs = Date.now() }) {
  const adminData = await requireAdmin(db, request);
  const { title, body } = cleanMessage(data);
  const when = cleanScheduleTime(data && data.scheduledForMs, nowMs);
  const link = cleanLink(data && data.link);
  const users = await resolveUsernames(db, data && data.usernames);

  const ref = db.collection("scheduledNotifications").doc();
  const batch = db.batch();
  batch.set(ref, {
    title,
    body,
    link,
    audience: "selected",
    targetUids: users.map((u) => u.uid),
    targetUsernames: users.map((u) => u.username),
    priority: typeof data.priority === "string" ? data.priority.slice(0, 20) : "Normal",
    scheduledFor: Timestamp.fromMillis(when),
    timezone: SCHEDULE_TIMEZONE,
    status: "scheduled",
    createdAt: FieldValue.serverTimestamp(),
    createdBy: request.auth.uid,
    createdByName: adminName(adminData),
  });
  batch.set(
    db.collection("auditLogs").doc(),
    buildAuditEntry({
      action: `Scheduled notification "${title}" for ${users.length} user${
        users.length === 1 ? "" : "s"
      }`,
      type: "CREATE",
      actorUid: request.auth.uid,
      actorName: adminName(adminData),
      targetType: "notification",
      targetId: ref.id,
      targetName: title,
      reason: "scheduled_for_selected_users",
    })
  );
  try {
    await batch.commit();
  } catch (err) {
    throw asClearError(err, "Could not schedule the notification. Please try again.");
  }
  return { id: ref.id, recipients: users.length };
}

/**
 * Admin-only. Edits a notification that has not gone out yet: its text, its
 * time, where it opens and (for the selected-users queue) who it is for. The
 * status is checked inside the transaction the scheduler also claims it in,
 * so a notification that is already being sent can't be edited. [collection]
 * says which queue.
 */
async function updateScheduledNotification({ db, request, data, nowMs = Date.now() }) {
  const adminData = await requireAdmin(db, request);
  const name = queueName(data && data.collection);
  const ref = db
    .collection(name)
    .doc(requireString(data && data.notificationId, "A notification id is required."));

  const changes = {};
  // Only what was sent changes: editing the title alone keeps the message.
  if ("title" in data) changes.title = cleanTitle(data.title);
  if ("body" in data) changes.body = cleanBody(data.body);
  if ("scheduledForMs" in data) {
    changes.scheduledFor = Timestamp.fromMillis(cleanScheduleTime(data.scheduledForMs, nowMs));
    changes.timezone = SCHEDULE_TIMEZONE;
  }
  if ("link" in data) changes.link = cleanLink(data.link);
  if ("usernames" in data) {
    if (name !== "scheduledNotifications") {
      throw new HttpsError(
        "invalid-argument",
        "Everyone gets this notification; there is no list of users to change."
      );
    }
    const users = await resolveUsernames(db, data.usernames);
    changes.targetUids = users.map((u) => u.uid);
    changes.targetUsernames = users.map((u) => u.username);
  }
  if (Object.keys(changes).length === 0) {
    throw new HttpsError("invalid-argument", "Nothing to change.");
  }

  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That notification no longer exists.");
      }
      const current = snap.data();
      if (current.status !== "scheduled") {
        throw new HttpsError(
          "failed-precondition",
          "This notification has already been sent, cancelled or is being " +
            "sent right now, so it can no longer be edited."
        );
      }
      tx.update(ref, {
        ...changes,
        editedAt: FieldValue.serverTimestamp(),
        editedBy: request.auth.uid,
      });
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: `Edited scheduled notification "${changes.title || current.title || ""}"`,
          type: "UPDATE",
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "notification",
          targetId: ref.id,
          targetName: changes.title || current.title,
          reason: `fields: ${Object.keys(changes).join(", ")}`,
        })
      );
      return { updated: true };
    });
  } catch (err) {
    throw asClearError(err, "Could not save the changes. Please try again.");
  }
}

/**
 * Scheduled every few minutes. Each due notification (in either queue) is
 * first CLAIMED in a transaction (scheduled -> sending), which is what makes
 * overlapping runs and a last-second cancel safe: only one party can win the
 * claim. All-users announcements go to the "all_users" topic; selected-users
 * ones go to those users' devices (and inboxes). A failed send goes back to
 * "scheduled" for a retry (up to MAX_SEND_ATTEMPTS, then "failed"); a claim
 * that never finishes is marked "failed", never re-sent.
 */
async function processDueNotifications({ db, messaging, nowMs = Date.now() }) {
  const result = { sent: 0, skipped: 0, retried: 0, failed: 0 };

  const deliver = {
    systemNotifications: async (doc, claimed) => {
      await messaging.send({
        topic: "all_users",
        notification: {
          title: claimed.title || "Fine Aid Update",
          body: claimed.body || "",
        },
        data: {
          link: NOTIFICATION_LINKS.includes(claimed.link) ? claimed.link : DEFAULT_LINK,
          notificationId: doc.id,
        },
        android: { priority: "high" },
      });
      return {};
    },
    scheduledNotifications: async (doc, claimed) => {
      const uids = Array.isArray(claimed.targetUids) ? claimed.targetUids : [];
      const link = NOTIFICATION_LINKS.includes(claimed.link) ? claimed.link : DEFAULT_LINK;
      const message = {
        title: claimed.title || "Fine Aid Update",
        body: claimed.body || "",
      };
      // A retry rewrites the same inbox notice rather than adding another.
      await writeInboxNotices(db, uids, { ...message, link, noticeId: `sched_${doc.id}` });
      const delivery = await pushToUsers({
        db,
        messaging,
        uids,
        ...message,
        link,
        notificationId: doc.id,
      });
      return { delivery };
    },
  };

  for (const name of QUEUES) {
    const col = db.collection(name);
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
        const extra = await deliver[name](doc, claimed);
        await doc.ref.update({
          status: "sent",
          sentAt: FieldValue.serverTimestamp(),
          ...extra,
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
  }
  return result;
}

// ---------------------------------------------------------------------------
// Editing a user's profile (User management)
// ---------------------------------------------------------------------------

const NAME_PATTERN = /^[\p{L}][\p{L} .'\-]*$/u;
const USERNAME_PATTERN = /^[A-Za-z0-9_.]{3,30}$/;
const EMAIL_PATTERN = /^[^@\s/]+@[^@\s/]+\.[^@\s/]+$/;
const GENDERS = ["male", "female", "other"];

function cleanName(value, label) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text || text.length > 60 || !NAME_PATTERN.test(text)) {
    throw new HttpsError(
      "invalid-argument",
      `${label} is required and may only contain letters, spaces, ` +
        "hyphens, apostrophes and periods."
    );
  }
  return text;
}

/** The standard +639XXXXXXXXX form of a stored number, or null if it isn't one. */
function canonicalPhoneOrNull(value) {
  try {
    return cleanPhone(value);
  } catch (_) {
    return null;
  }
}

/** +63 9XX XXX XXXX from any of the usual ways of writing it, or an error. */
function cleanPhone(value) {
  const digits = typeof value === "string" ? value.replace(/\D/g, "") : "";
  let national = null;
  if (digits.length === 12 && digits.startsWith("63")) national = digits.slice(2);
  else if (digits.length === 11 && digits.startsWith("0")) national = digits.slice(1);
  else if (digits.length === 10) national = digits;
  if (!national || !/^(9\d{9}|8(11|13|17|95|96|97|98)\d{7})$/.test(national)) {
    throw new HttpsError(
      "invalid-argument",
      "Enter a Philippine mobile number, e.g. +63 917 123 4567."
    );
  }
  return `+63${national}`;
}

/**
 * Finds who owns [username] in the public usernames collection: the exact-
 * case document, or an older account's lower-cased one whose usernameExact
 * matches. Returns the owner's uid or null. Read inside [tx] when given.
 */
async function usernameOwnerUid(db, username, tx) {
  const get = (ref) => (tx ? tx.get(ref) : ref.get());
  const exact = await get(db.collection("usernames").doc(username));
  if (exact.exists) return exact.get("uid") || "";
  const lower = username.toLowerCase();
  if (lower !== username) {
    const legacy = await get(db.collection("usernames").doc(lower));
    if (legacy.exists && legacy.get("usernameExact") === username) {
      return legacy.get("uid") || "";
    }
  }
  return null;
}

/**
 * Admin-only. Saves edits to a user's profile: username, first/last name,
 * date of birth, gender, email and phone. Only the fields present in
 * `changes` are touched. Done on the server in ONE transaction so that:
 *  - every value is validated the way sign-up validates it;
 *  - a new username/email can't clash with another account (usernames are
 *    exact-case, emails are compared lower-case) and the old reservations
 *    move with the change;
 *  - the audit entry lists WHICH fields changed (never their values).
 * The sign-in account itself (its generated sign-in address) never changes,
 * so a renamed user still signs in with their new username and same password.
 * Underage acknowledgment, registration date and account type are not editable.
 */
async function updateUserProfile({ db, request, data }) {
  const adminData = await requireAdmin(db, request);
  const uid = requireString(data && data.uid, "A user id is required.");
  const changes = (data && data.changes) || {};
  if (typeof changes !== "object" || Array.isArray(changes)) {
    throw new HttpsError("invalid-argument", "Nothing to change.");
  }

  // Validate everything first (no reads yet).
  const want = {};
  if ("username" in changes) {
    const name = typeof changes.username === "string" ? changes.username.trim() : "";
    if (!USERNAME_PATTERN.test(name)) {
      throw new HttpsError(
        "invalid-argument",
        "Username must be 3-30 characters: letters, numbers, _ and . only."
      );
    }
    want.username = name;
  }
  if ("firstName" in changes) want.firstName = cleanName(changes.firstName, "First name");
  if ("lastName" in changes) want.lastName = cleanName(changes.lastName, "Last name");
  if ("dateOfBirthMs" in changes) {
    const ms = changes.dateOfBirthMs;
    const min = Date.UTC(1900, 0, 1);
    if (typeof ms !== "number" || !Number.isFinite(ms) || ms < min || ms > Date.now()) {
      throw new HttpsError(
        "invalid-argument",
        "Date of birth must be a real date between 1900 and today."
      );
    }
    want.dateOfBirth = Timestamp.fromMillis(ms);
  }
  if ("gender" in changes) {
    if (!GENDERS.includes(changes.gender)) {
      throw new HttpsError("invalid-argument", "Choose a gender from the list.");
    }
    want.gender = changes.gender;
  }
  if ("email" in changes) {
    const raw = typeof changes.email === "string" ? changes.email.trim().toLowerCase() : "";
    if (raw && (raw.length > 254 || !EMAIL_PATTERN.test(raw))) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }
    want.email = raw; // "" removes it
  }
  if ("phone" in changes) want.phoneNumber = cleanPhone(changes.phone);

  const userRef = db.collection("users").doc(uid);
  let touched = [];
  try {
    await db.runTransaction(async (tx) => {
      touched = [];
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That user no longer exists.");
      }
      const user = snap.data();
      const updates = {};
      const after = []; // writes to run once every read is done

      // ----- reads -----
      let renameFrom = null;
      if (want.username !== undefined && want.username !== user.username) {
        const owner = await usernameOwnerUid(db, want.username, tx);
        if (owner !== null && owner !== uid) {
          throw new HttpsError("already-exists", "That username is already taken.");
        }
        if (!user.email) {
          throw new HttpsError(
            "failed-precondition",
            "This account has no sign-in email on record, so it can't be renamed."
          );
        }
        renameFrom = user.username || "";
        const olds = [];
        for (const key of new Set([renameFrom, renameFrom.toLowerCase()])) {
          if (!key) continue;
          const ref = db.collection("usernames").doc(key);
          const doc = await tx.get(ref);
          if (doc.exists && doc.get("uid") === uid) olds.push(ref);
        }
        after.push(() => {
          for (const ref of olds) tx.delete(ref);
          tx.set(db.collection("usernames").doc(want.username), {
            email: user.email,
            uid,
            usernameExact: want.username,
          });
        });
        updates.username = want.username;
      }

      if (want.email !== undefined) {
        const oldEmail = (user.recoveryEmail || "").trim().toLowerCase();
        if (want.email !== oldEmail) {
          if (want.email) {
            const holder = await tx.get(db.collection("emails").doc(want.email));
            if (holder.exists && holder.get("uid") !== uid) {
              throw new HttpsError("already-exists", "This email is already registered.");
            }
            if (!holder.exists) {
              after.push(() => tx.set(db.collection("emails").doc(want.email), { uid }));
            }
            updates.recoveryEmail = want.email;
          } else {
            updates.recoveryEmail = FieldValue.delete();
          }
          if (oldEmail) {
            const oldRef = db.collection("emails").doc(oldEmail);
            const oldDoc = await tx.get(oldRef);
            if (oldDoc.exists && oldDoc.get("uid") === uid) {
              after.push(() => tx.delete(oldRef));
            }
          }
        }
      }

      // One account per phone number: reserved as phones/{+639XXXXXXXXX}, the
      // same way emails are, and moved with the change.
      if (want.phoneNumber !== undefined) {
        const holder = await tx.get(db.collection("phones").doc(want.phoneNumber));
        if (holder.exists && holder.get("uid") !== uid) {
          throw new HttpsError("already-exists", "This phone number is already registered.");
        }
        if (!holder.exists) {
          after.push(() => tx.set(db.collection("phones").doc(want.phoneNumber), { uid }));
        }
        const oldPhone = canonicalPhoneOrNull(user.phoneNumber);
        if (oldPhone && oldPhone !== want.phoneNumber) {
          const oldRef = db.collection("phones").doc(oldPhone);
          const oldDoc = await tx.get(oldRef);
          if (oldDoc.exists && oldDoc.get("uid") === uid) {
            after.push(() => tx.delete(oldRef));
          }
        }
      }

      // ----- plain fields -----
      const same = (a, b) => (a && a.toMillis ? a.toMillis() === (b && b.toMillis && b.toMillis()) : a === b);
      for (const key of ["firstName", "lastName", "gender", "phoneNumber", "dateOfBirth"]) {
        if (want[key] !== undefined && !same(want[key], user[key])) {
          updates[key] = want[key];
        }
      }

      touched = Object.keys(updates).map((k) => (k === "recoveryEmail" ? "email" : k));
      if (touched.length === 0) return;

      updates.updatedAt = FieldValue.serverTimestamp();
      tx.update(userRef, updates);
      for (const run of after) run();
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: `Edited user ${want.username || user.username || uid}`,
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "user",
          targetId: uid,
          targetName: want.username || user.username,
          reason: `fields: ${touched.join(", ")}`,
        })
      );
    });
  } catch (err) {
    throw asClearError(err, "Could not save the changes. Please try again.");
  }
  return { updated: touched };
}

// ---------------------------------------------------------------------------
// Notification to one user
// ---------------------------------------------------------------------------

/**
 * Admin-only. Sends a notice right now to ONE user (`username`) or several
 * (`usernames`). Each gets it as a push to their registered devices AND as an
 * in-app notice in their own inbox (users/{uid}/notifications, which only
 * they can read), so it also shows in their Notifications list and a user
 * with no registered device still receives it. It does not go through the
 * public announcements collection, so no one else can see it. If the push
 * service can't be reached the inbox notice is still saved and the result
 * says the push failed. Only the title goes in the audit log, not the message.
 */
async function sendNotificationToUser({ db, request, data, messaging }) {
  const adminData = await requireAdmin(db, request);
  const names = Array.isArray(data && data.usernames)
    ? data.usernames
    : [requireString(data && data.username, "Enter the user's username.")];
  const { title, body } = cleanMessage(data);
  const link = cleanLink(data && data.link);
  const users = await resolveUsernames(db, names);
  const uids = users.map((u) => u.uid);

  await writeInboxNotices(db, uids, { title, body, link });
  await db.collection("auditLogs").add(
    buildAuditEntry({
      action:
        users.length === 1
          ? `Sent notification "${title}" to a user`
          : `Sent notification "${title}" to ${users.length} users`,
      type: "CREATE",
      actorUid: request.auth.uid,
      actorName: adminName(adminData),
      targetType: "user",
      targetId: users.length === 1 ? users[0].uid : undefined,
      targetName: users.length === 1 ? users[0].username : undefined,
      reason: "targeted_notification",
    })
  );

  let delivery;
  let pushFailed = false;
  try {
    delivery = await pushToUsers({ db, messaging, uids, title, body, link });
  } catch (err) {
    console.error("push to users failed", err);
    pushFailed = true;
    delivery = { recipients: uids.length, pushed: 0, noDevice: 0, invalidRemoved: 0, failed: uids.length };
  }
  return {
    sent: true,
    username: users[0].username,
    count: users.length,
    delivery,
    pushFailed,
  };
}

// ---------------------------------------------------------------------------
// Admin response to a feedback item
// ---------------------------------------------------------------------------

const FEEDBACK_RESPONSE_MAX = 1000;

/**
 * Admin-only. Sends an admin's reply to one feedback item and delivers it to
 * the user who wrote it. In ONE transaction it:
 *  - saves the reply on the feedback document (response, respondedBy,
 *    respondedByName, respondedAt) and moves its status to "responded";
 *  - puts the reply in that user's in-app inbox (users/{uid}/notifications,
 *    the same inbox every other notice uses, which only they can read),
 *    carrying the feedback's id so it stays linked to the original;
 *  - writes the audit entry (the reply text itself is never audited).
 * Either all of it happens or none of it does, so a failure leaves the
 * feedback untouched and not marked as sent. A reply can be sent once, and
 * never to a resolved item. Feedback sent without an account (a guest) is
 * saved but there is nobody to notify; the result says so (delivered: false).
 */
async function respondToFeedback({ db, request, data }) {
  const adminData = await requireAdmin(db, request);
  const feedbackId = requireString(data && data.feedbackId, "Missing feedback.");
  const response = requireString(data && data.response, "Write a response before sending.");
  if (response.length > FEEDBACK_RESPONSE_MAX) {
    throw new HttpsError(
      "invalid-argument",
      `A response can be up to ${FEEDBACK_RESPONSE_MAX} characters.`
    );
  }
  const feedbackRef = db.collection("feedback").doc(feedbackId);
  let delivered = false;
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(feedbackRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "That feedback no longer exists.");
      }
      const feedback = snap.data() || {};
      if (typeof feedback.response === "string" && feedback.response.length > 0) {
        throw new HttpsError(
          "failed-precondition",
          "This feedback already has a response."
        );
      }
      if (feedback.status === "resolved") {
        throw new HttpsError(
          "failed-precondition",
          "This issue is resolved. Responses are disabled."
        );
      }
      const userId = typeof feedback.userId === "string" ? feedback.userId : null;
      const userRef = userId ? db.collection("users").doc(userId) : null;
      // All reads first.
      const user = userRef ? await tx.get(userRef) : null;
      delivered = !!(user && user.exists);

      tx.update(feedbackRef, {
        response,
        respondedBy: request.auth.uid,
        respondedByName: adminName(adminData),
        respondedAt: FieldValue.serverTimestamp(),
        status: "responded",
      });
      if (delivered) {
        tx.set(userRef.collection("notifications").doc(), {
          ...inAppNotice("Reply to your feedback", response),
          feedbackId,
        });
      }
      tx.set(
        db.collection("auditLogs").doc(),
        buildAuditEntry({
          action: "Responded to feedback",
          actorUid: request.auth.uid,
          actorName: adminName(adminData),
          targetType: "feedback",
          targetId: feedbackId,
          targetName: delivered ? user.get("username") || null : null,
          reason: delivered ? "feedback_response" : "feedback_response_no_account",
        })
      );
    });
  } catch (err) {
    throw asClearError(err, "Could not send the response. Please try again.");
  }
  return { sent: true, delivered };
}

// ---------------------------------------------------------------------------
// Security settings (System Security page)
// ---------------------------------------------------------------------------

const ALLOWED_IDLE_MINUTES = [5, 10, 15, 30, 60];
const ALLOWED_LOCKOUT_ATTEMPTS = [3, 5, 10];
const ALLOWED_LOCKOUT_MINUTES = [5, 15, 30, 60];

// What applies until an admin changes them (the lockout default matches what
// the sign-in screen used before it was configurable).
const DEFAULT_IDLE = { enabled: true, minutes: 15 };
const DEFAULT_LOCKOUT = { enabled: true, maxAttempts: 5, minutes: 15 };

/**
 * Admin-only. Saves the System Security settings an admin can change:
 *  - the idle session timeout (on/off + minutes), applied by the admin portal;
 *  - the failed-login lockout (on/off + wrong passwords allowed + minutes
 *    locked), applied by the app's sign-in screen. The sign-in screen runs
 *    before anyone is signed in, so a public read-only copy is saved to
 *    appConfig/loginSecurity (nothing secret in it).
 * Send either group or both; a group must be complete. Done here (not from the
 * browser) so values are validated, the change is written and audit-logged
 * together, and the caller only hears "saved" once it really is. Returns every
 * setting as it stands now.
 */
async function updateSecuritySettings({ db, request, data }) {
  const adminData = await requireAdmin(db, request);
  const d = data || {};
  const hasIdle = "idleTimeoutEnabled" in d || "idleTimeoutMinutes" in d;
  const hasLock =
    "lockoutEnabled" in d || "lockoutMaxAttempts" in d || "lockoutMinutes" in d;
  if (!hasIdle && !hasLock) {
    throw new HttpsError("invalid-argument", "Choose on or off.");
  }
  if (hasIdle) {
    if (typeof d.idleTimeoutEnabled !== "boolean") {
      throw new HttpsError("invalid-argument", "Choose on or off.");
    }
    if (!ALLOWED_IDLE_MINUTES.includes(d.idleTimeoutMinutes)) {
      throw new HttpsError(
        "invalid-argument",
        `Idle timeout must be one of: ${ALLOWED_IDLE_MINUTES.join(", ")} minutes.`
      );
    }
  }
  if (hasLock) {
    if (typeof d.lockoutEnabled !== "boolean") {
      throw new HttpsError("invalid-argument", "Choose on or off.");
    }
    if (!ALLOWED_LOCKOUT_ATTEMPTS.includes(d.lockoutMaxAttempts)) {
      throw new HttpsError(
        "invalid-argument",
        `Wrong passwords allowed must be one of: ${ALLOWED_LOCKOUT_ATTEMPTS.join(", ")}.`
      );
    }
    if (!ALLOWED_LOCKOUT_MINUTES.includes(d.lockoutMinutes)) {
      throw new HttpsError(
        "invalid-argument",
        `Lockout length must be one of: ${ALLOWED_LOCKOUT_MINUTES.join(", ")} minutes.`
      );
    }
  }

  const ref = db.doc("adminSettings/security");
  const publicRef = db.doc("appConfig/loginSecurity");
  const actor = {
    actorUid: request.auth.uid,
    actorName: adminName(adminData),
    targetType: "security setting",
  };
  let result;
  try {
    await db.runTransaction(async (tx) => {
      const prev = (await tx.get(ref)).data() || {};
      const update = {
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: request.auth.uid,
        updatedByName: adminName(adminData),
      };
      if (hasIdle) {
        update.idleTimeoutEnabled = d.idleTimeoutEnabled;
        update.idleTimeoutMinutes = d.idleTimeoutMinutes;
        tx.set(
          db.collection("auditLogs").doc(),
          buildAuditEntry({
            action: d.idleTimeoutEnabled
              ? `Idle session timeout turned on (${d.idleTimeoutMinutes} minutes)`
              : "Idle session timeout turned off",
            ...actor,
            targetId: "idleTimeout",
            targetName: "Idle session timeout",
          })
        );
      }
      if (hasLock) {
        update.lockoutEnabled = d.lockoutEnabled;
        update.lockoutMaxAttempts = d.lockoutMaxAttempts;
        update.lockoutMinutes = d.lockoutMinutes;
        tx.set(
          publicRef,
          {
            lockoutEnabled: d.lockoutEnabled,
            lockoutMaxAttempts: d.lockoutMaxAttempts,
            lockoutMinutes: d.lockoutMinutes,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        tx.set(
          db.collection("auditLogs").doc(),
          buildAuditEntry({
            action: d.lockoutEnabled
              ? `Failed login lockout turned on (${d.lockoutMaxAttempts} attempts, ${d.lockoutMinutes} minutes)`
              : "Failed login lockout turned off",
            ...actor,
            targetId: "loginLockout",
            targetName: "Failed login lockout",
          })
        );
      }
      tx.set(ref, update, { merge: true });
      const now = { ...prev, ...update };
      result = {
        idleTimeoutEnabled:
          typeof now.idleTimeoutEnabled === "boolean"
            ? now.idleTimeoutEnabled
            : DEFAULT_IDLE.enabled,
        idleTimeoutMinutes: ALLOWED_IDLE_MINUTES.includes(now.idleTimeoutMinutes)
          ? now.idleTimeoutMinutes
          : DEFAULT_IDLE.minutes,
        lockoutEnabled:
          typeof now.lockoutEnabled === "boolean"
            ? now.lockoutEnabled
            : DEFAULT_LOCKOUT.enabled,
        lockoutMaxAttempts: ALLOWED_LOCKOUT_ATTEMPTS.includes(now.lockoutMaxAttempts)
          ? now.lockoutMaxAttempts
          : DEFAULT_LOCKOUT.maxAttempts,
        lockoutMinutes: ALLOWED_LOCKOUT_MINUTES.includes(now.lockoutMinutes)
          ? now.lockoutMinutes
          : DEFAULT_LOCKOUT.minutes,
      };
    });
  } catch (err) {
    throw asClearError(err, "Could not save the setting. Please try again.");
  }
  return result;
}

// ---------------------------------------------------------------------------
// Two-step verification (authenticator code) for admins
// ---------------------------------------------------------------------------

/**
 * Admin-only. Turns the "admins must sign in with an authenticator code"
 * requirement on or off (appConfig/adminAuth, which the Firestore rules, the
 * admin Cloud Functions and the portal all read).
 *
 * Turning it ON is refused unless the admin asking is themselves signed in
 * with an authenticator code right now, so the person switching it on can
 * never lock themselves out. Every OTHER admin must enrol before they next
 * sign in (the portal walks them through it). Audit-logged.
 */
async function setAdminTwoStepRequired({ db, request, data }) {
  const adminData = await requireAdmin(db, request);
  const required = data && data.required;
  if (typeof required !== "boolean") {
    throw new HttpsError("invalid-argument", "Say whether to require it.");
  }
  if (required && !usedSecondFactor(request)) {
    throw new HttpsError(
      "failed-precondition",
      "Set up an authenticator app and sign in with its code first. " +
        "Then you can require it for admins."
    );
  }
  const batch = db.batch();
  batch.set(db.doc("appConfig/adminAuth"), {
    requireTotp: required,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  });
  batch.set(
    db.collection("auditLogs").doc(),
    buildAuditEntry({
      action: required
        ? "Two-step verification turned on for admins"
        : "Two-step verification turned off for admins",
      actorUid: request.auth.uid,
      actorName: adminName(adminData),
      targetType: "security setting",
      targetId: "adminTwoStep",
      targetName: "Two-step verification",
    })
  );
  try {
    await batch.commit();
  } catch (err) {
    throw asClearError(err, "Could not save the setting. Please try again.");
  }
  return { required };
}

// ---------------------------------------------------------------------------
// Admin sign-in events (audit trail)
// ---------------------------------------------------------------------------

const SIGN_IN_EVENT_INTERVAL_MS = 5 * 1000;
const FAILED_SIGN_IN_INTERVAL_MS = 30 * 1000;

/**
 * True if [key] already logged an event within [intervalMs]; otherwise
 * stamps it and returns false. Keeps a script (or anyone calling the
 * sign-in functions in a loop) from filling the audit log.
 */
async function loggedRecently(db, key, nowMs, intervalMs) {
  const ref = db.collection("adminSignInThrottle").doc(key);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const last = snap.exists ? snap.get("lastAt") : 0;
    if (last && nowMs - last < intervalMs) return true;
    tx.set(ref, { lastAt: nowMs });
    return false;
  });
}

/**
 * Called by the admin portal right after any sign-in. The OUTCOME IS DECIDED
 * HERE, from the verified token and the admins collection, never from what
 * the client says: a real admin logs "Admin signed in"; anyone else who got
 * as far as signing in logs a refused attempt (and the portal signs them
 * out). Always answers { ok: true } so it reveals nothing.
 */
async function recordAdminSignIn({ db, request, nowMs = Date.now() }) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const uid = request.auth.uid;
  const snap = await db.collection("admins").doc(uid).get();
  const hasClaim = !!(request.auth.token && request.auth.token.admin === true);
  const isAdmin = snap.exists && hasClaim;

  const key = `${isAdmin ? "ok" : "denied"}_${uid}`;
  const interval = isAdmin
    ? SIGN_IN_EVENT_INTERVAL_MS
    : FAILED_SIGN_IN_INTERVAL_MS;
  if (await loggedRecently(db, key, nowMs, interval)) return { ok: true };

  await db.collection("auditLogs").add(
    buildAuditEntry({
      action: isAdmin
        ? "Admin signed in"
        : "Admin portal sign-in refused: not an admin",
      type: "LOGIN",
      actorUid: uid,
      actorName: isAdmin ? adminName(snap.data() || {}) : null,
      targetType: "admin portal",
      result: isAdmin ? "success" : "failure",
      reason: isAdmin
        ? usedSecondFactor(request)
          ? "authenticator_code"
          : null
        : snap.exists
          ? "claim_missing"
          : "not_an_admin",
    })
  );
  return { ok: true };
}

/**
 * Called (signed out) when an admin-portal sign-in fails. It only logs when
 * the email belongs to an admin, so strangers' typos and probing for emails
 * leave no trace and the answer is always the same { ok: true }. At most one
 * entry per admin every 30 seconds.
 */
async function recordAdminSignInFailure({
  db,
  auth,
  data,
  nowMs = Date.now(),
}) {
  const email =
    data && typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  if (!email || email.length > 254) return { ok: true };

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (_) {
    return { ok: true };
  }
  const snap = await db.collection("admins").doc(user.uid).get();
  const claimed = !!(user.customClaims && user.customClaims.admin === true);
  if (!snap.exists && !claimed) return { ok: true };

  if (await loggedRecently(db, `fail_${user.uid}`, nowMs, FAILED_SIGN_IN_INTERVAL_MS)) {
    return { ok: true };
  }
  const reasons = [
    "wrong_password",
    "wrong_code",
    "user_disabled",
    "too_many_attempts",
  ];
  await db.collection("auditLogs").add(
    buildAuditEntry({
      action: "Failed admin sign-in attempt",
      type: "LOGIN",
      actorUid: user.uid,
      actorName: adminName(snap.exists ? snap.data() || {} : {}),
      targetType: "admin portal",
      result: "failure",
      reason: reasons.includes(data.reason) ? data.reason : "wrong_password",
    })
  );
  return { ok: true };
}

// ---------------------------------------------------------------------------
// "Ghost" phone numbers and emails
// ---------------------------------------------------------------------------

/**
 * A sign-up that was never finished is only treated as abandoned once it is
 * this old, so someone still on the OTP screen can never lose their number.
 */
const UNFINISHED_SIGNUP_MS = 60 * 60 * 1000;

/** True when the sign-in account is gone, or older than [UNFINISHED_SIGNUP_MS]. */
async function isGoneOrOld(auth, uid, nowMs) {
  try {
    const user = await auth.getUser(uid);
    const created = Date.parse(user.metadata && user.metadata.creationTime);
    return Number.isFinite(created) && nowMs - created > UNFINISHED_SIGNUP_MS;
  } catch (err) {
    return err && err.code === "auth/user-not-found";
  }
}

/**
 * Whether [holder] (a uid) holding the reservation of [key] is a ghost: see
 * releaseStaleContact. [kind] is "phone" or "email". Reads only.
 */
async function isGhostHolder({ db, auth, kind, key, holder, nowMs = Date.now() }) {
  const field = kind === "phone" ? "phoneNumber" : "recoveryEmail";
  const normalize = (v) =>
    kind === "phone"
      ? canonicalPhoneOrNull(v)
      : typeof v === "string"
        ? v.trim().toLowerCase()
        : null;
  const profile = holder ? await db.collection("users").doc(holder).get() : null;
  if (!profile || !profile.exists) return true;
  if (profile.get("registrationComplete") === true) {
    return normalize(profile.get(field)) !== key;
  }
  const unfinished =
    profile.get("registrationComplete") === false ||
    (profile.get("phoneVerified") !== true &&
      profile.get("onboardingComplete") !== true);
  return unfinished && (await isGoneOrOld(auth, holder, nowMs));
}

/**
 * Called by the app when sign-up says a phone number (or email) is "already
 * registered". Phone numbers and emails are reserved in phones/{number} and
 * emails/{address} = {uid}. If whoever holds the reservation is a GHOST, the
 * reservation is released so the person can register:
 *
 *  - the holder's profile no longer exists, or
 *  - the holder never finished signing up (registrationComplete is false, or
 *    missing with no verification/onboarding progress) and the sign-in
 *    account is gone or more than an hour old, or
 *  - the holder finished signing up but their profile no longer uses this
 *    number/address.
 *
 * A real, finished account is never touched. Nothing else is deleted: only
 * the reservation, and (if the profile still names it) that one field.
 * Returns { released: true | false, reason? }.
 */
async function releaseStaleContact({ db, auth, request, data, nowMs = Date.now() }) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const kind = data && data.kind;
  if (kind !== "phone" && kind !== "email") {
    throw new HttpsError("invalid-argument", "kind must be phone or email.");
  }
  const raw = data && data.value;
  let key;
  if (kind === "phone") {
    key = cleanPhone(raw);
  } else {
    key = typeof raw === "string" ? raw.trim().toLowerCase() : "";
    if (!/^[^@\s]+@[^@\s]+$/.test(key)) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }
  }
  const collection = kind === "phone" ? "phones" : "emails";
  const field = kind === "phone" ? "phoneNumber" : "recoveryEmail";
  const normalize = (v) =>
    kind === "phone"
      ? canonicalPhoneOrNull(v)
      : typeof v === "string"
        ? v.trim().toLowerCase()
        : null;

  try {
    // Is the holder a ghost? (reads only; the Auth lookup is not in the
    // transaction)
    const reservationRef = db.collection(collection).doc(key);
    const reservation = await reservationRef.get();
    if (!reservation.exists) return { released: true };
    const holder = reservation.get("uid");
    if (holder === request.auth.uid) return { released: false, reason: "yours" };

    const profileRef = holder ? db.collection("users").doc(holder) : null;
    const stale = await isGhostHolder({ db, auth, kind, key, holder, nowMs });
    if (!stale) return { released: false, reason: "in-use" };

    // Release it, but only if it still is that holder's reservation.
    await db.runTransaction(async (tx) => {
      const again = await tx.get(reservationRef);
      if (!again.exists || again.get("uid") !== holder) return;
      const profileAgain = profileRef ? await tx.get(profileRef) : null;
      tx.delete(reservationRef);
      if (
        profileAgain &&
        profileAgain.exists &&
        normalize(profileAgain.get(field)) === key
      ) {
        tx.update(profileRef, { [field]: FieldValue.delete() });
      }
    });
    return { released: true };
  } catch (err) {
    throw asClearError(err, "Could not check this right now. Try again.");
  }
}

module.exports = {
  releaseStaleContact,
  isGhostHolder,
  UNFINISHED_SIGNUP_MS,
  ALLOWED_IDLE_MINUTES,
  DEACTIVATION_GRACE_DAYS,
  updateSecuritySettings,
  updateUserProfile,
  sendNotificationToUser,
  scheduleNotification,
  updateScheduledNotification,
  pushToUsers,
  respondToFeedback,
  recordAdminSignIn,
  recordAdminSignInFailure,
  requireAdmin,
  setAdminTwoStepRequired,
  adminTwoStepRequired,
  usedSecondFactor,
  scheduleDeactivation,
  cancelDeactivation,
  processDueDeactivations,
  reactivateAccount,
  cancelScheduledNotification,
  processDueNotifications,
};
