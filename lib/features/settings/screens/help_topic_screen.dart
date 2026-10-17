import 'package:flutter/material.dart';
import '../../../i18n/help_strings.dart';
import 'reference_detail_screen.dart';

enum HelpTopic { gettingStarted, privacy, journal, references }

class HelpTopicScreen extends StatelessWidget {
  final HelpTopic topic;

  const HelpTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _contentFor(context, topic);

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
              Text(
                HelpStrings.of(context).heading,
                style: theme.textTheme.headlineSmall,
              ),
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
    final onTap = card.onTap;
    final content = Container(
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
          // Tap cue for a card that opens a page.
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.primary,
              size: 20,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }

  _HelpContent _contentFor(BuildContext context, HelpTopic topic) {
    final strings = HelpStrings.of(context);
    switch (topic) {
      case HelpTopic.gettingStarted:
        return _fromText(strings.gettingStarted, const []);
      case HelpTopic.privacy:
        return _fromText(strings.privacy, const []);
      case HelpTopic.journal:
        return _fromText(strings.journal, const []);
      case HelpTopic.references:
        // Each reference card opens its own (for now empty) page, titled
        // with the card's name.
        return _fromText(
          strings.references,
          const [Icons.menu_book_outlined, Icons.medical_services_outlined],
          onTap: (label) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReferenceDetailScreen(title: label),
            ),
          ),
        );
    }
  }

  // Pairs each translated card label with its (language-independent) icon.
  _HelpContent _fromText(
    HelpTopicText text,
    List<IconData> icons, {
    void Function(String label)? onTap,
  }) {
    return _HelpContent(
      title: text.title,
      paragraphs: text.paragraphs,
      cards: [
        for (var i = 0; i < text.cardLabels.length; i++)
          _InfoCard(
            icon: icons[i],
            label: text.cardLabels[i],
            onTap: onTap == null ? null : () => onTap(text.cardLabels[i]),
          ),
      ],
    );
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
  final VoidCallback? onTap;

  _InfoCard({required this.icon, required this.label, this.onTap});
}
