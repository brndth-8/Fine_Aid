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
  final HelpSection gettingStarted;
  final HelpSection privacy;
  final HelpSection journal;
  final HelpSection references;

  const HelpStrings({
    required this.heading,
    required this.replayTour,
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
    gettingStarted: helpGettingStartedEn,
    privacy: helpPrivacyEn,
    journal: helpJournalEn,
    references: helpReferencesEn,
  );

  static const tl = HelpStrings(
    heading: 'Paano ka namin matutulungan?',
    replayTour: 'Ulitin ang Help Tour',
    gettingStarted: helpGettingStartedTl,
    privacy: helpPrivacyTl,
    journal: helpJournalTl,
    references: helpReferencesTl,
  );
}
