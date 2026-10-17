import '../services/api/gemini_service.dart' show TriageLevel;

/// The pain scale: 0 = no pain ... 5 = worst pain. (Entries saved before
/// this scale used 1-10; they carry no `painScaleMax`, see [kLegacyPainMax].)
const int kPainMin = 0;
const int kPainMax = 5;

/// Entries saved before the 0-5 scale rated pain 1-10 and have no
/// `painScaleMax` field; they keep showing "X/10".
const int kLegacyPainMax = 10;

bool isValidPainScore(int? score) =>
    score != null && score >= kPainMin && score <= kPainMax;

/// How the user's 0-5 pain rating is grouped.
enum PainLevel {
  mild, // 0-1: standard guide, normal self-care tips
  moderate, // 2-3: more careful care and monitoring tips
  severe, // 4: detailed guidance + "seek professional consultation"
  worst, // 5: "We advise you to seek medical consultation."
}

PainLevel painLevelFor(int score) {
  if (score <= 1) return PainLevel.mild;
  if (score <= 3) return PainLevel.moderate;
  if (score == 4) return PainLevel.severe;
  return PainLevel.worst;
}

/// The grouping used by the old 1-10 scale, kept so older saved entries are
/// still described correctly.
PainLevel legacyPainLevelFor(int score) {
  if (score <= 3) return PainLevel.mild;
  if (score <= 6) return PainLevel.moderate;
  if (score <= 9) return PainLevel.severe;
  return PainLevel.worst;
}

/// How strongly the result screen tells the user to seek care. Ordered from
/// least to most serious, so the higher one always wins when the AI's result
/// and the user's pain score are combined.
enum ReminderLevel { none, professional, urgent, emergency }

/// The reminder implied by the AI assessment alone (the app's existing rule:
/// emergency / urgent-care triage, or "needs professional evaluation").
ReminderLevel reminderFromAssessment(
  TriageLevel triage,
  bool needsProfessionalEvaluation,
) {
  if (triage == TriageLevel.emergency) return ReminderLevel.emergency;
  if (triage == TriageLevel.urgentCare) return ReminderLevel.urgent;
  if (needsProfessionalEvaluation) return ReminderLevel.professional;
  return ReminderLevel.none;
}

/// The reminder implied by the pain rating alone: 4 -> seek professional
/// consultation, 5 -> urgent medical care, lower -> nothing extra.
ReminderLevel reminderFromPain(int? score) {
  if (!isValidPainScore(score)) return ReminderLevel.none;
  switch (painLevelFor(score!)) {
    case PainLevel.mild:
    case PainLevel.moderate:
      return ReminderLevel.none;
    case PainLevel.severe:
      return ReminderLevel.professional;
    case PainLevel.worst:
      return ReminderLevel.urgent;
  }
}

/// The more serious of the two: a minor-looking wound with pain 5 still
/// gets urgent care, and a high-pain score never lowers an AI emergency.
ReminderLevel combinedReminder(
  TriageLevel triage,
  bool needsProfessionalEvaluation,
  int? painScore,
) {
  final fromAi = reminderFromAssessment(triage, needsProfessionalEvaluation);
  final fromPain = reminderFromPain(painScore);
  return fromAi.index >= fromPain.index ? fromAi : fromPain;
}
