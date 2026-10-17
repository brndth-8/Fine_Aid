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
  );
}
