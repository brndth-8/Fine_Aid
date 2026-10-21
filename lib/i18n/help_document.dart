/// Building blocks for the long Help & Support sections (Getting Started,
/// Privacy Issues, How to Use Journal, References), shown inside accordions.
/// The text itself lives in help_content_en.dart / help_content_tl.dart.
library;

/// One piece of a section's body.
sealed class HelpBlock {
  const HelpBlock();
}

/// A sub-heading.
class HelpHeading extends HelpBlock {
  final String text;
  const HelpHeading(this.text);
}

/// A paragraph; [label] (if any) is shown in bold in front of [text].
class HelpParagraph extends HelpBlock {
  final String? label;
  final String text;
  const HelpParagraph(this.text, {this.label});
}

/// A boxed notice (medical disclaimers and similar), shown prominently.
class HelpCallout extends HelpBlock {
  final String text;
  const HelpCallout(this.text);
}

/// A bulleted (or numbered) list.
class HelpList extends HelpBlock {
  final List<HelpItem> items;
  final bool numbered;
  const HelpList(this.items, {this.numbered = false});
}

/// A second-level accordion inside a section.
class HelpGroup extends HelpBlock {
  final String title;
  final List<HelpBlock> blocks;
  const HelpGroup(this.title, this.blocks);
}

/// A list entry: optional bold [label], then [text], then optional nested
/// [children] (one level of sub-bullets).
class HelpItem {
  final String? label;
  final String text;
  final List<HelpItem> children;

  /// Show [label] on its own line above [text] (instead of "Label: text").
  final bool stacked;

  const HelpItem(
    this.text, {
    this.label,
    this.children = const [],
    this.stacked = false,
  });
}

/// One Help topic: the accordion's title and its body.
class HelpSection {
  final String title;
  final List<HelpBlock> blocks;
  const HelpSection({required this.title, required this.blocks});
}
