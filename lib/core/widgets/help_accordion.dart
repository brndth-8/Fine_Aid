import 'package:flutter/material.dart';
import '../../i18n/help_document.dart';

/// A tappable section that opens and closes: a title row with a chevron that
/// turns, and a body that slides open. The parent owns [expanded], so it can
/// keep several accordions to one-open-at-a-time.
class HelpAccordion extends StatelessWidget {
  final String title;
  final Widget? leading;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  /// A smaller, lighter look for an accordion inside another one.
  final bool nested;

  const HelpAccordion({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.leading,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(nested ? 12 : 16);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: title,
            excludeSemantics: true,
            onTap: onToggle,
            child: InkWell(
              borderRadius: radius,
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: nested ? 12 : 16,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style:
                            (nested
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Draws a Help section's blocks (headings, paragraphs, notices, lists) and
/// turns each [HelpGroup] into a nested accordion, one open at a time.
class HelpBlocksView extends StatefulWidget {
  final List<HelpBlock> blocks;

  const HelpBlocksView({super.key, required this.blocks});

  @override
  State<HelpBlocksView> createState() => _HelpBlocksViewState();
}

class _HelpBlocksViewState extends State<HelpBlocksView> {
  int? _openGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var groupIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in widget.blocks)
          switch (block) {
            HelpHeading() => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                block.text,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            HelpParagraph() => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _labelled(theme, block.label, block.text),
            ),
            HelpCallout() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  block.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            HelpList() => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _list(theme, block.items, numbered: block.numbered),
            ),
            HelpGroup() => _group(block, groupIndex++),
          },
      ],
    );
  }

  Widget _group(HelpGroup group, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HelpAccordion(
        title: group.title,
        nested: true,
        expanded: _openGroup == index,
        onToggle: () =>
            setState(() => _openGroup = _openGroup == index ? null : index),
        child: HelpBlocksView(blocks: group.blocks),
      ),
    );
  }

  Widget _labelled(ThemeData theme, String? label, String text) {
    final base = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (label != null)
            TextSpan(
              text: text.isEmpty ? label : '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          TextSpan(text: text),
        ],
      ),
    );
  }

  Widget _list(
    ThemeData theme,
    List<HelpItem> items, {
    required bool numbered,
    bool child = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 6, left: child ? 16 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: numbered && !child ? 24 : 18,
                  child: Text(
                    numbered && !child ? '${i + 1}.' : (child ? '–' : '•'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items[i].stacked && items[i].label != null) ...[
                        Text(
                          items[i].label!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _labelled(theme, null, items[i].text),
                      ] else
                        _labelled(theme, items[i].label, items[i].text),
                      if (items[i].children.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _list(
                          theme,
                          items[i].children,
                          numbered: false,
                          child: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
