import '../i18n/evaluation_strings.dart';
import '../i18n/pain_strings.dart';
import 'pain_assessment.dart';

List<String> _strings(dynamic value) =>
    (value as List?)
        ?.map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList() ??
    const [];

final RegExp _phasePrefix = RegExp(r'^(Before|During|After):\s*');

/// Saved steps look like "During: step — why". For the one-line advice
/// summary only the action itself is quoted (no phase label, no "why"), and
/// the "During" steps are preferred since they are the care itself. Older
/// entries without that shape pass through unchanged.
List<String> _adviceActions(List<String> steps) {
  final during = steps.where((s) => s.startsWith('During:')).toList();
  return (during.isNotEmpty ? during : steps).map((s) {
    final action = s.replaceFirst(_phasePrefix, '');
    final cut = action.indexOf(' — ');
    return cut > 0 ? action.substring(0, cut) : action;
  }).toList();
}

String _stripTrailingPeriod(String s) =>
    s.endsWith('.') ? s.substring(0, s.length - 1) : s;

/// Builds the Health Journal "Evaluation" for one saved entry from fixed
/// templates (English or Tagalog). It only states what the entry's saved
/// data supports — classification, the AI's bleeding/depth/warning-sign
/// observations, the pain score, the care level and advice given, the
/// healing-milestone answer, and days monitored — and leaves a sentence out
/// when its data isn't there (so older entries still produce a shorter,
/// accurate summary). Returns null when the entry has no classification.
String? buildJournalEvaluation(
  Map<String, dynamic> data, {
  required bool tagalog,
  int monitoredDays = 0,
}) {
  final s = tagalog ? EvaluationStrings.tl : EvaluationStrings.en;
  final p = tagalog ? PainStrings.tl : PainStrings.en;

  final classification = (data['classification'] as String?)?.trim();
  if (classification == null || classification.isEmpty) return null;

  final sentences = <String>[
    s.recordedFormat.replaceFirst('{c}', classification),
  ];

  // Injury sub-type (Deep / Minor) chosen when the entry was added.
  final subType = !classification.startsWith('Injury')
      ? null
      : switch (data['severity']) {
          'Deep' => s.subTypeDeep,
          'Minor' => s.subTypeMinor,
          _ => null,
        };
  if (subType != null) {
    sentences.add(s.subTypeFormat.replaceFirst('{type}', subType));
  }

  // What the AI observed.
  final observed = <String>[
    ?switch (data['visibleBleeding']) {
      'none' => s.bleedingNone,
      'mild' => s.bleedingMild,
      'moderate' => s.bleedingModerate,
      'severe' => s.bleedingSevere,
      _ => null,
    },
    ?switch (data['apparentDepth']) {
      'superficial' => s.depthSuperficial,
      'partial_thickness' => s.depthPartial,
      'deep' => s.depthDeep,
      _ => null,
    },
  ];
  if (observed.isNotEmpty) {
    sentences.add(
      s.assessmentNotedFormat.replaceFirst('{parts}', observed.join('; ')),
    );
  }

  // Warning signs: only claim "none" when the entry actually carries the
  // field (an entry from the AI camera or the First Aid Assistant).
  final warnings = _strings(data['warningSigns'] ?? data['redFlags']);
  final hasWarningField =
      data.containsKey('warningSigns') || data.containsKey('redFlags');
  if (warnings.isNotEmpty) {
    sentences.add(
      s.warningSignsFormat.replaceFirst(
        '{list}',
        warnings.take(3).map(_stripTrailingPeriod).join('; '),
      ),
    );
  } else if (hasWarningField) {
    sentences.add(s.noWarningSigns);
  }

  // Pain score.
  // New entries rate pain 0-5 and say so (`painScaleMax`); entries saved
  // before that were rated 1-10 and have no such field.
  final rawPain = data['painScore'];
  final pain = rawPain is num ? rawPain.toInt() : null;
  final legacyScale = data['painScaleMax'] is! num;
  final validPain = pain == null
      ? null
      : (legacyScale
            ? (pain >= 1 && pain <= kLegacyPainMax ? pain : null)
            : (isValidPainScore(pain) ? pain : null));
  if (validPain != null) {
    final levelName = legacyScale
        ? p.levelName(legacyPainLevelFor(validPain))
        : p.rating(validPain).label;
    sentences.add(
      s.painFormat
          .replaceFirst('{n}', '$validPain')
          .replaceFirst('{max}', '${legacyScale ? kLegacyPainMax : kPainMax}')
          .replaceFirst('{level}', levelName),
    );
  }

  // Care level + whether a professional was recommended.
  final triage = data['triage'];
  final careLevel = switch (triage) {
    'selfCare' => s.careSelfCare,
    'firstAid' => s.careFirstAid,
    'urgentCare' => s.careUrgent,
    'emergency' => s.careEmergency,
    _ => null,
  };
  if (careLevel != null) {
    sentences.add(s.careLevelFormat.replaceFirst('{level}', careLevel));
  }
  final consult =
      data['needsProfessionalEvaluation'] == true ||
      triage == 'urgentCare' ||
      triage == 'emergency' ||
      data['hasRedFlag'] == true ||
      (validPain != null && validPain >= (legacyScale ? 7 : 4));
  if (consult) sentences.add(s.consultRecommended);

  // Advice given (the first few first-aid steps saved with the entry).
  final steps = _strings(data['firstAidSteps']);
  if (steps.isNotEmpty) {
    sentences.add(
      s.adviceFormat.replaceFirst(
        '{steps}',
        _adviceActions(steps).take(3).map(_stripTrailingPeriod).join('; '),
      ),
    );
  }

  // The user's answer at the healing milestone.
  if (data['milestoneResponded'] == true) {
    sentences.add(
      data['feelingBetter'] == true ? s.milestoneBetter : s.milestoneNotBetter,
    );
  }

  if (monitoredDays > 0) {
    sentences.add(
      monitoredDays == 1
          ? s.monitoredOne
          : s.monitoredManyFormat.replaceFirst('{n}', '$monitoredDays'),
    );
  }

  return sentences.join(' ');
}
