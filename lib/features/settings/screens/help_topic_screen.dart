import 'package:flutter/material.dart';
import '../../../core/widgets/help_accordion.dart';
import '../../../i18n/help_document.dart';
import '../../../i18n/help_strings.dart';

enum HelpTopic { gettingStarted, privacy, journal, references }

/// One Help & Support page (Getting Started, Privacy Issues, How to Use
/// Journal?, References), opened from the Help screen. References shows its
/// sources and the clinical-governance section as nested accordions.
class HelpTopicScreen extends StatelessWidget {
  final HelpTopic topic;

  const HelpTopicScreen({super.key, required this.topic});

  static HelpSection sectionOf(HelpStrings s, HelpTopic topic) =>
      switch (topic) {
        HelpTopic.gettingStarted => s.gettingStarted,
        HelpTopic.privacy => s.privacy,
        HelpTopic.journal => s.journal,
        HelpTopic.references => s.references,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = HelpStrings.of(context);
    final section = sectionOf(s, topic);

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
                          section.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        HelpBlocksView(blocks: section.blocks),
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
}
