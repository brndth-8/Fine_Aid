/// Tagalog translations of the First Aid Health Kit's pre-written content
/// (category titles, triage questions, first-aid steps, warning signs).
/// Kept as plain, natural Tagalog a layperson can follow; widely used
/// medical/product loanwords (bandage, antiseptic, gasa) are kept as-is,
/// and a less common term gets its English in parentheses on first use.
///
/// Keyed by the same `id` as each `_Category` in first_aid_kit_screen.dart
/// so the two stay in sync — add a translation here whenever a category
/// is added there.
library;

class QuestionTranslation {
  final String text;
  final String? redFlagMessage;

  const QuestionTranslation({required this.text, this.redFlagMessage});
}

class CategoryTranslationTl {
  final String title;
  final List<QuestionTranslation> questions;
  final List<String> steps;
  final List<String> watchFor;
  final String seekCareIf;

  const CategoryTranslationTl({
    required this.title,
    required this.questions,
    required this.steps,
    required this.watchFor,
    required this.seekCareIf,
  });
}

// Tagalog version of _sharedTailQuestions — appended to every category
// below in the same order as the English original.
const List<QuestionTranslation> sharedTailQuestionsTl = [
  QuestionTranslation(
    text:
        'Malakas ba ang pagdugo sa bahaging ito, o hindi humihinto kahit '
        'pinipisil nang dahan-dahan sa loob ng ilang minuto?',
    redFlagMessage:
        'Ang pagdugong hindi humihinto kahit pinipisil nang dahan-dahan '
        'ay kailangan ng agarang pag-aalaga ng propesyonal.',
  ),
  QuestionTranslation(
    text: 'Matindi ba ang sakit, o lumalala sa halip na gumagaling?',
    redFlagMessage:
        'Ang matindi o lumalalang sakit ay dapat ipatingin sa isang '
        'healthcare professional.',
  ),
  QuestionTranslation(
    text:
        'Nagiging mas pula o mainit ba ang bahaging ito, o may lumalabas '
        'na nana o iba pang likido (discharge) — posibleng senyales ng '
        'impeksyon?',
    redFlagMessage:
        'Maaaring ito ay unang senyales ng impeksyon (infection) — '
        'mangyaring ipatingin ito sa isang healthcare professional.',
  ),
];

const List<String> defaultWatchForTl = [
  'Lumalalang pamumula, init, o pamamaga',
  'Nana o discharge',
  'Lumalala o kumakalat na sakit',
  'Lagnat',
];

