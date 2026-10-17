import 'package:flutter/widgets.dart';
import 'app_language.dart';

class OnboardingPageText {
  final String title;
  final String description;
  const OnboardingPageText({required this.title, required this.description});
}

/// Onboarding slides text, English + Tagalog. English is the original
/// wording, unchanged. Review the Tagalog before release.
class OnboardingStrings {
  final List<OnboardingPageText> pages;
  final String skip;
  final String next;
  final String getStarted;
  final String genericError;

  const OnboardingStrings({
    required this.pages,
    required this.skip,
    required this.next,
    required this.getStarted,
    required this.genericError,
  });

  static OnboardingStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  // Same order as the slides' icons: scanner, textbook, journal, notices.
  static const en = OnboardingStrings(
    pages: [
      OnboardingPageText(
        title: 'AI Wound Scanning',
        description:
            'Point your camera at a wound or skin issue and let our '
            'AI analyze it to give you instant first aid guidance.',
      ),
      OnboardingPageText(
        title: 'First Aid Textbook Guide',
        description:
            'Browse a trusted library of first aid references, '
            'always available even when you are offline.',
      ),
      OnboardingPageText(
        title: 'Health Journal',
        description:
            'Track your healing progress over time, with reminders '
            'and auto-referrals if a wound needs professional care.',
      ),
      OnboardingPageText(
        title: 'Stay Notified',
        description:
            'Get gentle reminders to check on your wounds and '
            'updates on new first aid content.',
      ),
    ],
    skip: 'Skip',
    next: 'Next',
    getStarted: 'Get Started',
    genericError: 'Something went wrong. Please try again.',
  );

  static const tl = OnboardingStrings(
    pages: [
      OnboardingPageText(
        title: 'AI na Pag-scan ng Sugat',
        description:
            'Itutok ang iyong camera sa sugat o problema sa balat at hayaang '
            'suriin ito ng aming AI para mabigyan ka agad ng gabay sa first '
            'aid.',
      ),
      OnboardingPageText(
        title: 'Gabay sa First Aid (Textbook)',
        description:
            'Mag-browse sa isang mapagkakatiwalaang aklatan ng mga '
            'sanggunian sa first aid, na laging magagamit kahit offline ka.',
      ),
      OnboardingPageText(
        title: 'Health Journal',
        description:
            'Subaybayan ang iyong paggaling sa paglipas ng panahon, may mga '
            'paalala at awtomatikong referral kung kailangan ng sugat ng '
            'propesyonal na pangangalaga.',
      ),
      OnboardingPageText(
        title: 'Manatiling Updated',
        description:
            'Makatanggap ng mahinahong paalala para tingnan ang iyong mga '
            'sugat at mga update tungkol sa bagong nilalaman ng first aid.',
      ),
    ],
    skip: 'Laktawan',
    next: 'Susunod',
    getStarted: 'Magsimula',
    genericError: 'May nangyaring mali. Pakisubukang muli.',
  );
}
