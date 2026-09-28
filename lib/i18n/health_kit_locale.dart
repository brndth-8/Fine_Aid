import 'package:shared_preferences/shared_preferences.dart';

/// Language choice for the First Aid Health Kit screen's own pre-written
/// content (categories, questions, steps). Deliberately separate from the
/// AI Camera assessment screen's Tagalog toggle, which translates a
/// Gemini-generated result on demand rather than switching between two
/// already-written texts.
enum HealthKitLocale { en, tl }

const String _healthKitLocalePrefsKey = 'health_kit_locale';

Future<HealthKitLocale> loadHealthKitLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_healthKitLocalePrefsKey);
    return stored == 'tl' ? HealthKitLocale.tl : HealthKitLocale.en;
  } catch (_) {
    return HealthKitLocale.en;
  }
}

Future<void> saveHealthKitLocale(HealthKitLocale locale) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _healthKitLocalePrefsKey,
      locale == HealthKitLocale.tl ? 'tl' : 'en',
    );
  } catch (_) {
    // Persistence is a nice-to-have — an unsaved toggle just falls back
    // to English next launch rather than breaking the screen.
  }
}