final Map<String, CategoryTranslationTl> healthKitContentTl = {
  'laceration': CategoryTranslationTl(
    title: 'Malalim na Hiwa (Laceration)',
    questions: [
      const QuestionTranslation(
        text: 'Ito ba ay dulot ng maruming, kalawangin, o kontaminadong bagay?',
        redFlagMessage:
            'Dahil posibleng may kontaminadong bagay na sangkot, '
            'mas mabuting magpatingin sa isang healthcare professional '
            'para sa tetanus check.',
      ),
      const QuestionTranslation(
        text: 'Malalim ba ang hiwa, o bukas at malapad ang gilid nito?',
        redFlagMessage:
            'Ang malalim o malapad na hiwa ay kadalasang nangangailangan '
            'ng tahi (stitches) — mangyaring ipatingin ito sa isang '
            'propesyonal.',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Maghugas muna ng kamay bago hawakan ang sugat.',
      'Dahan-dahan ngunit matatag na pisilin ang sugat gamit ang malinis '
          'na gasa o tela para pigilan ang pagdugo.',
      'Banlawan ang sugat ng malinis na tubig kapag humupa na ang pagdugo.',
      'Takpan ng sterile na bendahe o dressing.',
      'Palitan ang takip araw-araw at panatilihing malinis at tuyo ang '
          'bahaging ito.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'Hindi humihinto ang pagdugo, malalim o malapad ang hiwa, o may '
        'napansin kang senyales ng impeksyon.',
  ),
  'minor_cut': CategoryTranslationTl(
    title: 'Maliit na Hiwa',
    questions: [
      const QuestionTranslation(
        text: 'Nasa mukha, kamay, o ibabaw ng kasukasuan (joint) ba ang hiwa?',
      ),
      const QuestionTranslation(
        text: 'May natitirang bagay pa ba na nakabaon sa sugat?',
        redFlagMessage:
            'Huwag subukang alisin mismo ang mga bagay na nakabaon sa '
            'sugat — magpatingin sa propesyonal na medikal na tulong.',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Maghugas ng kamay at banlawan ang hiwa sa malinis na tubig na '
          'umaagos.',
      'Dahan-dahang pisilin gamit ang malinis na tela kung dumudugo.',
      'Maglagay ng antiseptic kung meron.',
      'Takpan ng maliit na adhesive bandage.',
      'Panatilihing malinis ang bahagi at palitan ang bandage araw-araw.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'May bagay na nakabaon sa sugat, o may senyales ng impeksyon na '
        'lumitaw.',
  ),
  'scratch': CategoryTranslationTl(
    title: 'Kalmot',
    questions: [
      const QuestionTranslation(
        text: 'Ang kalmot ba ay galing sa alagang hayop o ibang hayop?',
        redFlagMessage:
            'Dahil posibleng kasangkot ang isang hayop sa sugat na ito, '
            'mas mabuting humingi ng payo mula sa isang healthcare '
            'professional (panganib ng rabies).',
      ),
      const QuestionTranslation(
        text: 'May pamamaga ba sa paligid ng kinalmot?',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Hugasang mabuti ang kinalmot gamit ang sabon at malinis na tubig.',
      'Maglagay ng antiseptic kung meron.',
      'Takpan ng malinis na bandage kung ito ay nasa bahaging madalas '
          'kumikiskis.',
      'Bantayan ang bahaging ito araw-araw sa susunod na ilang araw.',
      'Panatilihing malinis ang bahagi at iwasang kalmutin pa ito.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'May kasangkot na hayop, o may senyales ng impeksyon na lumitaw.',
  ),
  'abrasion': CategoryTranslationTl(
    title: 'Gasgas',
    questions: [
      const QuestionTranslation(
        text:
            'May dumi o gasgas na hindi maalis kahit banlawan ang '
            'bahaging gasgas?',
        redFlagMessage:
            'Ang mga dumi na nakabaon at hindi maalis sa paghuhugas ay '
            'dapat ipatingin sa isang propesyonal para maiwasan ang '
            'impeksyon.',
      ),
      const QuestionTranslation(
        text: 'Mas malaki ba ang gasgas kaysa sa palad mo?',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Banlawan nang dahan-dahan ang gasgas gamit ang malinis na tubig '
          'na umaagos.',
      'Maingat na alisin ang mga nakikitang dumi na hindi nakabaon nang '
          'husto.',
      'Maglagay ng antiseptic ointment kung meron.',
      'Takpan ng sterile na dressing na hindi dumidikit.',
      'Palitan ang takip araw-araw hanggang gumaling.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'Hindi maalis ang dumi, malaki ang sugat, o may lumitaw na '
        'senyales ng impeksyon.',
  ),
  'puncture_wound': CategoryTranslationTl(
    title: 'Tusok na Sugat (Puncture Wound)',
    questions: [
      const QuestionTranslation(
        text: 'Pako, karayom, o maruming/kalawangin bang bagay ang sanhi?',
        redFlagMessage:
            'Ang tusok na sugat mula sa maruming o kalawangin na bagay '
            'ay may panganib ng impeksyon at tetanus — mangyaring '
            'humingi ng medikal na tulong.',
      ),
      const QuestionTranslation(
        text: 'Malalim ba ang tusok?',
        redFlagMessage:
            'Ang malalim na tusok na sugat ay dapat ipasuri sa isang '
            'propesyonal, kahit mukhang kaunti lang ang pagdugo.',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Maghugas ng kamay, pagkatapos ay dahan-dahang hugasan ang bahagi '
          'gamit ang sabon at tubig.',
      'Huwag pisilin ang sugat para lang "paluwagin" ang dugo bilang '
          'paglilinis.',
      'Dahan-dahang pisilin gamit ang malinis na gasa kung dumudugo.',
      'Takpan ng malinis na bandage.',
      'Bantayang mabuti ang senyales ng impeksyon sa susunod na ilang '
          'araw.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'Maruming/kalawangin ang bagay na sanhi, malalim ang tusok, o '
        'hindi ka sigurado sa iyong bakuna sa tetanus.',
  ),
  'burn': CategoryTranslationTl(
    title: 'Paso',
    questions: [
      const QuestionTranslation(
        text:
            'Mas malaki ba ang paso kaysa sa palad mo, o nasa mukha, '
            'kamay, paa, o kasukasuan ba ito?',
        redFlagMessage:
            'Ang paso na ganito kalaki o nasa mga bahaging ito ay '
            'kailangang ipasuri ng propesyonal.',
      ),
      const QuestionTranslation(text: 'May paltos o sugatang balat ba?'),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Ibabad ang paso sa malamig (hindi yelo) na tubig na umaagos sa '
          'loob ng 10-20 minuto.',
      'Huwag maglagay ng yelo nang direkta sa paso.',
      'Alisin ang alahas o masikip na bagay na malapit sa napasong '
          'bahagi.',
      'Takpang maluwag gamit ang malinis na dressing na hindi dumidikit.',
      'Huwag pipigain o sasaksakin ang anumang paltos na lumitaw.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'Malaki o malalim ang paso, nasa sensitibong bahagi ito, o may '
        'senyales ng impeksyon.',
  ),
  'bruise': CategoryTranslationTl(
    title: 'Pasa',
    questions: [
      const QuestionTranslation(
        text:
            'Ito ba ay dulot ng malakas na epekto (pagkahulog, aksidente '
            'sa sasakyan, mabigat na bagay)?',
        redFlagMessage:
            'Ang mga sugat na dulot ng malakas na epekto ay maaaring may '
            'nakatagong pinsala — mangyaring magpatingin sa doktor.',
      ),
      const QuestionTranslation(
        text:
            'Sobrang namamaga ba, baluktot ang hugis, o mahirap galawin '
            'nang normal ang pasang bahagi?',
        redFlagMessage:
            'Maaaring ito ay senyales ng bali (fracture) o mas malalim '
            'na pinsala — mangyaring humingi ng medikal na atensyon.',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Magpahinga at iwasan ang karagdagang epekto sa pasang bahagi.',
      'Maglagay ng cold compress (nakabalot, hindi direkta sa balat) sa '
          'loob ng 15-20 minuto.',
      'Itaas ang bahagi nang mas mataas sa puso kung maaari.',
      'Pagkatapos ng 48 oras, makakatulong ang warm compress sa '
          'paggaling.',
      'Obserbahan ang laki at kulay ng pasa sa susunod na ilang araw.',
    ],
    watchFor: [
      'Lumalalang pamamaga o sakit',
      'Pamamanhid o hirap gumalaw ang bahagi',
      'Lumalaking husto ang pasa',
    ],
    seekCareIf:
        'May malakas na epekto na sanhi nito, o sobrang namamaga, '
        'baluktot, o mahirap galawin ang bahagi.',
  ),
  'swelling': CategoryTranslationTl(
    title: 'Pamamaga',
    questions: [
      const QuestionTranslation(
        text:
            'Bigla bang namaga nang walang malinaw na dahilan (posibleng '
            'reaksiyong alerdyi)?',
        redFlagMessage:
            'Ang biglaan at hindi maipaliwanag na pamamaga ay maaaring '
            'reaksiyong alerdyi (allergic reaction) — humingi kaagad ng '
            'medikal na atensyon, lalo na kung apektado ang mukha, labi, '
            'o lalamunan.',
      ),
      const QuestionTranslation(
        text: 'Mahirap ba galawin nang normal ang namamagang bahagi?',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Magpahinga sa namamagang bahagi.',
      'Maglagay ng cold compress (nakabalot, hindi direkta sa balat) sa '
          'loob ng 15-20 minuto.',
      'Itaas ang bahagi nang mas mataas sa puso kung maaari.',
      'Iwasan ang init o mabigat na aktibidad sa bahaging ito sa unang '
          'araw.',
      'Obserbahan ang pagbabago ng pamamaga sa susunod na 24-48 oras.',
    ],
    watchFor: [
      'Patuloy na lumalalang pamamaga',
      'Hirap sa paghinga o paglunok',
      'Kumakalat na pamamaga sa mukha, labi, o lalamunan',
    ],
    seekCareIf:
        'Bigla itong namaga nang walang dahilan, kumalat sa mukha/'
        'lalamunan, o may kasamang hirap sa paghinga.',
  ),
  'rash': CategoryTranslationTl(
    title: 'Pantal',
    questions: [
      const QuestionTranslation(
        text:
            'Bigla bang lumitaw ang pantal pagkatapos kumain ng bagong '
            'pagkain, gumamit ng bagong gamot, o makagat ng insekto '
            '(posibleng reaksiyong alerdyi)?',
        redFlagMessage:
            'Maaaring ito ay reaksiyong alerdyi (allergic reaction) — '
            'humingi ng medikal na atensyon, lalo na kung may hirap sa '
            'paghinga o pamamaga ng mukha.',
      ),
      const QuestionTranslation(
        text:
            'Mabilis bang kumakalat ang pantal, o may kasamang hirap sa '
            'paghinga o pamamaga ng mukha?',
        redFlagMessage:
            'Ito ay mga senyales ng malubhang reaksiyong alerdyi — '
            'humingi kaagad ng emergency care.',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Iwasang kamutin ang apektadong bahagi.',
      'Hugasang dahan-dahan ang bahagi gamit ang mild na sabon at '
          'malamig na tubig.',
      'Maglagay ng walang pabangong moisturizer o soothing lotion kung '
          'meron.',
      'Iwasan ang kilala mong mga irritant o allergen kung makikilala '
          'mo ito.',
      'Itala kung kailan nagsimula ang pantal at anumang bagong bagay '
          'na naharap mo.',
    ],
    watchFor: [
      'Mabilis na kumakalat na pantal',
      'Hirap sa paghinga o pamamaga ng mukha/lalamunan',
      'Lagnat kasabay ng pantal',
    ],
    seekCareIf:
        'Maaaring reaksiyong alerdyi ang pantal, mabilis itong '
        'kumakalat, o may kasamang hirap sa paghinga.',
  ),
  'other_skin_issue': CategoryTranslationTl(
    title: 'Ibang Problema sa Balat',
    questions: [
      const QuestionTranslation(text: 'May aktibong pagdugo ba?'),
      const QuestionTranslation(
        text: 'Sobrang masakit ba o lubhang namamaga ang apektadong bahagi?',
      ),
      ...sharedTailQuestionsTl,
    ],
    steps: [
      'Panatilihing malinis ang apektadong bahagi.',
      'Maglapat ng angkop na first aid batay sa iyong nakikita '
          '(paglilinis, cold compress, o pagpapahinga kung kinakailangan).',
      'Iwasang lagyan ng diin o pressure ang nasugatang bahagi.',
      'Obserbahan ang bahagi para sa mga pagbabago sa susunod na araw.',
      'Kung hindi sigurado kung ano ito, mag-ingat at bantayang mabuti.',
    ],
    watchFor: defaultWatchForTl,
    seekCareIf:
        'Hindi ka sigurado sa sugat, o may lumitaw na nakababahalang '
        'senyales.',
  ),
};
