import 'package:flutter/material.dart';
import '../../i18n/app_language.dart';
import '../../i18n/classification_strings.dart';

/// A small (i) button shown next to a wound classification. Tapping it opens
/// a short explanation of that classification: what it is, how to tell it is
/// probably minor, and the signs that mean it may be serious (eg how to tell
/// a deep wound from a minor one). Shows nothing when there is no
/// explanation for the given classification.
class ClassificationInfoButton extends StatelessWidget {
  final String? classification;
  final Color? color;

  const ClassificationInfoButton({
    super.key,
    required this.classification,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tagalog = AppLanguageScope.isTagalog(context);
    final info = classificationInfoFor(classification, tagalog: tagalog);
    if (info == null) return const SizedBox.shrink();
    final labels = tagalog
        ? ClassificationInfoLabels.tl
        : ClassificationInfoLabels.en;

    return IconButton(
      icon: Icon(Icons.info_outline, size: 18, color: color),
      tooltip: labels.tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _showSheet(context, info, labels),
    );
  }

  void _showSheet(
    BuildContext context,
    ClassificationInfo info,
    ClassificationInfoLabels labels,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        Widget section(String heading, String body, Color color) {
          if (body.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  classification!.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                section(labels.whatIsIt, info.what, theme.colorScheme.primary),
                section(
                  labels.usuallyMinor,
                  info.minorSigns,
                  Colors.green.shade700,
                ),
                section(
                  labels.seeProfessional,
                  info.seriousSigns,
                  Colors.red.shade700,
                ),
                Text(
                  labels.disclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
