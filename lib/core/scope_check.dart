// Shared scope rule for every AI text entry point (Describe your concern,
// AI Cam follow-ups, First Aid Kit follow-ups, the standalone chatbot) —
// Fine Aid only answers questions about wounds, minor injuries, and skin
// conditions. Defined once here so the exact refusal wording, and the
// lightweight local pre-check, can never drift between screens or from
// what gemini_service.dart's shared system prompt instructs the AI to
// say — the system prompt is the real safeguard; this is just a fast,
// free, offline-capable shortcut for the obvious cases.

/// The exact required refusal reply for an out-of-scope question. Used
/// both as the client-side canned reply when [looksObviouslyOutOfScope]
/// catches something locally, and quoted verbatim in the shared system
/// prompt so the AI's own refusal matches word-for-word.
const String outOfScopeRefusalMessage =
    "I'm sorry, I only provide preliminary assessments, guidance, and "
    'care for wounds, minor injuries, and skin issues. We recommend '
    'seeking professional consultation.';

// Broad on purpose — anything even loosely wound/skin-related here means
// "let the AI decide" rather than risk a false-positive local refusal on
// a genuine borderline case (eg "my cut has a fever").
const List<String> _woundContextKeywords = [
  'wound',
  'cut',
  'cuts',
  'scrape',
  'scraped',
  'laceration',
  'abrasion',
  'puncture',
  'burn',
  'burned',
  'burnt',
  'scald',
  'bite',
  'bitten',
  'sting',
  'stung',
  'bruise',
  'bruised',
  'rash',
  'itch',
  'itchy',
  'skin',
  'blister',
  'swelling',
  'swollen',
  'swell',
  'bleed',
  'bleeding',
  'sprain',
  'sprained',
  'infect',
  'pus',
  'gash',
  'injury',
  'injured',
  'stitches',
  'bandage',
  'dressing',
  'scab',
  'scar',
  'acne',
  'fungal',
  'fungus',
  'eczema',
  'hive',
  'hives',
  'boil',
  'sugat',
  'paso',
  'hiwa',
  'gasgas',
  'pasa',
  'pantal',
];

// Common topics the app is explicitly not for — only checked when the
// message has none of the wound-context words above.
const List<String> _outOfScopeKeywords = [
  'cough',
  'cold',
  'flu',
  'fever',
  'diabetes',
  'diabetic',
  'hypertension',
  'blood pressure',
  'asthma',
  'stomach',
  'digestive',
  'indigestion',
  'nausea',
  'vomit',
  'diarrhea',
  'constipation',
  'headache',
  'migraine',
  'mental health',
  'depression',
  'anxiety',
  'chest pain',
  'kidney',
  'liver disease',
  'cancer',
  'covid',
  'toothache',
  'dental',
  'sore throat',
  'menstrual',
  'period cramps',
  'urinary',
  'ubo',
  'sipon',
  'lagnat',
];

/// Lightweight local pre-check so an obviously out-of-scope message (eg
/// "I have a cough") can be refused instantly, without an API call and
/// without needing a network connection — NOT the definitive judge.
/// Returns false (let the AI decide) whenever the message has any
/// wound/skin context at all, so a genuine borderline case is never
/// wrongly refused client-side; the shared system prompt in
/// gemini_service.dart is what actually enforces scope for anything this
/// doesn't catch.
bool looksObviouslyOutOfScope(String message) {
  final lower = message.toLowerCase();
  final hasWoundContext = _woundContextKeywords.any(lower.contains);
  if (hasWoundContext) return false;
  return _outOfScopeKeywords.any(lower.contains);
}

/// True when [reply] is the out-of-scope refusal — whether it came back
/// from the AI itself or was substituted client-side. Callers use this to
/// skip counting the exchange against a guest's daily usage limit, since
/// a refusal never actually used the AI to help with anything.
bool isRefusalReply(String reply) => reply.trim() == outOfScopeRefusalMessage;
