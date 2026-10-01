import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks how many AI Cam scans + follow-up questions a GUEST (not
/// registered or logged in) has used today, so guests get a daily cap
/// while registered/logged-in users remain unlimited. Local-only
/// (shared_preferences), reset at local midnight by comparing today's date
/// string to the last stored one.
///
/// Caveat worth knowing: this is purely on-device, so it resets if the
/// user clears app data or reinstalls. If that matters (eg, someone
/// deliberately working around the limit), the fix is server-side tracking
/// keyed by a stable device ID, which this does not attempt.
class GuestUsageService extends ChangeNotifier {
  GuestUsageService._();
  static final GuestUsageService instance = GuestUsageService._();

  static const int dailyLimit = 5;
  static const String _countKey = 'guest_daily_usage_count';
  static const String _dateKey = 'guest_daily_usage_date';

  int _remaining = dailyLimit;
  int get remaining => _remaining;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Re-reads the stored count/date, rolling over to a fresh count if the
  /// stored date isn't today. Safe to call as often as needed.
  Future<int> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final storedDate = prefs.getString(_dateKey);
      int used;
      if (storedDate != today) {
        await prefs.setString(_dateKey, today);
        await prefs.setInt(_countKey, 0);
        used = 0;
      } else {
        used = prefs.getInt(_countKey) ?? 0;
      }
      _remaining = (dailyLimit - used).clamp(0, dailyLimit);
    } catch (e) {
      debugPrint('GuestUsageService.refresh error: $e');
      _remaining = dailyLimit;
    }
    _loaded = true;
    notifyListeners();
    return _remaining;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  Future<bool> hasReachedLimit() async => (await refresh()) <= 0;

  /// Call ONLY after a request was actually sent AND succeeded — an
  /// offline failure (or any error before a real response came back) must
  /// never consume a guest's daily allowance.
  Future<void> recordSuccessfulUse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final storedDate = prefs.getString(_dateKey);
      final used = storedDate == today ? (prefs.getInt(_countKey) ?? 0) + 1 : 1;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, used);
      _remaining = (dailyLimit - used).clamp(0, dailyLimit);
    } catch (e) {
      debugPrint('GuestUsageService.recordSuccessfulUse error: $e');
    }
    _loaded = true;
    notifyListeners();
  }
}
