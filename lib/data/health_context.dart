import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../i18n/checklist_strings.dart';
import '../services/guest_journal_store.dart';
import '../services/health_profile_service.dart';
import '../services/api/gemini_service.dart' show OtcSuggestion;
import 'health_profile_summary.dart';

// How a person's health conditions change what the app gives them.
//
// 1. The AI is TOLD (healthContextText, added to the scan prompt and to the
//    follow-up chat) so its first aid steps and OTC suggestions can differ
//    for someone with a condition.
// 2. A fixed safety net (filterOtcForHealth) takes out OTC products that are
//    known to conflict, whatever the AI said.
//
// Both are general safety advice, not a diagnosis. The medical rules below
// (which products to remove, the wording sent to the AI) should be reviewed by
// a nursing / medical professional before release.

/// Medicines that raise the risk of bleeding (blood thinners and aspirin).
const List<String> kBloodThinnerMedicines = [
  'warfarin',
  'coumadin',
  'aspirin',
  'clopidogrel',
  'plavix',
  'rivaroxaban',
  'xarelto',
  'apixaban',
  'eliquis',
  'dabigatran',
  'heparin',
  'enoxaparin',
  'cilostazol',
];

/// Pain relievers of the NSAID family (and aspirin), which can make bleeding
/// worse.
const List<String> kNsaidProducts = [
  'aspirin',
  'ibuprofen',
  'naproxen',
  'diclofenac',
  'mefenamic',
  'ketoprofen',
  'celecoxib',
  'nsaid',
];

bool _hasBleedingRisk(Map<String, dynamic>? profile, List<String> medications) {
  if (profile?['hemophiliaOrBloodDisorders'] == true) return true;
  final meds = medications.map((m) => m.toLowerCase()).toList();
  return meds.any((m) => kBloodThinnerMedicines.any(m.contains));
}

bool _hasLatexAllergy(Map<String, dynamic>? profile) =>
    ((profile?['allergyTypes'] as List?) ?? const []).contains('latex');

/// A short English description of the person's reported conditions, allergies
/// and medicines for the AI, or null when there is nothing to tell it.
String? healthContextText(
  Map<String, dynamic>? profile,
  List<String> medications,
) {
  final conditions = profileConditionLabels(profile, ChecklistStrings.en);
  final meds = [
    for (final m in medications)
      if (m.trim().isNotEmpty) m.trim(),
  ];
  if (conditions.isEmpty && meds.isEmpty) return null;
  final buffer = StringBuffer();
  if (conditions.isNotEmpty) {
    buffer.write('Health conditions/allergies: ${conditions.join('; ')}. ');
  }
  if (meds.isNotEmpty) {
    buffer.write('Medicines taken: ${meds.join(', ')}. ');
  }
  return buffer.toString().trim();
}

/// The instruction block added to the AI request when [context] is not null.
String healthContextPromptBlock(String context) =>
    'The person\'s reported health information (self-reported, not verified): '
    '$context Adjust first_aid_steps and otc_options for it: add the extra '
    'precautions these conditions call for (for example slower healing, '
    'higher infection risk, bleeding risk, or skin that is easily irritated), '
    'never suggest an over-the-counter product that conflicts with a listed '
    'condition, allergy or medicine (for example no NSAIDs or aspirin with a '
    'bleeding disorder or a blood thinner), and say to see a doctor sooner '
    'where that applies. Do not diagnose, and do not repeat this paragraph.\n\n';

/// Takes out the OTC suggestions that conflict with what the person said:
/// - a bleeding disorder, or a blood thinner / aspirin among their medicines:
///   no aspirin or other NSAID pain relievers;
/// - a latex allergy: nothing made of latex.
List<OtcSuggestion> filterOtcForHealth(
  List<OtcSuggestion> suggestions, {
  required Map<String, dynamic>? profile,
  required List<String> medications,
}) {
  final bleeding = _hasBleedingRisk(profile, medications);
  final latex = _hasLatexAllergy(profile);
  if (!bleeding && !latex) return suggestions;
  return [
    for (final s in suggestions)
      if (!_conflicts(s, bleeding: bleeding, latex: latex)) s,
  ];
}

bool _conflicts(
  OtcSuggestion s, {
  required bool bleeding,
  required bool latex,
}) {
  final name = s.name.toLowerCase();
  if (bleeding && kNsaidProducts.any(name.contains)) return true;
  if (latex && name.contains('latex') && !name.contains('latex-free')) {
    return !name.contains('latex free');
  }
  return false;
}

// ---------------------------------------------------------------------------
// The chatbot's health context
// ---------------------------------------------------------------------------

/// How many recent journal entries the chatbot is told about.
const int kChatRecentEntries = 3;

/// What the chatbot is told about the person, from what they already saved in
/// the app: the Health Profile's conditions, allergies and medicines, and
/// their latest journal entries ([recentEntries]: one short line each). Null
/// when there is nothing, so the chat then behaves exactly as before. Nothing
/// is made up: every line comes from stored data.
String? chatHealthContext({
  required Map<String, dynamic>? profile,
  required List<String> medications,
  List<String> recentEntries = const [],
}) {
  final profileText = healthContextText(profile, medications);
  final entries = [
    for (final e in recentEntries)
      if (e.trim().isNotEmpty) e.trim(),
  ].take(kChatRecentEntries).toList();
  if (profileText == null && entries.isEmpty) return null;
  final buffer = StringBuffer();
  if (profileText != null) buffer.writeln(profileText);
  if (entries.isNotEmpty) {
    buffer.writeln('Recent journal entries (newest first):');
    for (final e in entries) {
      buffer.writeln('- $e');
    }
  }
  return buffer.toString().trim();
}

/// One journal entry as a short line: "2026-11-08 - Burns - title".
String journalEntryLine(Map<String, dynamic> data) {
  final at = data['createdAt'];
  final date = at is Timestamp
      ? DateFormat('yyyy-MM-dd').format(at.toDate())
      : '';
  final category = (data['classification'] as String?)?.trim() ?? '';
  var title = (data['title'] as String?)?.trim() ?? '';
  if (title.length > 60) title = '${title.substring(0, 60)}...';
  return [date, category, title].where((p) => p.isNotEmpty).join(' - ');
}

/// Loads the chatbot's health context for whoever is using the app: the
/// signed-in person's Health Profile and latest journal entries, or (in Guest
/// Mode) the entries kept on the phone. Null when there is nothing stored or
/// it cannot be read: the chat then works as it always did.
Future<String?> loadChatHealthContext() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await GuestJournalStore.instance.load();
      final lines = [
        for (final e in GuestJournalStore.instance.entries.value)
          journalEntryLine(e.data),
      ];
      return chatHealthContext(
        profile: null,
        medications: const [],
        recentEntries: lines,
      );
    }
    final profile = await HealthProfileService().getHealthProfile();
    var lines = <String>[];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .orderBy('createdAt', descending: true)
          .limit(kChatRecentEntries)
          .get()
          .timeout(const Duration(seconds: 6));
      lines = [for (final d in snap.docs) journalEntryLine(d.data())];
    } catch (_) {
      // No entries available right now: the profile alone is still used.
    }
    return chatHealthContext(
      profile: profile,
      medications: profileMedications(profile),
      recentEntries: lines,
    );
  } catch (_) {
    return null;
  }
}
