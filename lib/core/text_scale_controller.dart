import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide text scale factor (Personalization > Text Size). A single
/// source of truth so every screen scales consistently, rather than each
/// screen computing its own scaled font sizes.
///
/// Applied at the [MaterialApp] root via a `MediaQuery` override in a
/// `builder`, so it takes effect immediately across the whole app and
/// composes correctly with the device's own system text-scale setting.
class TextScaleController extends ChangeNotifier {
  TextScaleController._();
  static final TextScaleController instance = TextScaleController._();

  static const double min = 0.8;
  static const double max = 1.6;
  static const double _defaultScale = 1.0;
  static const String _prefsKey = 'text_scale_factor';

  double _scale = _defaultScale;
  double get scale => _scale;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads the persisted scale, if any. Safe to call multiple times —
  /// only loads once. Call this once at app startup, before the first
  /// frame if possible (a brief default-scale flash otherwise is
  /// harmless).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_prefsKey);
      if (stored != null) {
        _scale = stored.clamp(min, max);
      }
    } catch (e) {
      debugPrint('TextScaleController.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setScale(double value) async {
    final clamped = value.clamp(min, max);
    if (clamped == _scale) return;
    _scale = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, clamped);
    } catch (e) {
      debugPrint('TextScaleController.setScale persist error: $e');
    }
  }
}
