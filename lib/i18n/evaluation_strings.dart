/// Sentence templates for the Health Journal's auto-generated "Evaluation"
/// (the Evaluation step of ADPIE), English + Tagalog. The text is built from
/// fixed templates filled with values the entry already saved — never free
/// AI writing — so the output is predictable and states only what the saved
/// data supports.
///
/// IMPORTANT: wording should be reviewed by a nursing/medical professional
/// before release.
library;

class EvaluationStrings {
  final String title;
  final String footnote;

  final String recordedFormat; // {c}
  final String subTypeFormat; // {type}
  final String subTypeDeep;
  final String subTypeMinor;
  final String assessmentNotedFormat; // {parts}
  final String bleedingNone;
  final String bleedingMild;
  final String bleedingModerate;
  final String bleedingSevere;
  final String depthSuperficial;
  final String depthPartial;
  final String depthDeep;
  final String warningSignsFormat; // {list}
  final String noWarningSigns;
  final String painFormat; // {n} {max} {level}
  final String careLevelFormat; // {level}
  final String careSelfCare;
  final String careFirstAid;
  final String careUrgent;
  final String careEmergency;
  final String consultRecommended;
  final String adviceFormat; // {steps}
  final String milestoneBetter;
  final String milestoneNotBetter;
  final String monitoredOne;
  final String monitoredManyFormat; // {n}

  const EvaluationStrings({
    required this.title,
    required this.footnote,
    required this.recordedFormat,
    required this.subTypeFormat,
    required this.subTypeDeep,
    required this.subTypeMinor,
    required this.assessmentNotedFormat,
    required this.bleedingNone,
    required this.bleedingMild,
    required this.bleedingModerate,
    required this.bleedingSevere,
    required this.depthSuperficial,
    required this.depthPartial,
    required this.depthDeep,
    required this.warningSignsFormat,
    required this.noWarningSigns,
    required this.painFormat,
    required this.careLevelFormat,
    required this.careSelfCare,
    required this.careFirstAid,
    required this.careUrgent,
    required this.careEmergency,
    required this.consultRecommended,
    required this.adviceFormat,
    required this.milestoneBetter,
    required this.milestoneNotBetter,
    required this.monitoredOne,
    required this.monitoredManyFormat,
  });

  static const en = EvaluationStrings(
    title: 'Evaluation',
    footnote:
        'Automatically summarized from what was saved in this entry. It is '
        'not a medical diagnosis.',
    recordedFormat: '{c} recorded in this entry.',
    subTypeFormat: 'Injury type: {type}.',
    subTypeDeep: 'Deep',
    subTypeMinor: 'Minor',
    assessmentNotedFormat: 'Assessment noted: {parts}.',
    bleedingNone: 'no visible bleeding',
    bleedingMild: 'mild bleeding',
    bleedingModerate: 'moderate bleeding',
    bleedingSevere: 'severe bleeding',
    depthSuperficial: 'the wound appears superficial',
    depthPartial: 'the wound appears partial-thickness',
    depthDeep: 'the wound appears deep',
    warningSignsFormat: 'Warning signs noted: {list}.',
    noWarningSigns: 'No warning signs were flagged.',
    painFormat: 'Reported pain score: {n}/{max} ({level}).',
    careLevelFormat: 'Assessed care level: {level}.',
    careSelfCare: 'Self Care',
    careFirstAid: 'First Aid',
    careUrgent: 'Urgent Care',
    careEmergency: 'Emergency',
    consultRecommended: 'Professional consultation was recommended.',
    adviceFormat: 'Advice given: {steps}.',
    milestoneBetter:
        'At the expected healing time, you reported feeling better.',
    milestoneNotBetter:
        'At the expected healing time, you reported not feeling better; '
        'professional consultation is recommended.',
    monitoredOne: 'Monitored for 1 day.',
    monitoredManyFormat: 'Monitored for {n} days.',
  );

  static const tl = EvaluationStrings(
    title: 'Ebalwasyon',
    footnote:
        'Awtomatikong buod mula sa mga na-save sa entry na ito. Hindi ito '
        'isang medikal na diagnosis.',
    recordedFormat: 'Naitala sa entry na ito ang {c}.',
    subTypeFormat: 'Uri ng pinsala: {type}.',
    subTypeDeep: 'Malalim',
    subTypeMinor: 'Maliit',
    assessmentNotedFormat: 'Napansin sa pagsusuri: {parts}.',
    bleedingNone: 'walang nakikitang pagdurugo',
    bleedingMild: 'bahagyang pagdurugo',
    bleedingModerate: 'katamtamang pagdurugo',
    bleedingSevere: 'matinding pagdurugo',
    depthSuperficial: 'mukhang mababaw ang sugat',
    depthPartial: 'mukhang partial-thickness ang sugat',
    depthDeep: 'mukhang malalim ang sugat',
    warningSignsFormat: 'Mga babalang palatandaan: {list}.',
    noWarningSigns: 'Walang babalang palatandaan na naitala.',
    painFormat: 'Iniulat na antas ng sakit: {n}/{max} ({level}).',
    careLevelFormat: 'Antas ng pangangalaga ayon sa pagsusuri: {level}.',
    careSelfCare: 'Pangangalaga sa Sarili',
    careFirstAid: 'First Aid',
    careUrgent: 'Agarang Pangangalaga',
    careEmergency: 'Emerhensiya',
    consultRecommended: 'Inirekomenda ang pagkonsulta sa propesyonal.',
    adviceFormat: 'Mga payong ibinigay: {steps}.',
    milestoneBetter:
        'Sa inaasahang oras ng paggaling, iniulat mong bumubuti na ang '
        'pakiramdam mo.',
    milestoneNotBetter:
        'Sa inaasahang oras ng paggaling, iniulat mong hindi pa bumubuti '
        'ang pakiramdam mo; inirerekomenda ang pagkonsulta sa propesyonal.',
    monitoredOne: 'Binantayan sa loob ng 1 araw.',
    monitoredManyFormat: 'Binantayan sa loob ng {n} araw.',
  );
}
