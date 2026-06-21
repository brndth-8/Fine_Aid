import 'package:flutter/material.dart';
import '../../../services/firebase/auth_service.dart';
import 'personalization_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _linkText(context, 'Rate this app', () {}),
              const SizedBox(height: 16),
              _linkText(context, 'Feedback', () {}),
              const SizedBox(height: 16),
              _linkText(context, 'Terms and conditions', () {}),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  await AuthService().signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
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
