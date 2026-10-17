import 'package:flutter/material.dart';
import '../../data/journal_evaluation.dart';
import '../../i18n/app_language.dart';
import '../../i18n/evaluation_strings.dart';

/// The Health Journal "Evaluation" card: a template-based summary built from
/// what an entry saved (see buildJournalEvaluation). Shown in a saved entry's
/// Overview and, with the same data, right after the pain result on the AI
/// result screen. Draws nothing when there is no classification to summarize.
class EvaluationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int monitoredDays;

  const EvaluationCard({super.key, required this.data, this.monitoredDays = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagalog = AppLanguageScope.isTagalog(context);
    final text = buildJournalEvaluation(
      data,
      tagalog: tagalog,
      monitoredDays: monitoredDays,
    );
    if (text == null) return const SizedBox.shrink();
    final labels = tagalog ? EvaluationStrings.tl : EvaluationStrings.en;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                labels.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            labels.footnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
