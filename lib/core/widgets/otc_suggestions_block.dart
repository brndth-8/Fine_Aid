import 'package:flutter/material.dart';

/// The "Suggested OTC options" block shown under a chat answer, shared by
/// every follow-up Q&A surface (AI Camera, First Aid Kit, the standalone
/// chatbot). Expects [suggestions] to already be filtered (see
/// otc_filter.dart) — renders nothing when the list is empty, so a caller
/// never needs a separate "should I show this" check.
class OtcSuggestionsBlock extends StatelessWidget {
  final List<String> suggestions;

  const OtcSuggestionsBlock({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication_outlined,
                size: 14,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggested OTC options',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $s', style: theme.textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This is general information, not a substitute for '
            'professional medical advice.',
            style: theme.textTheme.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
