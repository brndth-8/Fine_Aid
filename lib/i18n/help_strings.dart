import 'package:flutter/widgets.dart';
import 'app_language.dart';
import 'help_content_en.dart';
import 'help_content_tl.dart';
import 'help_document.dart';

/// Help & Support screen text: the heading, the replay-tour button and the
/// four sections shown as accordions (Getting Started, Privacy Issues, How to
/// Use Journal, References), English + Tagalog. The long section text lives
/// in help_content_en.dart / help_content_tl.dart. Review the Tagalog before
/// release.
class HelpStrings {
  final String heading;
  final String replayTour;
  final String intro;
  final String gettingStartedSub;
  final String privacySub;
  final String journalSub;
  final String referencesSub;
  final HelpSection gettingStarted;
  final HelpSection privacy;
  final HelpSection journal;
  final HelpSection references;

  const HelpStrings({
    required this.heading,
    required this.replayTour,
    required this.intro,
    required this.gettingStartedSub,
    required this.privacySub,
    required this.journalSub,
    required this.referencesSub,
    required this.gettingStarted,
    required this.privacy,
    required this.journal,
    required this.references,
  });

  static HelpStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  /// The four accordions, in display order.
  List<HelpSection> get sections => [
    gettingStarted,
    privacy,
    journal,
    references,
  ];

  static const en = HelpStrings(
    heading: 'How can we help?',
    replayTour: 'Replay Help Tour',
    intro: 'Find helpful guides, answers, and information about using the app.',
    gettingStartedSub:
        'Learn how to set up your account and get started with the app.',
    privacySub: 'Learn how we protect your data and privacy.',
    journalSub: 'Step-by-step guide on using the journal feature.',
    referencesSub: 'Helpful resources and additional information.',
    gettingStarted: helpGettingStartedEn,
    privacy: helpPrivacyEn,
    journal: helpJournalEn,
    references: helpReferencesEn,
  );

  static const tl = HelpStrings(
    heading: 'Paano ka namin matutulungan?',
    replayTour: 'Ulitin ang Help Tour',
    intro:
        'Maghanap ng mga kapaki-pakinabang na gabay, sagot, at impormasyon tungkol sa paggamit ng app.',
    gettingStartedSub:
        'Alamin kung paano i-set up ang iyong account at magsimula sa app.',
    privacySub:
        'Alamin kung paano namin pinoprotektahan ang iyong datos at privacy.',
    journalSub: 'Hakbang-hakbang na gabay sa paggamit ng journal.',
    referencesSub:
        'Mga kapaki-pakinabang na sanggunian at karagdagang impormasyon.',
    gettingStarted: helpGettingStartedTl,
    privacy: helpPrivacyTl,
    journal: helpJournalTl,
    references: helpReferencesTl,
  );
}
