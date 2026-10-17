import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's display language (Settings > Language).
enum AppLanguage { en, tl }

/// App-wide language choice, saved on the device. A single source of truth,
/// same pattern as [TextScaleController]: loaded at startup in main.dart and
/// applied at the [MaterialApp] root through [AppLanguageScope], so changing
/// it re-renders every screen immediately.
class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();
  static final AppLanguageController instance = AppLanguageController._();

  static const String _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads the saved language, if any (English otherwise). Safe to call more
  /// than once — only loads once.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString(_prefsKey) == 'tl'
          ? AppLanguage.tl
          : AppLanguage.en;
    } catch (e) {
      debugPrint('AppLanguageController.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        language == AppLanguage.tl ? 'tl' : 'en',
      );
    } catch (e) {
      // Persistence is a nice-to-have: an unsaved choice just falls back to
      // English next launch instead of breaking the switch.
      debugPrint('AppLanguageController.setLanguage persist error: $e');
    }
  }
}

/// Makes the current [AppLanguage] available to every screen below it.
/// Screens read it with [AppLanguageScope.of], which also registers them to
/// rebuild when the language changes.
class AppLanguageScope extends InheritedWidget {
  final AppLanguage language;

  const AppLanguageScope({
    super.key,
    required this.language,
    required super.child,
  });

  /// The language for [context]. Falls back to the controller's current value
  /// when there is no scope above (eg a widget shown on its own in a test).
  static AppLanguage of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.language ?? AppLanguageController.instance.language;
  }

  static bool isTagalog(BuildContext context) => of(context) == AppLanguage.tl;

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      language != oldWidget.language;
}
