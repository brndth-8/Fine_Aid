import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Health Profile (health checklist) screen text, English + Tagalog.
/// English is the original wording, unchanged. Review the Tagalog (medical
/// condition names especially) before release.
class ChecklistStrings {
  final String title;
  final String intro;
  final String diabetes;
  final String hemophilia;
  final String severeAllergies;
  // The allergy group and its six types (Health Profile).
  final String commonAllergies;
  final String allergyRhinitis;
  final String allergyFood;
  final String allergySkin;
  final String allergyInsect;
  final String allergyDrug;
  final String allergyLatex;
  final String noneOfTheAbove;
  // Short plain-language explanation shown under each checklist item.
  final String diabetesInfo;
  final String hemophiliaInfo;
  final String severeAllergiesInfo;
  final String noneInfo;
  final String privacyTitle;
  final String privacy;
  final String continueButton;
  final String saveChanges;
  final String saveError;
  // Diabetes type (single choice, shown once Diabetes is checked) with a
  // short plain-language description each. MEDICAL REVIEW NEEDED.
  final String diabetesTypeTitle;
  final String diabetesType1;
  final String diabetesType1Info;
  final String diabetesType2;
  final String diabetesType2Info;
  final String diabetesGestational;
  final String diabetesGestationalInfo;
  final String diabetesPrediabetes;
  final String diabetesPrediabetesInfo;
  // Shown every time a condition is checked.
  final String disclaimer;
  final String disclaimerOk;
  // Examples under Food Allergies.
  final String foodAllergyExamples;
  final String sectionConditions;
  final String bloodDisorderTypeTitle;
  final String hemophiliaA;
  final String hemophiliaAInfo;
  final String bloodDisorderOther;
  final String bloodDisorderOtherInfo;
  final String otherCondition;
  final String otherConditionInfo;
  final String otherConditionHint;
  final String specifyCondition;
  final String specifyConditionHint;
  final String medicationsInfo;

  const ChecklistStrings({
    required this.title,
    required this.intro,
    required this.diabetes,
    required this.hemophilia,
    required this.severeAllergies,
    required this.commonAllergies,
    required this.allergyRhinitis,
    required this.allergyFood,
    required this.allergySkin,
    required this.allergyInsect,
    required this.allergyDrug,
    required this.allergyLatex,
    required this.noneOfTheAbove,
    required this.diabetesInfo,
    required this.hemophiliaInfo,
    required this.severeAllergiesInfo,
    required this.noneInfo,
    required this.privacyTitle,
    required this.privacy,
    required this.continueButton,
    required this.saveChanges,
    required this.saveError,
    required this.diabetesTypeTitle,
    required this.diabetesType1,
    required this.diabetesType1Info,
    required this.diabetesType2,
    required this.diabetesType2Info,
    required this.diabetesGestational,
    required this.diabetesGestationalInfo,
    required this.diabetesPrediabetes,
    required this.diabetesPrediabetesInfo,
    required this.disclaimer,
    required this.disclaimerOk,
    required this.foodAllergyExamples,
    required this.sectionConditions,
    required this.bloodDisorderTypeTitle,
    required this.hemophiliaA,
    required this.hemophiliaAInfo,
    required this.bloodDisorderOther,
    required this.bloodDisorderOtherInfo,
    required this.otherCondition,
    required this.otherConditionInfo,
    required this.otherConditionHint,
    required this.specifyCondition,
    required this.specifyConditionHint,
    required this.medicationsInfo,
  });

