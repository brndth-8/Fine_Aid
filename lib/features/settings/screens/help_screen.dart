import 'package:flutter/material.dart';
import 'help_topic_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
                ],
              ),
              const SizedBox(height: 8),
              Text('How can we help?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
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
              Row(
                children: [
                  Expanded(
                    child: _helpTile(
                      context,
                      theme,
                      imagePath: 'assets/images/help_getting_started.png',
                      label: 'Getting Started',
                      topic: HelpTopic.gettingStarted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _helpTile(
                      context,
                      theme,
                      imagePath: 'assets/images/help_privacy.png',
                      label: 'Privacy Issues',
                      topic: HelpTopic.privacy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _helpTile(
                      context,
                      theme,
                      imagePath: 'assets/images/help_journal.png',
                      label: 'How to use Journal?',
                      topic: HelpTopic.journal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _helpTile(
                      context,
                      theme,
                      imagePath: 'assets/images/help_references.png',
                      label: 'References',
                      topic: HelpTopic.references,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpTile(
    BuildContext context,
    ThemeData theme, {
    required String imagePath,
    required String label,
    required HelpTopic topic,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HelpTopicScreen(topic: topic),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imagePath, height: 40, width: 40),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
