import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why a scan counted as failed. Only these reasons are logged — never the
/// photo, the wound, or anything about the person.
enum ScanFailureReason {
  offline,
  timeout,
  serverError,
  unreadableResponse,
  unreadableImage,
  lowConfidence,
}

/// A completed scan whose model confidence is below this counts as failed
/// (reason: low confidence), even though a result is still shown.
const double kLowConfidenceThreshold = 0.5;

/// Works out the failure reason from the error text a failed scan carries.
ScanFailureReason failureReasonFromError(String message) {
  final m = message.toLowerCase();
  if (m.contains('timed out') || m.contains('timeout')) {
    return ScanFailureReason.timeout;
  }
  if (m.contains('socketexception') ||
      m.contains('network') ||
      m.contains('no internet') ||
      m.contains('connection') ||
      m.contains('failed host lookup')) {
    return ScanFailureReason.offline;
  }
  if (m.contains('formatexception') ||
      m.contains('json') ||
      m.contains('unexpected character') ||
      m.contains('parse')) {
    return ScanFailureReason.unreadableResponse;
  }
  if (m.contains('filesystemexception') ||
      m.contains('pathnotfound') ||
      m.contains('decode') ||
      m.contains('image')) {
    return ScanFailureReason.unreadableImage;
  }
  return ScanFailureReason.serverError;
}

/// The counters, and the rates computed from them. Every rate is null (shown
/// as "No data yet") when there is nothing to divide by.
///
/// - total = successful + failed + no-wound-found
/// - success rate = successful / total
/// - failure rate = failed / total
/// - accuracy = rated correct / (rated correct + rated wrong); only among
///   scans the user actually rated
/// - reliability = scans that completed AND were not flagged wrong / total
class AiScanStats {
  final int total;
  final int success;
  final int failed;
  final int noWound;
  final int ratedCorrect;
  final int ratedWrong;
  final Map<ScanFailureReason, int> failedByReason;

  const AiScanStats({
    this.total = 0,
    this.success = 0,
    this.failed = 0,
    this.noWound = 0,
    this.ratedCorrect = 0,
    this.ratedWrong = 0,
    this.failedByReason = const {},
  });

  int get rated => ratedCorrect + ratedWrong;

  double? get successRate => total <= 0 ? null : success / total * 100;
  double? get failureRate => total <= 0 ? null : failed / total * 100;
  double? get accuracyRate => rated <= 0 ? null : ratedCorrect / rated * 100;
  double? get reliability =>
      total <= 0 ? null : (success - ratedWrong).clamp(0, total) / total * 100;

  /// Builds the stats from raw counter values (as stored).
  factory AiScanStats.fromCounters(Map<String, int> c) {
    int v(String k) => (c[k] ?? 0) < 0 ? 0 : (c[k] ?? 0);
    return AiScanStats(
      total: v('total'),
      success: v('success'),
      failed: v('failed'),
      noWound: v('noWound'),
      ratedCorrect: v('ratedCorrect'),
      ratedWrong: v('ratedWrong'),
      failedByReason: {
        for (final r in ScanFailureReason.values)
          if (v('failed_${r.name}') > 0) r: v('failed_${r.name}'),
      },
    );
  }
}

/// Where the counters live.
abstract class AiScanStatsStore {
  /// Adds [deltas] (which may be negative) to the stored counters.
  Future<void> add(Map<String, int> deltas);
  Future<Map<String, int>> read();
}

/// Device-only storage — used when nobody is signed in.
class LocalAiScanStatsStore implements AiScanStatsStore {
  static const String prefsKey = 'ai_scan_stats_guest_v1';

  @override
  Future<void> add(Map<String, int> deltas) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await read();
    deltas.forEach((k, d) => current[k] = (current[k] ?? 0) + d);
    await prefs.setString(prefsKey, jsonEncode(current));
  }

  @override
  Future<Map<String, int>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }
}

/// Per-account storage: one summary document at
/// users/{uid}/aiScanStats/summary, updated with atomic increments.
class FirestoreAiScanStatsStore implements AiScanStatsStore {
  final String uid;
  FirestoreAiScanStatsStore(this.uid);

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('aiScanStats')
      .doc('summary');

  @override
  Future<void> add(Map<String, int> deltas) {
    // Not awaited by callers: offline, Firestore queues this and sends it
    // later, and the future only completes once it has been sent.
    return _doc.set({
      for (final e in deltas.entries) e.key: FieldValue.increment(e.value),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, int>> read() async {
    final snap = await _doc.get().timeout(const Duration(seconds: 8));
    final data = snap.data() ?? const <String, dynamic>{};
    return {
      for (final e in data.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    };
  }
}

/// Counts AI scans and how often they go through. Counting must never get in
/// the way of a scan, so nothing here ever throws or makes the caller wait.
class AiScanStatsService {
  AiScanStatsService({AiScanStatsStore Function()? storeFactory})
    : _storeFactory = storeFactory ?? _defaultStore;

  static final AiScanStatsService instance = AiScanStatsService();

  final AiScanStatsStore Function() _storeFactory;

  static AiScanStatsStore _defaultStore() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? LocalAiScanStatsStore()
        : FirestoreAiScanStatsStore(user.uid);
  }

  void _apply(Map<String, int> deltas) {
    try {
      unawaited(
        _storeFactory().add(deltas).catchError((Object e) {
          debugPrint('[AiScanStats] could not save: $e');
        }),
      );
    } catch (e) {
      debugPrint('[AiScanStats] could not save: $e');
    }
  }

  /// A scan completed and returned a usable result.
  void recordSuccess() => _apply({'total': 1, 'success': 1});

  /// A scan completed but found no wound — not a failure of the scan.
  void recordNoWound() => _apply({'total': 1, 'noWound': 1});

  /// A scan failed technically, for [reason].
  void recordFailure(ScanFailureReason reason) =>
      _apply({'total': 1, 'failed': 1, 'failed_${reason.name}': 1});

  /// The user said whether the result was correct. [previous] is what they
  /// said before for the same scan (null if nothing), so changing their mind
  /// moves the count instead of adding a second one.
  void recordRating({bool? previous, required bool? current}) {
    if (previous == current) return;
    final deltas = <String, int>{};
    if (previous != null) {
      deltas[previous ? 'ratedCorrect' : 'ratedWrong'] = -1;
    }
    if (current != null) {
      deltas[current ? 'ratedCorrect' : 'ratedWrong'] =
          (deltas[current ? 'ratedCorrect' : 'ratedWrong'] ?? 0) + 1;
    }
    _apply(deltas);
  }

  /// The current counters; empty stats if they can't be read.
  Future<AiScanStats> load() async {
    try {
      return AiScanStats.fromCounters(await _storeFactory().read());
    } catch (e) {
      debugPrint('[AiScanStats] could not load: $e');
      return const AiScanStats();
    }
  }
}
