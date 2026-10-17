const admin = require("firebase-admin");

const VALID_TYPES = new Set(["CREATE", "UPDATE", "DELETE", "LOGIN"]);
const VALID_RESULTS = new Set(["success", "failure"]);

function text(value, max) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed.slice(0, max);
}

/**
 * The one shape every audit entry is written in. Used by the writeAuditLog
 * callable and by server-side jobs (deactivation, notification
 * cancellation), so nothing can forge the actor or the timestamp: both are
 * decided here, on the server. Never put secrets, passwords, free-text user
 * content or photos in an entry — only names, ids and short reasons.
 *
 * `type` is kept (CREATE / UPDATE / DELETE / LOGIN) because the Audit Logs
 * screen colours its pills by it.
 */
function buildAuditEntry({
  action,
  type = "UPDATE",
  actorUid = null,
  actorName = null,
  targetType = null,
  targetId = null,
  targetName = null,
  result = "success",
  reason = null,
}) {
  const cleanAction = text(action, 200);
  if (!cleanAction) throw new Error("An audit entry needs an action.");
  return {
    action: cleanAction,
    type: VALID_TYPES.has(type) ? type : "UPDATE",
    actorUid: text(actorUid, 128),
    actorName: text(actorName, 120),
    targetType: text(targetType, 40),
    targetId: text(targetId, 128),
    targetName: text(targetName, 120),
    result: VALID_RESULTS.has(result) ? result : "success",
    reason: text(reason, 100),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
}

module.exports = { buildAuditEntry };
