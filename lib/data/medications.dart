/// Medicines a user can pick from when they say which medication they take
/// (Health Profile and the questions before an AI result). Generic names only,
/// the way the rest of the app names medicines. The list is only a search
/// aid: a name that is not here can still be added exactly as typed. Added
/// for the app, not medical advice; a pharmacist or doctor should review it.
const List<String> kCommonMedications = [
  // Pain and fever
  'Paracetamol',
  'Ibuprofen',
  'Mefenamic acid',
  'Naproxen',
  'Diclofenac',
  'Aspirin',
  // Allergy and itch
  'Cetirizine',
  'Loratadine',
  'Diphenhydramine',
  'Chlorphenamine',
  'Hydrocortisone cream',
  // Blood thinners and clotting (these change how bleeding should be handled)
  'Warfarin',
  'Clopidogrel',
  'Rivaroxaban',
  'Apixaban',
  'Dabigatran',
  'Heparin',
  'Factor VIII (clotting factor)',
  'Tranexamic acid',
  // Diabetes
  'Insulin',
  'Metformin',
  'Gliclazide',
  'Glimepiride',
  // Heart and blood pressure
  'Amlodipine',
  'Losartan',
  'Lisinopril',
  'Atenolol',
  'Metoprolol',
  'Simvastatin',
  'Atorvastatin',
  // Steroids, asthma, stomach, thyroid
  'Prednisone',
  'Salbutamol',
  'Omeprazole',
  'Levothyroxine',
  // Antibiotics
  'Amoxicillin',
  'Cefalexin',
  'Azithromycin',
  'Ciprofloxacin',
  'Co-amoxiclav',
];

/// The medications whose name matches [query] (not case sensitive), names
/// that start with it first, then names that contain it. Anything in
/// [exclude] (already chosen) is left out. An empty query matches nothing.
List<String> searchMedications(
  String query, {
  Iterable<String> exclude = const [],
  int limit = 6,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final skip = exclude.map((e) => e.toLowerCase()).toSet();
  final starts = <String>[];
  final contains = <String>[];
  for (final name in kCommonMedications) {
    final lower = name.toLowerCase();
    if (skip.contains(lower)) continue;
    if (lower.startsWith(q)) {
      starts.add(name);
    } else if (lower.contains(q)) {
      contains.add(name);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// Whether [query] is exactly one of the known names (ignoring case), so the
/// picker does not offer to "add" a name it already lists.
bool isKnownMedication(String query) {
  final q = query.trim().toLowerCase();
  return kCommonMedications.any((m) => m.toLowerCase() == q);
}
