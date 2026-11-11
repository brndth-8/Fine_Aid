import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../i18n/app_language.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../services/api/gemini_service.dart';
import '../../../i18n/licenses_strings.dart';
import '../../../i18n/settings_strings.dart';
import 'licenses_screen.dart';
import 'personalization_screen.dart';
import 'help_screen.dart';
import 'ai_scan_info_screen.dart';
import '../../../i18n/ai_scan_stats_strings.dart';
import '../../auth/screens/terms_screen.dart';
import 'feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Opens the official FineAid website in the browser.
Future<void> _openWebsite() async {
  try {
    await launchUrl(
      Uri.parse('https://www.FineAid.site'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Nothing to do: the address is shown on screen for the user to copy.
  }
}

/// "Log out?" confirmation (same dialog style as the app's other
/// confirmations). Returns true only when the user taps "Log out"; Cancel,
/// tapping outside, the Android back button and swiping it away all return
/// false, so none of them can log the user out.
Future<bool> confirmLogout(BuildContext context) async {
  final s = SettingsStrings.of(context);
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      // Only the first tap counts, so a double-tap can't pop twice (the
      // second pop would close the Settings screen behind the dialog).
      var answered = false;
      void answer(bool value) {
        if (answered) return;
        answered = true;
        Navigator.pop(dialogContext, value);
      }

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.logOutConfirmTitle),
        content: Text(s.logOutConfirmMessage),
        actions: [
          OutlinedButton(
            onPressed: () => answer(false),
            child: Text(s.logOutConfirmCancel),
          ),
          ElevatedButton(
            onPressed: () => answer(true),
            // The theme's dark red (primary) with its on-colour (white) text.
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text(s.logOutConfirmButton),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  bool _isConfirmingLogout = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut || _isConfirmingLogout) return; // double-tap guard
    _isConfirmingLogout = true;
    final confirmed = await confirmLogout(context);
    _isConfirmingLogout = false;
    if (!confirmed || !mounted) return; // cancelled: nothing changes

    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await AuthService().signOut();
      // Forget the signed-in user's AI chat session too.
      GeminiService().reset();
      if (!mounted) return;
      // Always end on the login screen with an empty back stack: Back can't
      // return to a signed-in screen, and no guest dashboard is left behind.
      resetToLogin(Navigator.of(context));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SettingsStrings.of(context).logOutError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = SettingsStrings.of(context);
    final isGuest = AuthService().currentUser == null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(s.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                children: [
                  _banner(theme, s),
                  const SizedBox(height: 14),
                  _settingsTile(
                    context,
                    icon: Icons.text_fields,
                    label: s.personalization,
                    subtitle: s.personalizationSub,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalizationScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsTile(
                    context,
                    icon: Icons.info_outline,
                    label: s.aboutApplication,
                    subtitle: s.aboutApplicationSub,
                    onTap: () => _showAboutDialog(context, s),
                  ),
                  _settingsTile(
                    context,
                    icon: Icons.document_scanner_outlined,
                    label: AiScanStatsStrings.of(context).settingsLabel,
                    subtitle: s.aboutScanSub,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiScanInfoScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsTile(
                    context,
                    icon: Icons.help_outline,
                    label: s.helpFaq,
                    subtitle: s.helpFaqSub,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpScreen(),
                        ),
                      );
                    },
                  ),
                  // Language (English / Tagalog), applied app-wide.
                  _settingsTile(
                    context,
                    icon: Icons.language,
                    label: s.language,
                    subtitle: s.languageSub,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLanguageScope.of(context) == AppLanguage.tl
                              ? s.tagalog
                              : s.english,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _chooseLanguage(context, s),
                  ),
                  _settingsTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: s.feedback,
                    subtitle: s.feedbackSub,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsTile(
                    context,
                    icon: Icons.edit_note,
                    label: s.terms,
                    subtitle: s.termsSub,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TermsScreen(readOnly: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Small centered note and the official website, above Log out.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                children: [
                  Text(
                    s.footerNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  InkWell(
                    onTap: _openWebsite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'www.FineAid.site',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: ElevatedButton.icon(
                onPressed: isGuest
                    ? () => Navigator.pushNamed(context, '/login-form')
                    : (_isLoggingOut ? null : _handleLogout),
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isGuest ? Icons.login : Icons.logout, size: 20),
                label: Text(
                  isGuest
                      ? s.signIn
                      : (_isLoggingOut ? s.loggingOut : s.logOut),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The maroon card at the top: the line about the settings and a gear.
  Widget _banner(ThemeData theme, SettingsStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 26),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.banner,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE3E3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings,
              size: 26,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Asks which language to use (applied app-wide at once).
  Future<void> _chooseLanguage(BuildContext context, SettingsStrings s) {
    final current = AppLanguageScope.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(s.language),
        children: [
          for (final (language, name) in [
            (AppLanguage.en, s.english),
            (AppLanguage.tl, s.tagalog),
          ])
            SimpleDialogOption(
              onPressed: () {
                AppLanguageController.instance.setLanguage(language);
                Navigator.pop(dialogContext);
              },
              child: Row(
                children: [
                  Expanded(child: Text(name)),
                  if (language == current)
                    Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE3E3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF303130),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right,
                      size: 26,
                      color: Color(0xFF8F8584),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The About box: name, version, a line about the app, and View Licenses
  // (the Application Licenses & Technology Disclosure page).
  void _showAboutDialog(BuildContext context, SettingsStrings s) {
    final licenses = LicensesStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Fine Aid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1.0.1'),
            const SizedBox(height: 12),
            Text(s.aboutLegalese),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
            child: Text(licenses.viewLicenses),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.closeButton),
          ),
        ],
      ),
    );
  }
}
