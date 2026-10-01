import 'package:flutter/material.dart';
import '../../services/api/gemini_service.dart'
    show OtcSuggestion, OtcSuggestionCategory;

/// The "Suggested OTC products" / "Suggested supplies" block shown under a
/// chat answer or a wound assessment — the one shared widget every AI
/// entry point (chat follow-ups, AI Cam results, the assessment result
/// screen) renders OTC suggestions through, so they can never drift apart
/// in structure. Expects [suggestions] to already be filtered (see
/// otc_filter_service.dart), which also sets each suggestion's
/// [OtcSuggestion.category] — this widget just groups by that category
/// into two subsections. Renders nothing when the list is empty, so a
/// caller never needs a separate "should I show this" check.
///
/// Each suggestion starts collapsed to a single compact row (just its
/// generic name) so any number of suggestions still fits the screen —
/// tapping one expands it in place to show age limit, allergy precaution,
/// and how to use. No manufacturer field, ingredients list, price, or
/// long description anywhere. A missing detail is hidden rather than
/// shown as blank/"null".
class OtcSuggestionsBlock extends StatelessWidget {
  final List<OtcSuggestion> suggestions;

  const OtcSuggestionsBlock({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final products = suggestions
        .where((s) => s.category == OtcSuggestionCategory.product)
        .toList();
    final supplies = suggestions
        .where((s) => s.category == OtcSuggestionCategory.supply)
        .toList();

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
          if (products.isNotEmpty)
            _buildGroup(
              theme,
              icon: Icons.medication_outlined,
              title: 'Suggested OTC products',
              items: products,
            ),
          if (supplies.isNotEmpty) ...[
            if (products.isNotEmpty) const SizedBox(height: 10),
            _buildGroup(
              theme,
              icon: Icons.inventory_2_outlined,
              title: 'Suggested supplies',
              items: supplies,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "If symptoms don't improve or get worse, consult a doctor "
            'or pharmacist.',
            style: theme.textTheme.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<OtcSuggestion> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in items) _CollapsibleSuggestion(suggestion: item),
      ],
    );
  }
}

class _CollapsibleSuggestion extends StatefulWidget {
  final OtcSuggestion suggestion;
  const _CollapsibleSuggestion({required this.suggestion});

  @override
  State<_CollapsibleSuggestion> createState() => _CollapsibleSuggestionState();
}

class _CollapsibleSuggestionState extends State<_CollapsibleSuggestion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.suggestion;
    final hasDetails =
        s.ageLimit.isNotEmpty ||
        s.allergyPrecaution.isNotEmpty ||
        s.howToUse.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasDetails
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasDetails)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && hasDetails)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.ageLimit.isNotEmpty) _detail(theme, 'Age', s.ageLimit),
                  if (s.allergyPrecaution.isNotEmpty)
                    _detail(theme, 'Allergy precaution', s.allergyPrecaution),
                  if (s.howToUse.isNotEmpty)
                    _detail(theme, 'How to use', s.howToUse),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detail(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
