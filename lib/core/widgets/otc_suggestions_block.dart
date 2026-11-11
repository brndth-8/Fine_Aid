import 'package:flutter/material.dart';
import '../../i18n/chat_strings.dart';
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

  /// The AI result screen's look (a pink card with white rows, maroon
  /// headings); the chat keeps the original look.
  final bool cardStyle;

  const OtcSuggestionsBlock({
    super.key,
    required this.suggestions,
    this.cardStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = ChatStrings.of(context);

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
        color: cardStyle
            ? const Color(0xFFFFF0F0)
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(cardStyle ? 14 : 10),
        border: cardStyle
            ? null
            : Border.all(
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
              title: text.suggestedProducts,
              items: products,
              cardStyle: cardStyle,
            ),
          if (supplies.isNotEmpty) ...[
            if (products.isNotEmpty) const SizedBox(height: 10),
            _buildGroup(
              theme,
              icon: Icons.inventory_2_outlined,
              title: text.suggestedSupplies,
              items: supplies,
              cardStyle: cardStyle,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            text.seeDoctorNote,
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
    bool cardStyle = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: cardStyle ? 16 : 14,
              color: cardStyle
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: cardStyle ? 11.5 : null,
                color: cardStyle
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in items)
          _CollapsibleSuggestion(suggestion: item, cardStyle: cardStyle),
      ],
    );
  }
}

class _CollapsibleSuggestion extends StatefulWidget {
  final OtcSuggestion suggestion;
  final bool cardStyle;
  const _CollapsibleSuggestion({
    required this.suggestion,
    this.cardStyle = false,
  });

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
        color: widget.cardStyle
            ? Colors.white
            : theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(widget.cardStyle ? 14 : 8),
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
                  if (s.ageLimit.isNotEmpty)
                    _detail(
                      theme,
                      ChatStrings.of(context).detailAge,
                      s.ageLimit,
                    ),
                  if (s.allergyPrecaution.isNotEmpty)
                    _detail(
                      theme,
                      ChatStrings.of(context).detailAllergy,
                      s.allergyPrecaution,
                    ),
                  if (s.howToUse.isNotEmpty)
                    _detail(
                      theme,
                      ChatStrings.of(context).detailHowToUse,
                      s.howToUse,
                    ),
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
