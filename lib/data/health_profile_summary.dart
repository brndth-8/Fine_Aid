import '../i18n/checklist_strings.dart';

/// The conditions the user saved in their Health Profile, as readable names
/// in the given language (eg "Type 1 Diabetes", "Hemophilia A"), for the
/// "You indicated that you have …" summary shown before an AI result. Empty
/// when there is no profile or nothing was ticked.
List<String> profileConditionLabels(
  Map<String, dynamic>? profile,
  ChecklistStrings s,
) {
  if (profile == null) return const [];
  final labels = <String>[];

  if (profile['diabetes'] == true) {
    labels.add(switch (profile['diabetesType']) {
      'type1' => '${s.diabetesType1} ${s.diabetes}',
      'type2' => '${s.diabetesType2} ${s.diabetes}',
      'gestational' => '${s.diabetesGestational} ${s.diabetes}',
      'prediabetes' => s.diabetesPrediabetes,
      _ => s.diabetes,
    });
  }

  if (profile['hemophiliaOrBloodDisorders'] == true) {
    labels.add(switch (profile['bloodDisorderType']) {
      'hemophiliaA' => s.hemophiliaA,
      'other' => s.bloodDisorderOther,
      _ => s.hemophilia,
    });
  }

  final allergyTypes =
      (profile['allergyTypes'] as List?)?.map((e) => '$e').toList() ??
      const <String>[];
  for (final id in allergyTypes) {
    labels.add(switch (id) {
      'rhinitis' => s.allergyRhinitis,
      'food' => s.allergyFood,
      'skin' => s.allergySkin,
      'insect' => s.allergyInsect,
      'drug' => s.allergyDrug,
      'latex' => s.allergyLatex,
      _ => id,
    });
  }
  // Older profiles only have the flag, with no list of types.
  if (allergyTypes.isEmpty && profile['severeAllergies'] == true) {
    labels.add(s.severeAllergies);
  }

  final other = (profile['otherCondition'] as String?)?.trim();
  if (other != null && other.isNotEmpty) labels.add(other);

  return labels;
}

/// The medications saved in the Health Profile (empty when none).
List<String> profileMedications(Map<String, dynamic>? profile) {
  final raw = profile?['medications'];
  if (raw is! List) return const [];
  return [
    for (final m in raw)
      if ('$m'.trim().isNotEmpty) '$m'.trim(),
  ];
}

/// "A", "A and B", "A, B and C".
String joinWithAnd(List<String> items, String andWord) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} $andWord '
      '${items.last}';
}
