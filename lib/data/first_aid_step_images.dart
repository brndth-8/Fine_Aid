/// Which image (if any) goes with a First Aid step.
///
/// The steps are written by the AI each time, so their number and order
/// change. Images are therefore named by the KIND of step, not by its
/// position: one file per kind, in [kFirstAidImageDir], named
/// `<kind>.png` (see [firstAidStepImageKeys]). A step whose kind has no
/// matching file simply shows no image.
library;

/// Folder the images go in.
const String kFirstAidImageDir = 'assets/images/first_aid/';

/// File extension of the images.
const String kFirstAidImageExtension = 'png';

/// Every step kind that can have an image, in the order they are checked.
/// The first kind whose keywords appear in the step wins, so the more
/// specific kinds come first.
const List<String> firstAidStepImageKeys = [
  // Named after their files, so these keep the file's exact spelling
  // (including "are" in the wash one).
  'prepare_clean_warm_water_and_a_soft_towel_1',
  'wash_the_affected_are_and_remove_surface_debris_1',
  'protect_the_face_from_direct_sunlight_1',
  'consult_a_doctor_if_not_better_1',
  'consult_a_doctor_for_formal_evaluation_1',
  'Apply_mild_fragrance_free_moisturizer_1',
  'call_emergency',
  'avoid_harsh_product',
  'avoid_touching',
  'change_dressing',
  'wash_hands',
  'cool_burn',
  'gather_gauze_or_cloth_1',
  'rinse_water',
  'pat_dry',
  'apply_pressure',
  'apply_ointment',
  'apply_antiseptic',
  'cold_compress',
  'apply_dressing',
  'elevate',
  'rest',
  'watch_infection',
  'keep_track_of_changes_1',
  'monitor_the_area',
  // Added last: they only picture steps no kind above matches.
  'air_dry_do_not_rub_1',
  'check_what_you_see_1',
  'keep_area_dry_1',
  'cool_damp_cloth_1',
  'sterile_gauze_cover_1',
  'gauze_or_clean_towel_1',
  'warning_signs_to_watch_1',
  'blisters_seek_care_1',
];

/// Kinds that only apply to a step that STARTS with a "don't" ("Do not pour
/// alcohol…", "Avoid touching…"), so a step that merely mentions alcohol
/// while telling you to do something else keeps its own picture.
const Set<String> _warningKeys = {'avoid_harsh_product', 'avoid_touching'};

