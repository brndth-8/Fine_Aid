import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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

    // "Label: value" lines, with the label in bold.
    Widget lines() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty)
            Builder(
              builder: (context) {
                final colon = line.indexOf(':');
                final base = theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                );
                if (colon < 1 || colon > 32) return Text(line, style: base);
                return Text.rich(
                  TextSpan(
                    style: base,
                    children: [
                      TextSpan(
                        text: line.substring(0, colon + 1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: line.substring(colon + 1)),
                    ],
                  ),
                );
              },
            ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDCEBFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3F6DB3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    size: 20,
                    color: Color(0xFF3F6DB3),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    labels.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              lines(),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(labels.footnote, style: AppTheme.noteStyle()),
      ],
    );
  }
}
