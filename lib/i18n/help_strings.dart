import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for one Help topic page (title, paragraphs, optional info cards).
class HelpTopicText {
  final String title;
  final List<String> paragraphs;
  final List<String> cardLabels;

  const HelpTopicText({
    required this.title,
    required this.paragraphs,
    this.cardLabels = const [],
  });
}

/// Help & Support screens text (the topic list and the four topic pages:
/// Getting Started, Privacy Issues, How to use Journal, References), English
/// + Tagalog. English is the original wording, unchanged. Review the
/// Tagalog before release.
class HelpStrings {
  final String heading;
  final String gettingStartedTile;
  final String privacyTile;
  final String journalTile;
  final String referencesTile;
  final String replayTour;
  // Placeholder shown on the (still empty) Verified Medical Sources and
  // Doctor-Reviewed Content pages under References.
  final String contentComingSoon;
  final HelpTopicText gettingStarted;
  final HelpTopicText privacy;
  final HelpTopicText journal;
  final HelpTopicText references;

  const HelpStrings({
    required this.heading,
    required this.gettingStartedTile,
    required this.privacyTile,
    required this.journalTile,
    required this.referencesTile,
    required this.replayTour,
    required this.contentComingSoon,
    required this.gettingStarted,
    required this.privacy,
    required this.journal,
    required this.references,
  });

  static HelpStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = HelpStrings(
    heading: 'How can we help?',
    gettingStartedTile: 'Getting Started',
    privacyTile: 'Privacy Issues',
    journalTile: 'How to use Journal?',
    referencesTile: 'References',
    replayTour: 'Replay Help Tour',
    contentComingSoon: 'Content coming soon',
    gettingStarted: HelpTopicText(
      title: 'Getting Started',
      paragraphs: [
        'Fine Aid helps you assess minor wounds and skin issues using AI, '
            'keep a recovery journal, and access trusted first aid references — '
            'all in one place.',
        'Start by exploring the Dashboard: browse the First Aid Textbook Guide, '
            'use the AI Vision Camera to scan an injury, or open your Health '
            "Journal to log how you're feeling.",
        'Create an account to save your journal entries, personalize your '
            'profile, and get healing reminders. Guest mode lets you explore '
            'without saving any data.',
      ],
    ),
    privacy: HelpTopicText(
      title: 'Privacy Issues',
      paragraphs: [
        'Your personal information, including your username and contact '
            'details, is stored securely and is never shared without your '
            'explicit consent.',
        'Images attached to your Health Journal entries is not viewable '
            'to the admin module for review purposes, to help improve the '
            'accuracy and safety of guidance provided.',
        'In Guest Mode, none of your entries or images are saved - they '
            'exist only temporarily during your session.',
      ],
    ),
    journal: HelpTopicText(
      title: 'How to use Journal?',
      paragraphs: [
        'The Health Journal helps you track wounds and skin issues over '
            'time. Tap "Add Entry" to create a new log: add a photo, give it '
            "a title, describe how you're feeling, and classify the issue "
            '(Injury, Burns, Skin Issues, or Animal Bite/Scratch).',
        'Turn on "Remind Me" to get a notification once you\'ve reached the '
            'standard healing time for that classification — Fine Aid will '
            "check in and ask if you're feeling better.",
        'Tap any entry to view its full details, ask for more help, or '
            'export your log to share with a healthcare provider.',
      ],
    ),
    references: HelpTopicText(
      title: 'References',
      paragraphs: [
        'Sources include: WHO, American Red Cross, MIMS, recognized local '
            'organizations. Every piece of information is cross-referenced.',
        'All clinical guidelines and advice are meticulously reviewed and '
            'credited by a panel of board-certified specialists.',
      ],
      cardLabels: ['Verified Medical Sources', 'Doctor-Reviewed Content'],
    ),
  );