// Keywords (lower case) that mark each kind, checked against the action part
// of the step.
const Map<String, List<String>> _keywords = {
  'prepare_clean_warm_water_and_a_soft_towel_1': [
    'prepare clean warm water',
    'warm water and a soft towel',
    'soft towel',
  ],
  'wash_the_affected_are_and_remove_surface_debris_1': [
    'wash the affected area',
    'remove surface debris',
  ],
  'protect_the_face_from_direct_sunlight_1': [
    'protect the face',
    'direct sunlight',
  ],
  'consult_a_doctor_for_formal_evaluation_1': [
    'consult a doctor',
    'formal evaluation',
  ],
  'Apply_mild_fragrance_free_moisturizer_1': ['moisturizer', 'moisturiser'],
  // "Consult a doctor ... if the rash does not get better in a few days".
  'consult_a_doctor_if_not_better_1': [
    'does not get better',
    'keeps coming back',
  ],
  // "Get clean running water, clean gauze (or a clean cloth ...)".
  'gather_gauze_or_cloth_1': ['gauze (or', 'gauze or a clean'],
  // "Keep track of when the rash started ...".
  'keep_track_of_changes_1': ['keep track', 'track of when'],
  // "After washing, let the skin air-dry. Do not rub it ...".
  'air_dry_do_not_rub_1': ['air-dry', 'air dry', 'let the skin dry'],
  'check_what_you_see_1': ['what you see', 'inspect', 'examine'],
  'keep_area_dry_1': [
    'keep the area dry',
    'keep it dry',
    'avoid getting the area wet',
  ],
  'cool_damp_cloth_1': [
    'cool, damp',
    'cool damp',
    'cool wet',
    'cool cloth',
    'cool compress',
  ],
  'sterile_gauze_cover_1': ['sterile gauze', 'gauze pad', 'non-stick gauze'],
  'gauze_or_clean_towel_1': ['gauze or', 'cloth or gauze', 'towel or gauze'],
  'warning_signs_to_watch_1': [
    'fever',
    'swelling',
    'spreading',
    'getting worse',
    'worsen',
  ],
  'blisters_seek_care_1': ['blister'],
  'call_emergency': [
    'emergency',
    'call 911',
    'ambulance',
    'nearest hospital',
    'go to the nearest',
    'medical help right away',
  ],
  'avoid_harsh_product': [
    'alcohol',
    'peroxide',
    'toothpaste',
    'butter',
    'oil',
    'petroleum',
    'harsh',
    'chemical',
  ],
  'avoid_touching': [
    'touch',
    'scratch',
    'pick',
    'pop',
    'squeeze',
    'rub',
    'push on',
    'press on',
  ],
  'change_dressing': [
    'change the dressing',
    'change dressing',
    'change the bandage',
    'replace the dressing',
    'replace the bandage',
  ],
  'wash_hands': [
    'wash your hands',
    'wash hands',
    'clean hands',
    'clean your hands',
    'hand hygiene',
    'sanitize your hands',
    'disposable gloves',
  ],
  'cool_burn': ['cool the burn', 'cool running water', 'cool the area'],
  'rinse_water': [
    'rinse',
    'running water',
    'flush',
    'irrigate',
    'wash the wound',
    'wash the area',
    'wash the scratch',
    'wash the cut',
  ],
  'pat_dry': ['pat the', 'pat dry', 'pat it dry', 'gently dry', 'dry the area'],
  'apply_pressure': ['pressure'],
  'apply_ointment': ['ointment', 'cream', 'thin layer'],
  'apply_antiseptic': ['antiseptic', 'povidone', 'disinfect', 'antibiotic'],
  'cold_compress': ['cold compress', 'cold pack', 'ice pack', 'apply ice'],
  'apply_dressing': ['dressing', 'bandage', 'cover the', 'cover with'],
  'elevate': ['elevate', 'raise the'],
  'rest': ['rest the', 'rest and', 'keep still'],
  'watch_infection': ['signs of infection', 'infection'],
  'monitor_the_area': [
    'monitor',
    'watch for',
    'keep an eye',
    'check the area',
    'check it',
    'keep track',
    'track',
  ],
};

final RegExp _phasePrefix = RegExp(r'^(Before|During|After):\s*');

/// The action part of a step: without a leading "Before:/During:/After:" and
/// without a trailing " — why". Only this is matched, so the reason text
/// ("Washes out dirt…") can't pick the wrong image.
String stepActionText(String step) {
  final action = step.replaceFirst(_phasePrefix, '');
  final cut = action.indexOf(' — ');
  return (cut > 0 ? action.substring(0, cut) : action).toLowerCase();
}

final RegExp _negation = RegExp(r"^(do not|don't|dont|never|avoid|stop)\b");

/// The kind of [step] (a value from [firstAidStepImageKeys]), or null when it
/// matches none.
String? firstAidStepImageKey(String step) {
  final text = stepActionText(step);
  final startsWithNegation = _negation.hasMatch(text);
  for (final key in firstAidStepImageKeys) {
    if (_warningKeys.contains(key) && !startsWithNegation) continue;
    for (final word in _keywords[key]!) {
      if (text.contains(word)) return key;
    }
  }
  return null;
}

/// Where the image for [key] lives, eg `assets/images/first_aid/wash_hands.png`.
String firstAidStepImagePath(String key) =>
    '$kFirstAidImageDir$key.$kFirstAidImageExtension';
