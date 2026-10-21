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
  final String diabetesNotSure;
  final String diabetesNotSureInfo;
  // Shown every time a condition is checked.
  final String disclaimer;
  final String disclaimerOk;
  // Examples under Food Allergies.
  final String foodAllergyExamples;

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
    required this.diabetesNotSure,
    required this.diabetesNotSureInfo,
    required this.disclaimer,
    required this.disclaimerOk,
    required this.foodAllergyExamples,
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
    diabetesNotSure: 'Not sure',
    diabetesNotSureInfo: 'I have diabetes but I do not know which type.',
    disclaimer:
        'Health conditions you select here should be reviewed by a licensed '
        'medical professional. They are not a self-assessment or a '
        'diagnosis.',
    disclaimerOk: 'OK, I understand',
    foodAllergyExamples:
        'Examples: peanuts, tree nuts, shellfish (shrimp, crab), fish, eggs, '
        'milk, soy, wheat, sesame',
  );

  static const tl = ChecklistStrings(
    title: 'Profile ng Kalusugan',
    intro:
        'Para makapagbigay ng epektibong tulong medikal, kailangan naming '
        'maunawaan ang iyong profile ng kalusugan. Ang ilang kondisyon ay '
        'malaking nakaaapekto sa kung paano tumutugon ang iyong katawan sa '
        'mga pinsala at sa mga partikular na klinikal na protokol na '
        'kailangan sa agarang pangangalaga.',
    diabetes: 'Diabetes',
    hemophilia: 'Hemophilia o mga Sakit sa Dugo',
    severeAllergies: 'Malubhang Allergy',
    commonAllergies: 'Karaniwang mga Allergy',
    allergyRhinitis: 'Allergic rhinitis / Hay Fever',
    allergyFood: 'Allergy sa Pagkain',
    allergySkin: 'Allergy sa Balat',
    allergyInsect: 'Allergy sa Kagat at Tusok ng Insekto',
    allergyDrug: 'Allergy sa Gamot',
    allergyLatex: 'Allergy sa Latex',
    noneOfTheAbove:
        'Wala akong alinman sa mga nakalistang kondisyon (Ibigay ang '
        'Karaniwang Klinikal na Protokol)',
    diabetesInfo:
        'Isang kondisyon kung saan nahihirapan ang katawan na kontrolin ang '
        'asukal sa dugo. Maaaring mas matagal gumaling ang mga sugat at mas '
        'madali itong mahawa ng impeksyon.',
    hemophiliaInfo:
        'Mga kondisyon kung saan hindi normal ang pamumuo ng dugo, kaya '
        'maaaring mas matagal o mas mahirap pigilan ang pagdurugo.',
    severeAllergiesInfo:
        'Matinding reaksyon ng katawan sa isang bagay tulad ng pagkain, '
        'gamot, o kagat ng insekto, na maaaring magdulot ng pangangati, '
        'pantal, o pamamaga.',
    noneInfo:
        'Piliin ito kung wala sa mga kondisyon sa itaas ang naaangkop sa '
        'iyo.',
    privacyTitle: 'Privacy at Paggamit ng Datos:',
    privacy:
        'Alinsunod sa Data Privacy Act, ang iyong personal na impormasyon ay '
        'ligtas na iniimbak sa iyong device lamang at hindi ibinabahagi '
        'kaninuman nang walang malinaw mong pahintulot.',
    continueButton: 'Magpatuloy',
    saveError:
        'Hindi na-save ang iyong profile ng kalusugan. Pakisubukang '
        'muli.',
    diabetesTypeTitle: 'Uri ng diabetes (opsyonal)',
    diabetesType1: 'Type 1',
    diabetesType1Info: 'Kaunti o walang insulin na nagagawa ang katawan.',
    diabetesType2: 'Type 2',
    diabetesType2Info:
        'Hindi mahusay na nagagamit ng katawan ang insulin. Ito ang '
        'pinakakaraniwang uri.',
    diabetesGestational: 'Gestational',
    diabetesGestationalInfo: 'Diabetes na unang natuklasan habang buntis.',
    diabetesPrediabetes: 'Prediabetes',
    diabetesPrediabetesInfo:
        'Mas mataas kaysa normal ang asukal sa dugo pero wala pa sa antas '
        'ng diabetes.',
    diabetesNotSure: 'Hindi sigurado',
    diabetesNotSureInfo: 'May diabetes ako pero hindi ko alam kung anong uri.',
    disclaimer:
        'Ang mga kondisyong pangkalusugan na pipiliin mo rito ay dapat '
        'suriin ng isang lisensyadong propesyonal sa medisina. Hindi ito '
        'self-assessment o diagnosis.',
    disclaimerOk: 'OK, naiintindihan ko',
    foodAllergyExamples:
        'Mga halimbawa: mani, tree nuts, shellfish (hipon, alimango), isda, '
        'itlog, gatas, toyo (soy), trigo, linga',
  );
}
