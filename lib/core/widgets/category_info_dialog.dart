import 'package:flutter/material.dart';
import '../../i18n/journal_entry_strings.dart';

/// One choice inside [showCategoryInfoDialog] (eg Deep / Minor).
class CategoryOption {
  /// What gets saved (eg "Deep").
  final String value;
  final String title;
  final String description;

  const CategoryOption({
    required this.value,
    required this.title,
    required this.description,
  });
}

/// What the user confirmed. [option] is the chosen [CategoryOption.value], or
/// null when the pop-up had no options.
class CategoryDialogResult {
  final String? option;
  const CategoryDialogResult(this.option);
}

/// The one pop-up used for every Health Journal category: the category name,
/// a short description, and a Confirm button. With [options] (eg the Injury
/// type Deep / Minor) the user must also pick one before Confirm turns on.
///
/// Returns null if the pop-up is closed any other way (Cancel, tapping
/// outside, back) — in which case nothing is selected.
Future<CategoryDialogResult?> showCategoryInfoDialog(
  BuildContext context, {
  required String title,
  required String description,
  List<CategoryOption> options = const [],
}) {
  return showDialog<CategoryDialogResult>(
    context: context,
    builder: (_) => _CategoryInfoDialog(
      title: title,
      description: description,
      options: options,
    ),
  );
}

class _CategoryInfoDialog extends StatefulWidget {
  final String title;
  final String description;
  final List<CategoryOption> options;

  const _CategoryInfoDialog({
    required this.title,
    required this.description,
    required this.options,
  });

  @override
  State<_CategoryInfoDialog> createState() => _CategoryInfoDialogState();
}

class _CategoryInfoDialogState extends State<_CategoryInfoDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = JournalEntryStrings.of(context);
    final needsChoice = widget.options.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description, style: theme.textTheme.bodyMedium),
            for (final option in widget.options) ...[
              const SizedBox(height: 12),
              _optionCard(theme, option),
            ],
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: needsChoice && _selected == null
              ? null
              : () => Navigator.pop(context, CategoryDialogResult(_selected)),
          child: Text(s.confirm),
        ),
      ],
    );
  }

  Widget _optionCard(ThemeData theme, CategoryOption option) {
    final selected = _selected == option.value;
    final color = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = option.value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade400,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(option.description, style: theme.textTheme.bodySmall),
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
