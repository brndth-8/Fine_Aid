import 'package:flutter/material.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/healing_reminder_settings.dart';
import 'personalization_screen.dart';
import 'help_screen.dart';
import '../../auth/screens/terms_screen.dart';
import 'feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    HealingReminderSettings.instance.load();
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return; // guards against a double-tap race
    setState(() => _isLoggingOut = true);

    try {
      await AuthService().signOut();
      if (!mounted) return;
      // Pop every pushed route (Dashboard, Settings, etc.) back to
      // AuthGate, which now shows the landing/login screen since the user
      // is signed out. Without this, signing out leaves the authenticated
      // screens sitting on the navigation stack, reachable via back.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      'Settings',
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
                      label: 'Personalization',
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
                      label: 'About Application',
                      onTap: () => _showAboutDialog(context),
                    ),

                    const Divider(height: 1),
                    _settingsTile(
                      context,
                      icon: Icons.help_outline,
                      label: 'Help/FAQ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpScreen(),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),
                    ListenableBuilder(
                      listenable: HealingReminderSettings.instance,
                      builder: (context, _) => SwitchListTile(
                        secondary: Icon(
                          Icons.notifications_active_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          'Healing milestone reminders',
                          style: theme.textTheme.bodyLarge,
                        ),
                        subtitle: const Text(
                          'Get notified when a saved wound reaches its '
                          'expected healing time.',
                        ),
                        value: HealingReminderSettings.instance.enabled,
                        onChanged: (value) =>
                            HealingReminderSettings.instance.setEnabled(value),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _linkText(context, 'Rate this app', () {}),

              const SizedBox(height: 16),
              _linkText(context, 'Feedback', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackScreen(),
                  ),
                );
              }),

              const SizedBox(height: 16),
              _linkText(context, 'Terms and conditions', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsScreen(readOnly: true),
                  ),
                );
              }),
              const Spacer(),

              ElevatedButton.icon(
                onPressed: _isLoggingOut ? null : _handleLogout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(_isLoggingOut ? 'Logging out...' : 'Log Out'),
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Fine Aid',
      applicationVersion: '1.0.0',
      applicationLegalese:
          'A multi-platform AI-integrated first aid guide for wounds, '
          'minor injuries, and skin issues assessment.',
    );
  }
}
