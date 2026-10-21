import 'package:flutter/material.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../i18n/app_language.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../services/api/gemini_service.dart';
import '../../../i18n/settings_strings.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 48), // balance the back button
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _settingsTile(
                      context,
                      icon: Icons.person_outline,
                      label: s.personalization,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PersonalizationScreen(),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),
                    _settingsTile(
                      context,
                      icon: Icons.info_outline,
                      label: s.aboutApplication,
                      onTap: () => _showAboutDialog(context, s),
                    ),

                    const Divider(height: 1),
                    _settingsTile(
                      context,
                      icon: Icons.analytics_outlined,
                      label: AiScanStatsStrings.of(context).settingsLabel,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AiScanInfoScreen(),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),
                    _settingsTile(
                      context,
                      icon: Icons.help_outline,
                      label: s.helpFaq,
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
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.language,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                s.language,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<AppLanguage>(
                              segments: [
                                ButtonSegment(
                                  value: AppLanguage.en,
                                  label: Text(s.english),
                                ),
                                ButtonSegment(
                                  value: AppLanguage.tl,
                                  label: Text(s.tagalog),
                                ),
                              ],
                              selected: {AppLanguageScope.of(context)},
                              onSelectionChanged: (selection) =>
                                  AppLanguageController.instance.setLanguage(
                                    selection.first,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _linkText(context, s.rateApp, () {}),

              const SizedBox(height: 16),
              _linkText(context, s.feedback, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackScreen(),
                  ),
                );
              }),

              const SizedBox(height: 16),
              _linkText(context, s.terms, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsScreen(readOnly: true),
                  ),
                );
              }),
              const Spacer(),

              ElevatedButton.icon(
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
                    : Icon(isGuest ? Icons.login : Icons.logout),
                label: Text(
                  isGuest
                      ? s.signIn
                      : (_isLoggingOut ? s.loggingOut : s.logOut),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _linkText(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, SettingsStrings s) {
    showAboutDialog(
      context: context,
      applicationName: 'Fine Aid',
      applicationVersion: '1.0.0',
      applicationLegalese: s.aboutLegalese,
    );
  }
}
