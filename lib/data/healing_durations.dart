import '../services/api/gemini_service.dart' show WoundCategories;

// Keyed by the same WoundCategories taxonomy the AI Scanner and First Aid
// Assistant both save to a journal entry's `classification` field, so the
// estimate always corresponds to what was actually recognized. Categories
// left out (Other Skin Issue, Unable to Classify) intentionally have no
// duration — callers should show an honest "estimate unavailable" message
// for those instead of guessing.
const Map<String, int> healingDurationDays = {
  WoundCategories.laceration: 10,
  WoundCategories.minorCut: 7,
  WoundCategories.scratch: 5,
  WoundCategories.abrasion: 7,
  WoundCategories.punctureWound: 10,
  WoundCategories.burn: 1, //10 originally
  WoundCategories.bruise: 10,
  WoundCategories.swelling: 5,
  WoundCategories.rash: 7,
};