  static ChecklistStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = ChecklistStrings(
    title: 'Health Profile',
    intro:
        'To provide effective medical assistance, we need to understand your '
        'health profile. Certain conditions can significantly affect how your body '
        'responds to injuries and the specific clinical protocols required for '
        'immediate care.',
    diabetes: 'Diabetes',
    hemophilia: 'Hemophilia or Blood Disorders',
    severeAllergies: 'Severe Allergies',
    commonAllergies: 'Common Allergies',
    allergyRhinitis: 'Allergic rhinitis / Hay Fever',
    allergyFood: 'Food Allergies',
    allergySkin: 'Skin Allergies',
    allergyInsect: 'Insect Sting & Bite Allergies',
    allergyDrug: 'Drug & Medication Allergies',
    allergyLatex: 'Latex Allergies',
    noneOfTheAbove:
        "I don't have any of the listed conditions (Provide Standard Clinical Protocols)",
    diabetesInfo:
        'A condition where the body has trouble controlling blood sugar. '
        'Wounds may heal more slowly and are more likely to get infected.',
    hemophiliaInfo:
        'Conditions where the blood does not clot normally, so bleeding may '
        'last longer or be harder to stop.',
    severeAllergiesInfo:
        'A strong reaction of your body to a substance such as food, '
        'medicine, or insect bites, which may cause itching, rash, or '
        'swelling.',
    noneInfo: 'Choose this if none of the conditions above apply to you.',
    privacyTitle: 'Privacy & Data Use:',
    privacy:
        'In accordance with the Data Privacy Act, your personal information is '
        'stored securely only on your device and is not shared with anyone without '
        'your explicit consent.',
    continueButton: 'Continue',
    saveChanges: 'Save changes',
    saveError: 'Could not save your health profile. Please try again.',
    diabetesTypeTitle: 'Type of diabetes (optional)',
    diabetesType1: 'Type 1',
    diabetesType1Info: 'The body makes little or no insulin.',
    diabetesType2: 'Type 2',
    diabetesType2Info:
        'The body does not use insulin well. The most common type.',
    diabetesGestational: 'Gestational',
    diabetesGestationalInfo: 'Diabetes first found during pregnancy.',
    diabetesPrediabetes: 'Prediabetes',
    diabetesPrediabetesInfo:
        'Blood sugar is higher than normal but not yet in the diabetes '
        'range.',
    disclaimer:
        'Health conditions you select here should be reviewed by a licensed '
        'medical professional. They are not a self-assessment or a '
        'diagnosis.',
    disclaimerOk: 'OK, I understand',
    foodAllergyExamples:
        'Examples: peanuts, tree nuts, shellfish (shrimp, crab), fish, eggs, '
        'milk, soy, wheat, sesame',
    sectionConditions: 'Health conditions',
    bloodDisorderTypeTitle: 'Type of blood disorder (optional)',
    hemophiliaA: 'Hemophilia A',
    hemophiliaAInfo:
        'The most common type of hemophilia. The blood is low in clotting factor VIII, so bleeding can last longer.',
    bloodDisorderOther: 'Another bleeding or clotting disorder',
    bloodDisorderOtherInfo:
        'A bleeding or clotting condition other than Hemophilia A.',
    otherCondition: 'Other',
    otherConditionInfo: 'My condition is not listed above.',
    otherConditionHint: 'Type your condition',
    specifyCondition: 'Please specify your health condition/s',
    specifyConditionHint: 'Type your health condition here...',
    medicationsInfo:
        'Optional. Some medicines, such as blood thinners, can change how wounds bleed and heal.',
  );

