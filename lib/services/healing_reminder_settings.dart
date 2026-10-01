import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether healing-milestone reminder notifications are scheduled at all —
/// a single on/off toggle in Settings. A single source of truth (mirrors
/// TextScaleController's pattern) so the Settings screen and
/// NotificationService always agree on the current state without a
/// redundant SharedPreferences read in each place.
class HealingReminderSettings extends ChangeNotifier {
  HealingReminderSettings._();
  static final HealingReminderSettings instance = HealingReminderSettings._();

  static const String _prefsKey = 'healing_reminders_enabled';

  bool _enabled = true;
  bool get enabled => _enabled;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (e) {
      debugPrint('HealingReminderSettings.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      debugPrint('HealingReminderSettings.setEnabled persist error: $e');
    }
  }

  /// Reads the current value, loading it first if this is the first call
  /// this session — for one-off checks (eg right before scheduling a
  /// reminder) where a widget listener isn't set up.
  Future<bool> isEnabled() async {
    await load();
    return _enabled;
  }
}
