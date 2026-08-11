import 'package:flutter/material.dart';

enum HelpTopic { gettingStarted, privacy, journal, references }

class HelpTopicScreen extends StatelessWidget {
  final HelpTopic topic;

  const HelpTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _contentFor(topic);

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
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final paragraph in content.paragraphs) ...[
                          Text(paragraph, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                        ],
                        if (content.cards.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: content.cards
                                .map(
                                  (c) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _infoCard(theme, c),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Center(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, _InfoCard card) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(card.icon, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            card.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _HelpContent _contentFor(HelpTopic topic) {
    switch (topic) {
      case HelpTopic.gettingStarted:
        return _HelpContent(
          title: 'Getting Started',
          paragraphs: const [
            'Fine Aid helps you assess minor wounds and skin issues using AI, '
                'keep a recovery journal, and access trusted first aid references — '
                'all in one place.',
            'Start by exploring the Dashboard: browse the First Aid Textbook Guide, '
                'use the AI Vision Camera to scan an injury, or open your Health '
                'Journal to log how you\'re feeling.',
            'Create an account to save your journal entries, personalize your '
                'profile, and get healing reminders. Guest mode lets you explore '
                'without saving any data.',
          ],
          cards: const [],
        );
      case HelpTopic.privacy:
        return _HelpContent(
          title: 'Privacy Issues',
          paragraphs: const [
            'Your personal information, including your username and contact '
                'details, is stored securely and is never shared without your '
                'explicit consent.',
            'Images attached to your Health Journal entries may be made viewable '
                'to the admin module for review purposes, to help improve the '
                'accuracy and safety of guidance provided.',
            'In Guest Mode, none of your entries or images are saved — they '
                'exist only temporarily during your session.',
          ],
          cards: const [],
        );
      case HelpTopic.journal:
        return _HelpContent(
          title: 'How to use Journal?',
          paragraphs: const [
            'The Health Journal helps you track wounds and skin issues over '
                'time. Tap "Add Entry" to create a new log: add a photo, give it '
                'a title, describe how you\'re feeling, and classify the issue '
                '(Injury, Burns, Skin Issues, or Animal Bite/Scratch).',
            'Turn on "Remind Me" to get a notification once you\'ve reached the '
                'standard healing time for that classification — Fine Aid will '
                'check in and ask if you\'re feeling better.',
            'Tap any entry to view its full details, ask for more help, or '
                'export your log to share with a healthcare provider.',
          ],
          cards: const [],
        );
      case HelpTopic.references:
        return _HelpContent(
          title: 'References',
          paragraphs: const [
            'Sources include: WHO, American Red Cross, MIMS, recognized local '
                'organizations. Every piece of information is cross-referenced.',
            'All clinical guidelines and advice are meticulously reviewed and '
                'credited by a panel of board-certified specialists.',
          ],
          cards: [
            _InfoCard(
              icon: Icons.menu_book_outlined,
              label: 'Verified Medical Sources',
            ),
            _InfoCard(
              icon: Icons.medical_services_outlined,
              label: 'Doctor-Reviewed Content',
            ),
          ],
        );
    }
  }
}

class _HelpContent {
  final String title;
  final List<String> paragraphs;
  final List<_InfoCard> cards;

  _HelpContent({
    required this.title,
    required this.paragraphs,
    required this.cards,
  });
}

class _InfoCard {
  final IconData icon;
  final String label;

  _InfoCard({required this.icon, required this.label});
}
