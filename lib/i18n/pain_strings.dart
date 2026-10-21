import 'package:flutter/widgets.dart';
import '../data/pain_assessment.dart';
import 'app_language.dart';

/// What the user sees for ONE pain rating: its label, the message shown
/// first, and the "small help" (short interim care tips) shown after it.
/// One entry per rating 0-5 in [PainStrings.ratings] — edit a rating's text
/// here and nowhere else.
class PainRatingContent {
  /// Short name shown on the scale, eg "Minor".
  final String label;

  /// Shown first, as a recommendation (never a diagnosis).
  final String message;

  /// Small help: short interim care tips for this rating.
  final List<String> tips;

  const PainRatingContent({
    required this.label,
    required this.message,
    required this.tips,
  });
}

/// Pain-scale pop-up and pain-based guidance text, English + Tagalog.
///
/// IMPORTANT: every message and small-help tip below is general first-aid
/// advice drafted for this app and MUST be reviewed by a nursing/medical
/// professional before release.
class PainStrings {
  final String dialogTitle;
  final String dialogBody;
  final String chooseHint;
  final String continueButton;

  // Names used for older entries saved on the 1-10 scale.
  final String levelMild;
  final String levelModerate;
  final String levelSevere;
  final String levelWorst;

  final String scoreLabelFormat; // uses {n}, {max} and {level}

  final String professionalTitle;
  final String urgentTitle;
  final String smallHelpTitle;
  final String findHealthcare;

  /// Index = the rating (0-5).
  final List<PainRatingContent> ratings;

  const PainStrings({
    required this.dialogTitle,
    required this.dialogBody,
    required this.chooseHint,
    required this.continueButton,
    required this.levelMild,
    required this.levelModerate,
    required this.levelSevere,
    required this.levelWorst,
    required this.scoreLabelFormat,
    required this.professionalTitle,
    required this.urgentTitle,
    required this.smallHelpTitle,
    required this.findHealthcare,
    required this.ratings,
  });

  static PainStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  PainRatingContent rating(int score) => ratings[score];

  /// Name of an older (1-10 scale) entry's level.
  String levelName(PainLevel level) {
    switch (level) {
      case PainLevel.mild:
        return levelMild;
      case PainLevel.moderate:
        return levelModerate;
      case PainLevel.severe:
        return levelSevere;
      case PainLevel.worst:
        return levelWorst;
    }
  }

  /// eg "Pain score: 2/5 (Minor)".
  String scoreLabel(int score) => scoreLabelFormat
      .replaceFirst('{n}', '$score')
      .replaceFirst('{max}', '$kPainMax')
      .replaceFirst('{level}', ratings[score].label);

  static const en = PainStrings(
    dialogTitle: 'How much pain are you feeling?',
    dialogBody:
        'Rate your pain from 0 to 5, where 0 is no pain and 5 is severe.',
    chooseHint: 'Choose a number to continue.',
    continueButton: 'Continue',
    levelMild: 'Mild',
    levelModerate: 'Moderate',
    levelSevere: 'Severe',
    levelWorst: 'Worst',
    scoreLabelFormat: 'Pain score: {n}/{max} ({level})',
    professionalTitle: 'Seek Professional Consultation',
    urgentTitle: 'Seek Urgent Medical Care',
    smallHelpTitle: 'Small help',
    findHealthcare: 'Find Nearby Healthcare',
    ratings: [
      PainRatingContent(
        label: 'No pain',
        message:
            'You reported no pain. The standard care steps below are enough '
            'for now.',
        tips: [
          'Keep the area clean and dry.',
          'Follow the first aid steps shown below.',
          'Look at the area once a day for any change.',
        ],
      ),
      PainRatingContent(
        label: 'Very mild',
        message:
            'You reported very mild pain. The standard care steps below '
            'should be enough for now.',
        tips: [
          'Keep the area clean and dry.',
          'Avoid pressing or rubbing the area.',
          'Look at the area once a day. If the pain grows, see a '
              'healthcare professional.',
        ],
      ),
      PainRatingContent(
        label: 'Minor',
        message:
            'You reported minor pain. Take a little extra care and keep an '
            'eye on the area.',
        tips: [
          'Rest the area and avoid activities that make it hurt.',
          'Keep it clean and dry, and covered if needed.',
          'Check it at least twice a day for more redness, swelling, '
              'warmth, or discharge.',
          'Ask a pharmacist about an over-the-counter pain reliever that '
              'is suitable for you.',
        ],
      ),
      PainRatingContent(
        label: 'Moderate',
        message:
            'You reported moderate pain. Be more careful with the area and '
            'monitor it closely.',
        tips: [
          'Rest the area and avoid pressing on it or putting strain on it.',
          'Keep it clean and dry, and change the dressing if it gets wet '
              'or dirty.',
          'Check it several times a day for spreading redness, swelling, '
              'warmth, pus, or fever.',
          'If the pain is not easing within a day, see a healthcare '
              'professional.',
        ],
      ),
      PainRatingContent(
        label: 'Severe',
        message:
            'You reported severe pain. We recommend seeking professional '
            'consultation.',
        tips: [
          'Avoid using the area or putting weight on it.',
          'Keep it clean and covered with a clean, non-stick dressing, and '
              'raised if possible.',
          'Ask a pharmacist or doctor about a suitable pain reliever and '
              'follow the package label.',
          'Watch for heavy bleeding, numbness, or spreading redness, and '
              'get care sooner if any appear.',
        ],
      ),
      PainRatingContent(
        label: 'Worst pain',
        message: 'We advise you to seek medical consultation.',
        tips: [
          'Stop what you are doing and rest. Avoid using the area or '
              'putting weight on it.',
          'If it is bleeding, press gently but firmly with clean gauze or '
              'cloth.',
          'Keep it covered with a clean, non-stick dressing and raised if '
              'possible. Do not put anything on it unless a professional '
              'advises.',
          'Ask someone to stay with you or take you to a clinic or hospital, '
              'and bring this assessment to show the healthcare '
              'professional.',
          'If you feel faint or confused, or have trouble breathing, go to '
              'the nearest emergency room right away.',
        ],
      ),
    ],
  );

