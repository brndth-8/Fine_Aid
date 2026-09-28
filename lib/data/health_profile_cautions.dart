// Turns the user's saved Health Profile into short, relevant cautions
// surfaced alongside first aid steps and OTC suggestions. This is a
// lightweight, additive nudge rather than a true medical-safety filter —
// the app has no per-product condition tagging to reliably hide specific
// OTC options, so instead it flags what's worth double-checking given the
// conditions the user reported.
List<String> healthProfileCautions(Map<String, dynamic>? healthProfile) {
  if (healthProfile == null) return const [];
  final cautions = <String>[];

  if (healthProfile['diabetes'] == true) {
    cautions.add(
      "You've noted diabetes - wounds can heal more slowly and infection "
      'risk is higher, so watch this one closely and see a doctor sooner '
      'if healing seems slow or signs of infection appear.',
    );
  }
  if (healthProfile['hemophiliaOrBloodDisorders'] == true) {
    cautions.add(
      "You've noted a bleeding or blood clotting condition — apply firm, "
      'sustained pressure to any bleeding, and seek medical care promptly '
      "if it doesn't stop quickly.",
    );
  }
  if (healthProfile['severeAllergies'] == true) {
    cautions.add(
      "You've noted severe allergies — check ingredient labels before "
      'using any over-the-counter product, and ask a pharmacist first if '
      "you're unsure.",
    );
  }

  return cautions;
}
