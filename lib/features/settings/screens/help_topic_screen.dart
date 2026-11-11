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

    // The page title is in the top bar; the text sits in a bordered box under
    // "How can we help?".
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(section.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.heading,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [HelpBlocksView(blocks: section.blocks)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
