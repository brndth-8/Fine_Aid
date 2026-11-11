import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One Guest Mode journal entry as the screens read it: the same field names
/// the Firestore entries use (so the existing cards and detail screen work),
/// with `createdAt` as a [Timestamp].
class GuestJournalEntry {
  final String id;
  final Map<String, dynamic> data;
  const GuestJournalEntry(this.id, this.data);
}

/// Journal entries written in Guest Mode, kept on this phone only (there is
/// no account to store them under). When the person signs up or signs in,
/// [migrateTo] moves them into that account's journal and clears them here.
///
/// Text, category and pain/itch scores are kept. Photos are not (they have
/// nowhere to be uploaded without an account).
class GuestJournalStore {
  GuestJournalStore._();
  static final GuestJournalStore instance = GuestJournalStore._();

  static const _key = 'guest_journal_entries_v1';

  // Keeps ids unique even for two entries saved in the same instant.
  int _seq = 0;

  /// The entries, newest first. Screens listen to this.
  final ValueNotifier<List<GuestJournalEntry>> entries = ValueNotifier(
    const [],
  );

  // What is stored: id, title, description, classification, severity,
  // painScore, itchScore, painScaleMax and createdAt (ISO 8601 text).
  Future<List<Map<String, dynamic>>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    if (list.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(list));
    }
    _publish(list);
  }

  void _publish(List<Map<String, dynamic>> list) {
    final sorted = [...list]
      ..sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
    entries.value = [
      for (final e in sorted)
        GuestJournalEntry(e['id'] as String, {
          ...e,
          'createdAt': Timestamp.fromDate(
            DateTime.parse(e['createdAt'] as String),
          ),
          'imageUrls': <String>[],
          'imageCount': 0,
          'remindMe': false,
          'isLocal': true,
        }),
    ];
  }

  /// Reads what is stored into [entries]. Call before showing them.
  Future<void> load() async => _publish(await _read());

  /// Saves a new entry and returns its id.
  Future<String> add({
    required String title,
    required String description,
    String? classification,
    String? severity,
    int? painScore,
    int? painScaleMax,
    int? itchScore,
    required DateTime createdAt,
  }) async {
    final list = await _read();
    final id = 'guest_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    list.add({
      'id': id,
      'title': title,
      'description': description,
      'classification': classification,
      'severity': severity,
      'painScore': painScore,
      'painScaleMax': painScaleMax,
      'itchScore': ?itchScore,
      'createdAt': createdAt.toIso8601String(),
    });
    await _write(list);
    return id;
  }

  /// Changes the title and/or description of an entry.
  Future<void> update(String id, {String? title, String? description}) async {
    final list = await _read();
    for (final e in list) {
      if (e['id'] == id) {
        if (title != null) e['title'] = title;
        if (description != null) e['description'] = description;
      }
    }
    await _write(list);
  }

  Future<void> remove(String id) async {
    final list = await _read()
      ..removeWhere((e) => e['id'] == id);
    await _write(list);
  }

  /// Moves every stored entry into `users/[uid]/journalEntries` and returns
  /// how many moved. Each keeps its own id as the document id, so running
  /// this again (after a failure or a timeout) never makes a duplicate. An
  /// entry is only removed here once its write succeeded.
  ///
  /// [writeDoc] replaces the Firestore write (tests).
  Future<int> migrateTo(
    String uid, {
    Future<void> Function(String id, Map<String, dynamic> doc)? writeDoc,
  }) async {
    final write =
        writeDoc ??
        (String id, Map<String, dynamic> doc) => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('journalEntries')
            .doc(id)
            .set(doc)
            .timeout(const Duration(seconds: 10));
    final list = await _read();
    if (list.isEmpty) return 0;
    var moved = 0;
    for (final e in [...list]) {
      try {
        await write(e['id'] as String, firestoreDoc(e));
        list.removeWhere((x) => x['id'] == e['id']);
        moved++;
      } catch (_) {
        // Keep it; it is tried again next time.
      }
    }
    await _write(list);
    return moved;
  }

  /// The Firestore document for a stored entry (same fields a normal entry
  /// has, no photos, no reminder).
  @visibleForTesting
  static Map<String, dynamic> firestoreDoc(Map<String, dynamic> e) => {
    'title': e['title'],
    'description': e['description'],
    'classification': e['classification'],
    'severity': e['severity'],
    'painScore': e['painScore'],
    'painScaleMax': ?e['painScaleMax'],
    'itchScore': ?e['itchScore'],
    'remindMe': false,
    'imageUrls': <String>[],
    'imageCount': 0,
    'createdAt': Timestamp.fromDate(DateTime.parse(e['createdAt'] as String)),
    'fromGuestMode': true,
  };
}
