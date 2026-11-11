import 'package:flutter/material.dart';
import '../../data/health_profile_summary.dart';
import '../../i18n/app_language.dart';
import '../../i18n/assessment_strings.dart';
import '../../i18n/checklist_strings.dart';
import '../../i18n/pain_strings.dart';
import 'medication_picker.dart';
import 'pain_scale_dialog.dart';

/// What the user answered before an AI result. [pain] / [itch] stay null when
/// they were not asked or the answer was "No".
class AssessmentAnswers {
  final int? pain;
  final int? itch;
  final List<String> medications;

  /// What a guest said about existing health conditions, in the same shape
  /// as the Health Profile (so the same notes can be built from it). Null when
  /// the person was not asked (a signed-in user has the profile instead);
  /// empty when they have none.
  final Map<String, dynamic>? conditions;

  /// A skin issue from an animal bite or scratch: the person is sent to a
  /// doctor before anything else is shown, so no other question was asked.
  final bool animalBite;

  const AssessmentAnswers({
    this.pain,
    this.itch,
    this.medications = const [],
    this.conditions,
    this.animalBite = false,
  });
}

/// Skin issues get the longer set of questions (pain? itchiness? medication);
/// every other result (cuts, scratches, scrapes, punctures, burns, bruises,
/// swelling...) is asked for a pain rating and medication only.
bool isSkinIssueCategory(String category) {
  final c = category.toLowerCase();
  return c == 'rash' || c == 'other skin issue';
}

/// Cuts, scratches and lacerations: the results that are asked whether an
/// animal was involved.
bool isCutScratchLacerationCategory(String category) {
  final c = category.toLowerCase();
  return c == 'laceration' || c == 'minor cut' || c == 'scratch';
}

/// "Was an animal involved?" (Yes / No, in italics). Not dismissible.
Future<bool?> askAnimalInvolved(BuildContext context) => _askYesNo(
  context,
  AssessmentStrings.of(context).animalQuestion,
  italic: true,
);

const Color _maroon = Color(0xFF7A0000);

/// The title of these pop-ups: bold 12.5, black (the design).
TextStyle? _popupTitle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black);

/// Asks the questions before an AI result, one pop-up at a time. None of them
/// can be dismissed or skipped:
///
/// - wounds and minor injuries: pain rating (0-5), then medication;
/// - skin issues: "Do you feel any pain?" (then the rating if yes), "Do you
///   feel any itchiness?" (then the rating if yes), then medication.
///
/// When the Health Profile already lists medications ([savedMedications]) the
/// medication question is NOT asked again: they are used as the answer (the
/// results then say "You are taking ..."). It is only asked when there are
/// none. With [askConditions] (a guest, who has no Health Profile) existing
/// health conditions are asked about first, before the medication question.
/// Returns null if the screen went away part-way.
Future<AssessmentAnswers?> askAssessmentQuestions(
  BuildContext context, {
  required bool skinIssue,
  List<String> savedMedications = const [],
  bool askConditions = false,
}) async {
  final a = AssessmentStrings.of(context);
  final pain = PainStrings.of(context);

  int? painScore;
  int? itchScore;

  if (skinIssue) {
    // First: was an animal or insect involved? An animal bite or scratch goes
    // straight to the doctor advice; an insect bite or sting gets care steps
    // and red flags, then the questions go on as usual.
    final involved = await _askYesNo(context, a.skinAnimalQuestion);
    if (involved == null || !context.mounted) return null;
    if (involved) {
      final kind = await _askAnimalKind(context);
      if (kind == null || !context.mounted) return null;
      if (kind == _AnimalKind.bite) {
        return const AssessmentAnswers(animalBite: true);
      }
      await _showInsectGuidance(context);
      if (!context.mounted) return null;
    }

    final hasPain = await _askYesNo(context, a.painYesNoTitle);
    if (hasPain == null || !context.mounted) return null;
    if (hasPain) {
      painScore = await showPainScaleDialog(context);
      if (painScore == null || !context.mounted) return null;
    }
    final hasItch = await _askYesNo(context, a.itchYesNoTitle);
    if (hasItch == null || !context.mounted) return null;
    if (hasItch) {
      itchScore = await showPainScaleDialog(
        context,
        title: a.itchTitle,
        body: a.itchBody,
        labels: a.itchLabels,
      );
      if (itchScore == null || !context.mounted) return null;
    }
  } else {
    painScore = await showPainScaleDialog(
      context,
      title: pain.dialogTitle,
      body: pain.dialogBody,
    );
    if (painScore == null || !context.mounted) return null;
  }

  Map<String, dynamic>? conditions;
  if (askConditions) {
    conditions = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConditionsDialog(),
    );
    if (conditions == null || !context.mounted) return null;
  }

  final medications = savedMedications.isNotEmpty
      ? savedMedications
      : await showDialog<List<String>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _MedicationDialog(saved: []),
        );
  if (medications == null) return null;

  return AssessmentAnswers(
    pain: painScore,
    itch: itchScore,
    medications: medications,
    conditions: conditions,
  );
}