  static const tl = ChecklistStrings(
    title: 'Profile ng Kalusugan',
    intro:
        'Para makapagbigay ng epektibong tulong medikal, kailangan '
        'naming malaman ang iyong profile sa kalusugan. Ang ilang '
        'partikular na kondisyon ay maaaring makaapekto nang malaki sa '
        'kung paano tumutugon ang iyong katawan sa mga sugat at sa mga '
        'tiyak na protokol na klinikal na kailangan para sa agarang '
        'paggagamot.',
    diabetes: 'Diabetes',
    hemophilia: 'Hemophilia o mga Sakit sa Dugo',
    severeAllergies: 'Malubhang Allergy',
    commonAllergies: 'Mga Karaniwan na Allergies',
    allergyRhinitis: 'Allergic rhinitis / Hay Fever',
    allergyFood: 'Mga Allergy sa Pagkain',
    allergySkin: 'Mga Allergy sa Balat',
    allergyInsect: 'Mga Allergy na nagmumula sa insekto',
    allergyDrug: 'Mga Allergy sa Gamot at Medisina',
    allergyLatex: 'Mga Allergy sa Latex',
    noneOfTheAbove:
        'Wala akong anuman sa mga nakalistang kondisyon (Magbigay ng '
        'Karaniwang Protokol na Klinikal)',
    diabetesInfo:
        'Isang kondisyon kung saan nahihirapan ang katawan na kontrolin '
        'ang asukal sa dugo. Ang mga sugat ay maaaring mas matagal '
        'gumaling at mas malamang na maimpeksyon.',
    hemophiliaInfo:
        'Mga kondisyon kung saan hindi normal ang pamumuo ng dugo, kaya '
        'maaaring mas matagal o mas mahirap pigilan ang pagdurugo.',
    severeAllergiesInfo:
        'Isang matinding reaksyon ng iyong katawan sa isang sustansya '
        'tulad ng pagkain, gamot, o kagat ng insekto, na maaaring '
        'magdulot ng pangangati, pantal, o pamamaga.',
    noneInfo:
        'Piliin ito kung wala sa mga kondisyon sa itaas ang naaangkop '
        'sa iyo.',
    privacyTitle: 'Pagkapribado at Paggamit ng Datos:',
    privacy:
        'Alinsunod sa Data Privacy Act, ang iyong personal na '
        'impormasyon ay ligtas na nakaimbak lamang sa iyong device at '
        'hindi ibinabahagi sa sinuman nang walang tahasang pahintulot '
        'mo.',
    continueButton: 'Magpatuloy',
    saveChanges: 'I-save ang mga pagbabago',
    saveError:
        'Hindi na-save ang iyong profile ng kalusugan. Pakisubukang '
        'muli.',
    diabetesTypeTitle: 'Uri ng diabetes (opsyonal)',
    diabetesType1: 'Type 1',
    diabetesType1Info: 'Mababa o walang nalilikhang insulin ang katawan.',
    diabetesType2: 'Type 2',
    diabetesType2Info:
        'Hindi nagagamit nang maayos ng katawan ang insulin. Ito ang '
        'pinakakaraniwang uri.',
    diabetesGestational: 'Gestational',
    diabetesGestationalInfo: 'Diabetes na unang natuklasan habang nagbubuntis.',
    diabetesPrediabetes: 'Prediabetes',
    diabetesPrediabetesInfo:
        'Mas mataas sa normal ang asukal sa dugo ngunit hindi pa pasok '
        'sa antas ng diabetes.',
    disclaimer:
        'Ang mga kondisyong pangkalusugan na pipiliin mo rito ay dapat '
        'suriin ng isang lisensyadong propesyonal sa medisina. Hindi ito '
        'self-assessment o diagnosis.',
    disclaimerOk: 'OK, naiintindihan ko',
    foodAllergyExamples:
        'Mga halimbawa: mani, tree nuts, shellfish (hipon, alimasag), '
        'isda, itlog, gatas, toyo, trigo, sesame',
    sectionConditions: 'Mga kondisyon sa kalusugan',
    bloodDisorderTypeTitle: 'Uri ng sakit sa dugo (opsyonal)',
    hemophiliaA: 'Hemophilia A',
    hemophiliaAInfo:
        'Ang pinakakaraniwang uri ng hemophilia. Mababa ang clotting '
        'factor VIII sa dugo, kaya mas tumatagal ang pagdurugo.',
    bloodDisorderOther: 'Iba pang karamdaman sa pagdurugo o pagbuo ng dugo',
    bloodDisorderOtherInfo:
        'Isang kondisyon ng pagdurugo o pagbuo ng dugo maliban sa '
        'Hemophilia A.',
    otherCondition: 'Iba pa',
    otherConditionInfo: 'Wala sa itaas ang aking kondisyon.',
    otherConditionHint: 'I-type ang iyong kondisyon',
    specifyCondition:
        'Mangyaring tukuyin ang iyong (mga) kondisyon sa kalusugan',
    specifyConditionHint: 'I-type ang iyong kondisyon sa kalusugan dito...',
    medicationsInfo:
        'Opsyonal. Ang ilang mga gamot, tulad ng blood thinners, ay '
        'maaaring magbago sa kung paano dumugo at gumaling ang mga '
        'sugat.',
  );
}
