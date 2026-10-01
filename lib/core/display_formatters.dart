// Shared display-label formatting for raw code-like values (enum names,
// free-form Gemini strings) so every screen that shows a triage level or
// wound type renders the same human-readable text — never editing each
// screen's own copy of this logic separately.

import '../services/api/gemini_service.dart' show TriageLevel;

/// Converts a camelCase or snake_case/kebab-case code string into Title
/// Case words — eg "someNewValue" -> "Some New Value",
/// "puncture_wound" -> "Puncture Wound". Used as the fallback for any
/// value that isn't one of the explicitly named cases below, so a new or
/// unrecognized value never shows raw code to the user, and as the whole
/// implementation for wound-type labels (which have no fixed enum).
String titleCaseFromCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  // Split camelCase boundaries (aB -> a B) and normalize snake/kebab-case
  // separators to spaces before title-casing each word.
  final withSpaces = trimmed
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_\-]+'), ' ');

  final words = withSpaces.trim().split(RegExp(r'\s+'));
  return words
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Human-readable label for a [TriageLevel] — eg urgentCare -> "Urgent
/// Care". Falls back to [titleCaseFromCode] for any value not explicitly
/// listed, so adding a new enum value later never regresses to raw code.
String triageDisplayLabel(TriageLevel triage) {
  switch (triage) {
    case TriageLevel.selfCare:
      return 'Self Care';
    case TriageLevel.firstAid:
      return 'First Aid';
    case TriageLevel.urgentCare:
      return 'Urgent Care';
    case TriageLevel.emergency:
      return 'Emergency';
    case TriageLevel.unknown:
      return titleCaseFromCode(triage.name);
  }
}

/// Human-readable label for a raw `wound_type` string (eg "burn",
/// "puncture_wound") — capitalizes single words and Title Cases
/// multi-word camelCase/snake_case values the same way.
String woundTypeDisplayLabel(String woundType) => titleCaseFromCode(woundType);

extension TriageLevelDisplay on TriageLevel {
  /// Convenience accessor for [triageDisplayLabel] — `triage.displayName`.
  String get displayName => triageDisplayLabel(this);
}