Future<bool?> _askYesNo(
  BuildContext context,
  String title, {
  bool italic = false,
}) {
  final a = AssessmentStrings.of(context);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: _popupTitle(
            dialogContext,
          )?.copyWith(fontStyle: italic ? FontStyle.italic : null),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(a.no),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(a.yes),
          ),
        ],
      ),
    ),
  );
}

enum _AnimalKind { bite, insect }

/// "What was it?": an animal bite or scratch, or an insect bite or sting.
Future<_AnimalKind?> _askAnimalKind(BuildContext context) {
  final a = AssessmentStrings.of(context);
  return showDialog<_AnimalKind>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(a.animalTypeTitle, style: _popupTitle(dialogContext)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, _AnimalKind.bite),
              child: Text(a.animalTypeBite, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, _AnimalKind.insect),
              child: Text(a.animalTypeInsect, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Care for an insect bite or sting, then the red flags to watch for, with
/// the short "guidance, not a diagnosis" line. One Continue button.
Future<void> _showInsectGuidance(BuildContext context) {
  final a = AssessmentStrings.of(context);
  final theme = Theme.of(context);
  Widget bullets(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\u2022  '),
              Expanded(child: Text(item)),
            ],
          ),
        ),
    ],
  );
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(a.insectCareTitle, style: _popupTitle(dialogContext)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullets(a.insectCareSteps),
              const SizedBox(height: 14),
              Text(
                a.insectRedFlagsTitle,
                style: theme.textTheme.titleSmall?.copyWith(color: _maroon),
              ),
              const SizedBox(height: 4),
              Text(a.insectRedFlagsIntro),
              const SizedBox(height: 4),
              bullets(a.insectRedFlags),
              Text(a.insectRedFlagsOutro),
              const SizedBox(height: 12),
              Text(
                a.guidanceDisclaimer,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8F8584),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(a.continueButton),
          ),
        ],
      ),
    ),
  );
}

/// "Do you have any existing health conditions?" (guests). Yes shows the
/// conditions of the Health Profile to tick, plus an "Other" line; Continue
/// needs at least one when it is Yes. Returns the answer in the Health
/// Profile's shape (empty for No).
class _ConditionsDialog extends StatefulWidget {
  const _ConditionsDialog();

  @override
  State<_ConditionsDialog> createState() => _ConditionsDialogState();
}

class _ConditionsDialogState extends State<_ConditionsDialog> {
  bool? _has;
  bool _diabetes = false;
  bool _blood = false;
  bool _allergies = false;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Widget _choice(bool value, String label) {
    final chosen = _has == value;
    void choose() => setState(() => _has = chosen ? null : value);
    return chosen
        ? ElevatedButton(
            onPressed: choose,
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            child: Text(label),
          )
        : OutlinedButton(onPressed: choose, child: Text(label));
  }

