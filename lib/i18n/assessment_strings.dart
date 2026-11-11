import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the questions asked before an AI result (pain / itchiness /
/// medication), the medication picker, and the short "you indicated…" summary
/// shown before the result, English + Tagalog. The itch labels reuse the same
/// wording as the pain scale. Review the Tagalog before release.
class AssessmentStrings {
  final String medicationsTitle;
  final String medicationHint;
  final String medicationAdd; // uses {name}
  final String medicationRemove;

  final String animalQuestion;
  final String skinAnimalQuestion;
  final String animalTypeTitle;
  final String animalTypeBite;
  final String animalTypeInsect;
  final String animalBiteAdvice;
  final String insectCareTitle;
  final List<String> insectCareSteps;
  final String insectRedFlagsTitle;
  final String insectRedFlagsIntro;
  final List<String> insectRedFlags;
  final String insectRedFlagsOutro;
  final String guidanceDisclaimer;
  final String animalCannotHelp;
  final String painYesNoTitle;
  final String itchYesNoTitle;
  final String yes;
  final String no;
  final String itchTitle;
  final String itchBody;
  final List<String> itchLabels; // index = rating 0-5
  final String medicationQuestionTitle;
  final String medicationQuestionBody;
  // Guests (no Health Profile) are asked about existing conditions.
  final String conditionsQuestionTitle;
  final String conditionsQuestionBody;
  final String continueButton;

  final String ackTitle;
  final String ackHave; // uses {list}
  final String ackTake; // uses {list}
  final String listAnd; // "A, B and C"

  // The blue "Based on Your Health Profile" box on a result.
  final String profileBoxTitle;
  final String profileConditionsLine; // uses {list}

  const AssessmentStrings({
    required this.medicationsTitle,
    required this.medicationHint,
    required this.medicationAdd,
    required this.medicationRemove,
    required this.animalQuestion,
    required this.skinAnimalQuestion,
    required this.animalTypeTitle,
    required this.animalTypeBite,
    required this.animalTypeInsect,
    required this.animalBiteAdvice,
    required this.insectCareTitle,
    required this.insectCareSteps,
    required this.insectRedFlagsTitle,
    required this.insectRedFlagsIntro,
    required this.insectRedFlags,
    required this.insectRedFlagsOutro,
    required this.guidanceDisclaimer,
    required this.animalCannotHelp,
    required this.painYesNoTitle,
    required this.itchYesNoTitle,
    required this.yes,
    required this.no,
    required this.itchTitle,
    required this.itchBody,
    required this.itchLabels,
    required this.medicationQuestionTitle,
    required this.medicationQuestionBody,
    required this.conditionsQuestionTitle,
    required this.conditionsQuestionBody,
    required this.continueButton,
    required this.ackTitle,
    required this.ackHave,
    required this.ackTake,
    required this.listAnd,
    required this.profileBoxTitle,
    required this.profileConditionsLine,
  });

  static AssessmentStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String addFormat(String name) => medicationAdd.replaceFirst('{name}', name);

  static const en = AssessmentStrings(
    medicationsTitle: 'Medications you are taking',
    medicationHint: 'Type a medication name',
    medicationAdd: 'Add "{name}"',
    medicationRemove: 'Remove',
    animalQuestion:
        'Was an animal involved? (For example: a bite, scratch, or laceration.)',
    skinAnimalQuestion:
        'Was an animal or insect involved? (For example: an insect bite or '
        'sting, or an animal bite or scratch.)',
    animalTypeTitle: 'What was it?',
    animalTypeBite: 'Animal bite or scratch (dog, cat, or other mammal)',
    animalTypeInsect: 'Insect bite or sting',
    animalBiteAdvice:
        'Please seek immediate medical consultation. An animal bite or '
        'scratch can lead to infection, tetanus or rabies.',
    insectCareTitle: 'Care for an insect bite or sting',
    insectCareSteps: [
      'Clean the area with soap and water.',
      'Apply a cold compress.',
      'Avoid scratching the area.',
      'Over-the-counter relief may help. Ask a pharmacist which one is '
          'suitable for you.',
    ],
    insectRedFlagsTitle: 'Red Flags',
    insectRedFlagsIntro: 'Watch for signs of an allergic reaction:',
    insectRedFlags: [
      'Swelling of the face or lips',
      'Difficulty breathing',
      'Widespread hives',
      'Dizziness',
    ],
    insectRedFlagsOutro:
        'Also watch for fever. If any of these happen, seek medical '
        'attention.',
    guidanceDisclaimer: 'This is guidance, not a medical diagnosis.',
    animalCannotHelp:
        'I cannot specifically address the issue you are pertaining to. '
        'Seek medical help if needed.',
    painYesNoTitle: 'Do you feel any pain?',
    itchYesNoTitle: 'Do you feel any itchiness?',
    yes: 'Yes',
    no: 'No',
    itchTitle: 'How itchy is it?',
    itchBody: 'Rate the itch from 0 to 5, where 0 is no itch and 5 is severe.',
    itchLabels: [
      'No itch',
      'Very mild',
      'Minor',
      'Moderate',
      'Severe',
      'Worst itch',
    ],
    medicationQuestionTitle: 'Do you take any medication?',
    medicationQuestionBody:
        'If yes, type the medication you take or choose it from the list.',
    conditionsQuestionTitle: 'Do you have any existing health conditions?',
    conditionsQuestionBody: 'If yes, choose all that apply.',
    continueButton: 'Continue',
    ackTitle: 'Before we continue',
    ackHave: 'You indicated that you have {list}.',
    ackTake: 'You are taking {list}.',
    listAnd: 'and',
    profileBoxTitle: 'Based on Your Health Profile',
    profileConditionsLine: 'Health conditions noted: {list}.',
  );

  static const tl = AssessmentStrings(
    medicationsTitle: 'Mga gamot na iyong iniinom o ginagamit',
    medicationHint: 'I-type ang pangalan ng gamot',
    medicationAdd: 'Idagdag ang "{name}"',
    medicationRemove: 'Alisin',
    animalQuestion:
        'May hayop bang kasangkot? (Halimbawa: kagat, kalmot, o hiwa.)',
    skinAnimalQuestion:
        'May hayop o insekto bang kasangkot? (Halimbawa: kagat o kirot ng '
        'insekto, o kagat o kalmot ng hayop.)',
    animalTypeTitle: 'Ano ito?',
    animalTypeBite: 'Kagat o kalmot ng hayop (aso, pusa, o iba pang mammal)',
    animalTypeInsect: 'Kagat o kirot ng insekto',
    animalBiteAdvice:
        'Magpakonsulta agad sa doktor. Ang kagat o kalmot ng hayop ay maaaring '
        'magdulot ng impeksyon, tetano o rabies.',
    insectCareTitle: 'Pangangalaga sa kagat o kirot ng insekto',
    insectCareSteps: [
      'Hugasan ang lugar gamit ang sabon at tubig.',
      'Maglagay ng malamig na compress.',
      'Iwasang kamutin ang lugar.',
      'Maaaring makatulong ang over-the-counter na gamot. Magtanong sa '
          'parmasyutiko kung alin ang angkop para sa iyo.',
    ],
    insectRedFlagsTitle: 'Mga Babalang Palatandaan',
    insectRedFlagsIntro: 'Bantayan ang mga palatandaan ng allergic reaction:',
    insectRedFlags: [
      'Pamamaga ng mukha o labi',
      'Hirap sa paghinga',
      'Malawakang pantal (hives)',
      'Pagkahilo',
    ],
    insectRedFlagsOutro:
        'Bantayan din ang lagnat. Kung mangyari ang alinman dito, humingi ng '
        'medikal na tulong.',
    guidanceDisclaimer: 'Ito ay gabay lamang at hindi medikal na diyagnosis.',
    animalCannotHelp:
        'Hindi ko matutugunan nang tiyak ang isyung tinutukoy mo. '
        'Humingi ng medikal na tulong kung kinakailangan.',
    painYesNoTitle: 'May nararamdaman ka bang sakit?',
    itchYesNoTitle: 'May nararamdaman ka bang pangangati?',
    yes: 'Oo',
    no: 'Hindi',
    itchTitle: 'Gaano kakati?',
    itchBody:
        'I-rate ang pangangati mula 0 hanggang 5, kung saan ang 0 ay walang '
        'kati at ang 5 ay matindi.',
    itchLabels: [
      'Walang kati',
      'Napakaliit',
      'Maliit',
      'Katamtaman',
      'Matindi',
      'Pinakamatindi',
    ],
    medicationQuestionTitle: 'Umiinom ka ba ng anumang gamot?',
    medicationQuestionBody:
        'Kung oo, i-type ang gamot na iniinom mo o piliin ito sa listahan.',
    conditionsQuestionTitle:
        'Mayroon ka bang kasalukuyang kondisyon sa kalusugan?',
    conditionsQuestionBody: 'Kung oo, piliin ang lahat ng naaangkop.',
    continueButton: 'Magpatuloy',
    ackTitle: 'Bago tayo magpatuloy',
    ackHave: 'Sinabi mong mayroon kang {list}.',
    ackTake: 'Umiinom ka ng {list}.',
    listAnd: 'at',
    profileBoxTitle: 'Batay sa Iyong Health Profile',
    profileConditionsLine: 'Mga kondisyong nabanggit: {list}.',
  );
}
