import '../services/api/gemini_service.dart' show WoundCategories;

// Keyed by the same WoundCategories taxonomy the AI Scanner and First Aid
// Assistant both save to a journal entry's `classification` field, so the
// estimate always corresponds to what was actually recognized. Categories
// left out (Other Skin Issue, Unable to Classify) intentionally have no
// duration — callers should show an honest "estimate unavailable" message
// for those instead of guessing.
/// Open wounds and burns: the ones the daily "time to clean your wound"
/// reminder is for (a bruise, swelling or rash is not cleaned that way).
const Set<String> woundCareCategories = {
  WoundCategories.laceration,
  WoundCategories.minorCut,
  WoundCategories.scratch,
  WoundCategories.abrasion,
  WoundCategories.punctureWound,
  WoundCategories.burn,
};

/// The standard-time category (a [WoundCategories] name) for a journal entry's
/// `classification`. The AI scan and the First Aid Kit save those names
/// directly; the manual "Add new entry" categories have their own names, so
/// they are matched here: an Injury is a Laceration when marked Deep and a
/// Minor Cut otherwise, Burns is Burn, Skin Issues is Rash and an Animal
/// Scratch counts as a Scratch. Null when there is no standard time.
String? healingCategoryFor(String? classification, {String? severity}) {
  if (classification == null) return null;
  if (healingDurationDays.containsKey(classification)) return classification;
  if (classification.startsWith('Injury')) {
    return severity == 'Deep'
        ? WoundCategories.laceration
        : WoundCategories.minorCut;
  }
  return switch (classification) {
    'Burns' => WoundCategories.burn,
    'Skin Issues' => WoundCategories.rash,
    'Animal Scratch' => WoundCategories.scratch,
    _ => null,
  };
}

/// Days until the check-in for [classification] (see [healingCategoryFor]),
/// or null when it has no standard healing time.
int? healingDaysFor(String? classification, {String? severity}) {
  final category = healingCategoryFor(classification, severity: severity);
  return category == null ? null : healingDurationDays[category];
}

const Map<String, int> healingDurationDays = {
  WoundCategories.laceration: 10,
  WoundCategories.minorCut: 7,
  WoundCategories.scratch: 5,
  WoundCategories.abrasion: 7,
  WoundCategories.punctureWound: 10,
  WoundCategories.burn: 10,
  WoundCategories.bruise: 10,
  WoundCategories.swelling: 5,
  WoundCategories.rash: 7,
};