  Widget _tile(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _maroon,
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v ?? false)),
    );
  }

  bool get _anyChosen =>
      _diabetes || _blood || _allergies || _other.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = AssessmentStrings.of(context);
    final c = AppLanguageScope.isTagalog(context)
        ? ChecklistStrings.tl
        : ChecklistStrings.en;
    final canContinue = _has == false || (_has == true && _anyChosen);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(a.conditionsQuestionTitle, style: _popupTitle(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.conditionsQuestionBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _choice(false, a.no)),
                  const SizedBox(width: 12),
                  Expanded(child: _choice(true, a.yes)),
                ],
              ),
              if (_has == true) ...[
                const SizedBox(height: 8),
                _tile(c.diabetes, _diabetes, (v) => _diabetes = v),
                _tile(c.hemophilia, _blood, (v) => _blood = v),
                _tile(c.severeAllergies, _allergies, (v) => _allergies = v),
                const SizedBox(height: 4),
                TextField(
                  controller: _other,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: c.otherCondition,
                    hintText: c.otherConditionHint,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
            ),
            onPressed: canContinue
                ? () => Navigator.pop(context, <String, dynamic>{
                    if (_has == true) ...{
                      if (_diabetes) 'diabetes': true,
                      if (_blood) 'hemophiliaOrBloodDisorders': true,
                      if (_allergies) 'severeAllergies': true,
                      if (_other.text.trim().isNotEmpty)
                        'otherCondition': _other.text.trim(),
                    },
                  })
                : null,
            child: Text(a.continueButton),
          ),
        ],
      ),
    );
  }
}

/// "Do you take any medication?" Yes shows the medication picker (starting
/// with the Health Profile's list); Continue needs at least one when it is Yes.
class _MedicationDialog extends StatefulWidget {
  final List<String> saved;
  const _MedicationDialog({required this.saved});

  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  late bool? _takes = widget.saved.isEmpty ? null : true;
  late List<String> _medications = List.of(widget.saved);

  Widget _choice(bool value, String label) {
    final chosen = _takes == value;
    void choose() => setState(() => _takes = chosen ? null : value);
    return chosen
        ? ElevatedButton(
            onPressed: choose,
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            child: Text(label),
          )
        : OutlinedButton(onPressed: choose, child: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = AssessmentStrings.of(context);
    final canContinue =
        _takes == false || (_takes == true && _medications.isNotEmpty);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(a.medicationQuestionTitle, style: _popupTitle(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.medicationQuestionBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              // No and Yes are two separate pills (the chosen one filled).
              Row(
                children: [
                  Expanded(child: _choice(false, a.no)),
                  const SizedBox(width: 12),
                  Expanded(child: _choice(true, a.yes)),
                ],
              ),
              if (_takes == true) ...[
                const SizedBox(height: 12),
                MedicationPicker(
                  selected: _medications,
                  onChanged: (list) => setState(() => _medications = list),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
            ),
            onPressed: canContinue
                ? () => Navigator.pop(
                    context,
                    _takes == true ? _medications : <String>[],
                  )
                : null,
            child: Text(a.continueButton),
          ),
        ],
      ),
    );
  }
}

/// The "You indicated that…" lines to show before the result: the
/// conditions saved in the Health Profile and the medication just entered.
/// Empty when there is nothing to acknowledge.
List<String> acknowledgementLines(
  BuildContext context, {
  required Map<String, dynamic>? profile,
  required List<String> medications,
}) {
  final tagalog = AppLanguageScope.isTagalog(context);
  final a = tagalog ? AssessmentStrings.tl : AssessmentStrings.en;
  final c = tagalog ? ChecklistStrings.tl : ChecklistStrings.en;
  final conditions = profileConditionLabels(profile, c);
  return [
    if (conditions.isNotEmpty)
      a.ackHave.replaceFirst('{list}', joinWithAnd(conditions, a.listAnd)),
    if (medications.isNotEmpty)
      a.ackTake.replaceFirst('{list}', joinWithAnd(medications, a.listAnd)),
  ];
}

/// Shows [lines] in a short pop-up with one Continue button.
Future<void> showAcknowledgement(BuildContext context, List<String> lines) {
  final a = AssessmentStrings.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFF0F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(a.ackTitle, style: _popupTitle(dialogContext)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(a.continueButton),
          ),
        ],
      ),
    ),
  );
}
