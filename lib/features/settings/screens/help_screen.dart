import 'package:flutter/material.dart';
import '../../../core/widgets/help_tour_launcher.dart';
import '../../../i18n/help_strings.dart';
import 'help_topic_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _topics = [
    (HelpTopic.gettingStarted, 'assets/images/help_getting_started.png'),
    (HelpTopic.privacy, 'assets/images/help_privacy.png'),
    (HelpTopic.journal, 'assets/images/help_journal.png'),
    (HelpTopic.references, 'assets/images/help_references.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = HelpStrings.of(context);

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
                ],
              ),
              const SizedBox(height: 8),
              Text(s.heading, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        color: theme.colorScheme.primary,
                        padding: const EdgeInsets.all(24),
                        child: Image.asset(
                          'assets/images/help_hero.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (topic, icon) in _topics) ...[
                      _PageTile(
                        title: HelpTopicScreen.sectionOf(s, topic).title,
                        icon: icon,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HelpTopicScreen(topic: topic),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        HelpTourLauncher.instance.requestTour();
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(s.replayTour),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered row (icon, title, arrow) that opens a Help page.
class _PageTile extends StatelessWidget {
  final String title;
  final String icon;
  final VoidCallback onTap;

  const _PageTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Image.asset(icon, height: 32, width: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
