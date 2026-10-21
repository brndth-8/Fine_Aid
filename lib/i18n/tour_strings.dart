import 'package:flutter/widgets.dart';
import 'app_language.dart';

class TourStepText {
  final String title;
  final String description;
  const TourStepText(this.title, this.description);
}

/// Dashboard help tour text (English + Tagalog). English is the original
/// wording, unchanged. Review the Tagalog before release.
class TourStrings {
  /// Same order as the dashboard's tour steps: welcome, AI Scanner, Health
  /// Journal, First Aid Textbook, Help & Support, Profile, Settings.
  final List<TourStepText> steps;
  final String skipTour;
  final String back;
  final String next;
  final String done;

  const TourStrings({
    required this.steps,
    required this.skipTour,
    required this.back,
    required this.next,
    required this.done,
  });

  static TourStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = TourStrings(
    steps: [
      TourStepText(
        'Welcome to Fine Aid',
        'A quick look at the main features - tap Next to continue, or '
            'Skip Tour any time.',
      ),
      TourStepText(
        'AI Scanner',
        'Point your camera at a wound or skin issue and get instant, '
            'AI-powered first aid guidance.',
      ),
      TourStepText(
        'Health Journal',
        'Track your recovery over time, with healing-progress estimates '
            'and reminders if something needs a closer look.',
      ),
      TourStepText(
        'First Aid Textbook',
        'Browse trusted first aid reference books — available even '
            'when you\'re offline, with search to jump straight to a topic.',
      ),
      TourStepText(
        'Help & Support',
        'Find answers to common questions, or come back here to replay '
            'this tour whenever you like.',
      ),
      TourStepText(
        'Profile',
        'View and edit your profile, and manage your account details '
            'from here.',
      ),
      TourStepText(
        'Settings',
        'Adjust notifications, text size, and other app preferences '
            'from here.',
      ),
    ],
    skipTour: 'Skip Tour',
    back: 'Back',
    next: 'Next',
    done: 'Done',
  );

  static const tl = TourStrings(
    steps: [
      TourStepText(
        'Maligayang pagdating sa Fine Aid',
        'Isang mabilis na pagtingin sa mga pangunahing tampok - i-tap ang '
            'Susunod para magpatuloy, o Laktawan ang Tour anumang oras.',
      ),
      TourStepText(
        'AI Scanner',
        'Itutok ang iyong camera sa sugat o problema sa balat at makakuha '
            'ng agarang gabay sa first aid mula sa AI.',
      ),
      TourStepText(
        'Health Journal',
        'Subaybayan ang iyong paggaling sa paglipas ng panahon, may mga '
            'pagtatantya ng paggaling at paalala kung may kailangang '
            'masusing tingnan.',
      ),
      TourStepText(
        'First Aid Textbook',
        'Mag-browse ng mga mapagkakatiwalaang aklat ng first aid - '
            'magagamit kahit offline, at may paghahanap para direktang '
            'makapunta sa isang paksa.',
      ),
      TourStepText(
        'Tulong at Suporta',
        'Maghanap ng sagot sa mga karaniwang tanong, o bumalik dito para '
            'ulitin ang tour na ito anumang oras.',
      ),
      TourStepText(
        'Profile',
        'Tingnan at i-edit ang iyong profile, at pamahalaan dito ang mga '
            'detalye ng iyong account.',
      ),
      TourStepText(
        'Settings',
        'Ayusin dito ang mga notification, laki ng teksto, at iba pang '
            'kagustuhan sa app.',
      ),
    ],
    skipTour: 'Laktawan ang Tour',
    back: 'Bumalik',
    next: 'Susunod',
    done: 'Tapos na',
  );
}
