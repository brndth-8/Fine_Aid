import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Turns user IDs into display names without a read per row: unknown IDs are
/// fetched together (one `whereIn` query per 30 IDs, Firestore's limit) and
/// remembered, so paging back and forth doesn't re-read them.
///
/// Call [ensure] with the IDs on the current page, then rebuild; [nameFor]
/// shows "…" while a lookup is in flight and [fallback] if no name exists
/// (missing field or deleted user) — never the raw ID.
class AdminNameLookup {
  AdminNameLookup({required this.collection, required this.nameOf});

  final String collection;
  final String? Function(Map<String, dynamic> data) nameOf;

  final Map<String, String> _names = {};
  final Set<String> _requested = {};
  final Set<String> _done = {};

  String nameFor(String? uid, {String fallback = 'Unknown user'}) {
    if (uid == null || uid.isEmpty) return fallback;
    final name = _names[uid];
    if (name != null) return name;
    return _done.contains(uid) ? fallback : '…';
  }

  /// Returns true if anything new was resolved (so the caller should rebuild).
  Future<bool> ensure(Iterable<String?> uids) async {
    final pending = uids
        .whereType<String>()
        .where((u) => u.isNotEmpty && !_requested.contains(u))
        .toSet()
        .toList();
    if (pending.isEmpty) return false;
    _requested.addAll(pending);

    for (var i = 0; i < pending.length; i += 30) {
      final chunk = pending.sublist(i, min(i + 30, pending.length));
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final name = nameOf(doc.data());
          if (name != null && name.trim().isNotEmpty) {
            _names[doc.id] = name.trim();
          }
        }
        _done.addAll(chunk);
      } catch (_) {
        // Show the fallback rather than a stuck "…", but let a later
        // page/refresh retry these IDs.
        _done.addAll(chunk);
        _requested.removeAll(chunk);
      }
    }
    return true;
  }
}

/// Who did an audit-log action. Entries written since the server-side audit
/// writer store `actorUid` / `actorName`; older ones only have `userId`.
String? auditActorUid(Map<String, dynamic> data) =>
    (data['actorUid'] ?? data['userId']) as String?;

/// Display name for an audit entry's actor: the name recorded with the entry
/// when there is one, otherwise a lookup by id, otherwise "System".
String auditActorLabel(Map<String, dynamic> data, AdminNameLookup names) {
  final stored = (data['actorName'] as String?)?.trim();
  if (stored != null && stored.isNotEmpty) return stored;
  final uid = auditActorUid(data);
  if (uid == null || uid.isEmpty) return 'System';
  return names.nameFor(uid);
}