  static const tl = PainStrings(
    dialogTitle: 'Gaano kasakit ang nararamdaman mo?',
    dialogBody:
        'I-rate ang iyong sakit mula 0 hanggang 5, kung saan ang 0 ay walang '
        'sakit at ang 5 ay matindi.',
    chooseHint: 'Pumili ng numero para magpatuloy.',
    continueButton: 'Magpatuloy',
    levelMild: 'Banayad',
    levelModerate: 'Katamtaman',
    levelSevere: 'Matindi',
    levelWorst: 'Pinakamatindi',
    scoreLabelFormat: 'Antas ng sakit: {n}/{max} ({level})',
    professionalTitle: 'Kumonsulta sa Propesyonal',
    urgentTitle: 'Humingi ng Agarang Medikal na Tulong',
    smallHelpTitle: 'Munting tulong',
    findHealthcare: 'Maghanap ng Malapit na Pasilidad',
    ratings: [
      PainRatingContent(
        label: 'Walang sakit',
        message:
            'Iniulat mong walang sakit. Sapat na muna ang karaniwang mga '
            'hakbang sa pangangalaga sa ibaba.',
        tips: [
          'Panatilihing malinis at tuyo ang bahagi.',
          'Sundin ang mga hakbang sa first aid sa ibaba.',
          'Tingnan ang bahagi isang beses sa isang araw para sa anumang '
              'pagbabago.',
        ],
      ),
      PainRatingContent(
        label: 'Napakagaan',
        message:
            'Iniulat mong napakagaan ng sakit. Dapat sapat na muna ang '
            'karaniwang mga hakbang sa pangangalaga sa ibaba.',
        tips: [
          'Panatilihing malinis at tuyo ang bahagi.',
          'Iwasang diinan o kuskusin ang bahagi.',
          'Tingnan ang bahagi isang beses sa isang araw. Kung lumala ang '
              'sakit, magpatingin sa propesyonal sa kalusugan.',
        ],
      ),
      PainRatingContent(
        label: 'Maliit',
        message:
            'Iniulat mong maliit na sakit. Mag-ingat nang kaunti pa at '
            'bantayan ang bahagi.',
        tips: [
          'Ipahinga ang bahagi at iwasan ang mga gawaing nagpapasakit dito.',
          'Panatilihing malinis at tuyo, at may takip kung kailangan.',
          'Tingnan ito kahit dalawang beses sa isang araw para sa dagdag na '
              'pamumula, pamamaga, init, o lumalabas na likido.',
          'Magtanong sa parmasyutiko tungkol sa pampawala ng sakit na mabibili '
              'nang walang reseta at angkop sa iyo.',
        ],
      ),
      PainRatingContent(
        label: 'Katamtaman',
        message:
            'Iniulat mong katamtaman ang sakit. Mag-ingat nang higit sa '
            'bahaging ito at bantayan itong mabuti.',
        tips: [
          'Ipahinga ang bahagi at iwasang diinan o pwersahin ito.',
          'Panatilihing malinis at tuyo, at palitan ang takip kapag nabasa '
              'o nadumihan.',
          'Tingnan ito nang ilang beses sa isang araw para sa kumakalat na '
              'pamumula, pamamaga, init, nana, o lagnat.',
          'Kung hindi gumagaan ang sakit sa loob ng isang araw, magpatingin '
              'sa propesyonal sa kalusugan.',
        ],
      ),
      PainRatingContent(
        label: 'Matindi',
        message:
            'Iniulat mong matindi ang sakit. Inirerekomenda naming '
            'kumonsulta sa propesyonal.',
        tips: [
          'Iwasang gamitin ang bahagi o patungan ng bigat.',
          'Panatilihing malinis at natatakpan ng malinis na non-stick na '
              'dressing, at nakataas kung posible.',
          'Magtanong sa parmasyutiko o doktor tungkol sa angkop na '
              'pampawala ng sakit at sundin ang nakasulat sa label.',
          'Bantayan ang matinding pagdurugo, pamamanhid, o kumakalat na '
              'pamumula, at magpatingin nang mas maaga kung lumitaw ang '
              'alinman.',
        ],
      ),
      PainRatingContent(
        label: 'Pinakamatinding sakit',
        message:
            'Pinapayuhan ka naming magpakonsulta sa medikal na propesyonal.',
        tips: [
          'Itigil ang ginagawa at magpahinga. Iwasang gamitin ang bahagi o '
              'patungan ng bigat.',
          'Kung dumudugo, dahan-dahan ngunit matatag na pisilin gamit ang '
              'malinis na gasa o tela.',
          'Takpan ng malinis na non-stick na dressing at itaas kung posible. '
              'Huwag maglagay ng anuman dito maliban kung payo ng '
              'propesyonal.',
          'Magpasama sa iba o magpadala sa klinika o ospital, at dalhin ang '
              'pagsusuring ito para maipakita sa propesyonal sa kalusugan.',
          'Kung nahihilo o nalilito ka, o nahihirapang huminga, pumunta agad '
              'sa pinakamalapit na emergency room.',
        ],
      ),
    ],
  );
}