  static const tl = HelpStrings(
    heading: 'Paano ka namin matutulungan?',
    gettingStartedTile: 'Pagsisimula',
    privacyTile: 'Mga Isyu sa Privacy',
    journalTile: 'Paano gamitin ang Journal?',
    referencesTile: 'Mga Sanggunian',
    replayTour: 'Ulitin ang Help Tour',
    contentComingSoon: 'Malapit nang magkaroon ng nilalaman',
    gettingStarted: HelpTopicText(
      title: 'Pagsisimula',
      paragraphs: [
        'Tinutulungan ka ng Fine Aid na suriin ang maliliit na sugat at '
            'problema sa balat gamit ang AI, magtago ng journal ng paggaling, '
            'at ma-access ang mga mapagkakatiwalaang sanggunian sa first aid '
            '— lahat sa iisang lugar.',
        'Magsimula sa pag-explore ng Dashboard: tingnan ang First Aid '
            'Textbook Guide, gamitin ang AI Vision Camera para i-scan ang '
            'isang pinsala, o buksan ang iyong Health Journal para itala ang '
            'iyong nararamdaman.',
        'Gumawa ng account para ma-save ang mga entry sa journal, '
            'ma-personalize ang iyong profile, at makatanggap ng mga paalala '
            'sa paggaling. Sa Guest mode, makakapag-explore ka nang hindi '
            'nagse-save ng anumang datos.',
      ],
    ),
    privacy: HelpTopicText(
      title: 'Mga Isyu sa Privacy',
      paragraphs: [
        'Ang iyong personal na impormasyon, kasama ang iyong username at '
            'mga detalye sa pakikipag-ugnayan, ay ligtas na iniimbak at '
            'hindi kailanman ibinabahagi nang walang malinaw mong pahintulot.',
        'Ang mga larawang naka-attach sa iyong mga entry sa Health Journal '
            'ay hindi makikita ng admin module para sa layunin ng pagsusuri, '
            'upang makatulong sa pagpapabuti ng katumpakan at kaligtasan ng '
            'ibinibigay na gabay.',
        'Sa Guest Mode, walang entry o larawan mo ang nase-save - '
            'pansamantala lamang itong umiiral habang nasa session ka.',
      ],
    ),
    journal: HelpTopicText(
      title: 'Paano gamitin ang Journal?',
      paragraphs: [
        'Tinutulungan ka ng Health Journal na subaybayan ang mga sugat at '
            'problema sa balat sa paglipas ng panahon. I-tap ang "Add Entry" '
            'para gumawa ng bagong tala: magdagdag ng larawan, bigyan ito ng '
            'pamagat, ilarawan ang iyong nararamdaman, at i-classify ang '
            'problema (Pinsala, Paso, Problema sa Balat, o Kagat/Kalmot ng '
            'Hayop).',
        'I-on ang "Remind Me" para makatanggap ng notification kapag naabot '
            'mo na ang karaniwang oras ng paggaling para sa classification '
            'na iyon — magtatanong ang Fine Aid kung bumubuti na ang '
            'pakiramdam mo.',
        'I-tap ang anumang entry para makita ang buong detalye nito, '
            'humingi ng karagdagang tulong, o i-export ang iyong log para '
            'maibahagi sa isang healthcare provider.',
      ],
    ),
    references: HelpTopicText(
      title: 'Mga Sanggunian',
      paragraphs: [
        'Kabilang sa mga pinagkukunan: WHO, American Red Cross, MIMS, at '
            'mga kinikilalang lokal na organisasyon. Bawat impormasyon ay '
            'inihahambing sa iba pang sanggunian.',
        'Ang lahat ng klinikal na alituntunin at payo ay maingat na '
            'sinusuri at kinikilala ng isang panel ng mga board-certified na '
            'espesyalista.',
      ],
      cardLabels: [
        'Mga Beripikadong Sanggunian sa Medisina',
        'Nilalamang Sinuri ng Doktor',
      ],
    ),
  );
}
