import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Settings screen text (including the new language toggle) and the camera
/// permission-denied text on the camera screen, English + Tagalog. English
/// is the original wording, unchanged. Review the Tagalog before release.
class SettingsStrings {
  final String title;
  final String personalization;
  final String aboutApplication;
  final String helpFaq;
  final String feedback;
  final String terms;
  final String signIn;
  final String logOut;
  final String loggingOut;
  final String logOutError;
  // The "Log out?" confirmation.
  final String logOutConfirmTitle;
  final String logOutConfirmMessage;
  final String logOutConfirmCancel;
  final String logOutConfirmButton;
  final String aboutLegalese;
  final String closeButton;
  final String language;
  final String english;
  final String tagalog;
  final String banner;
  final String personalizationSub;
  final String aboutApplicationSub;
  final String aboutScanSub;
  final String helpFaqSub;
  final String languageSub;
  final String feedbackSub;
  final String termsSub;
  // The small note above Log out (the website itself is never translated).
  final String footerNote;
  // The warning when the text size is set very large (Personalization).
  final String textSizeWarnTitle;
  final String textSizeWarnBody;
  final String textSizeKeep;
  final String textSizeRevert;

  const SettingsStrings({
    required this.title,
    required this.personalization,
    required this.aboutApplication,
    required this.helpFaq,
    required this.feedback,
    required this.terms,
    required this.signIn,
    required this.logOut,
    required this.loggingOut,
    required this.logOutError,
    required this.logOutConfirmTitle,
    required this.logOutConfirmMessage,
    required this.logOutConfirmCancel,
    required this.logOutConfirmButton,
    required this.aboutLegalese,
    required this.closeButton,
    required this.language,
    required this.english,
    required this.tagalog,
    required this.banner,
    required this.personalizationSub,
    required this.aboutApplicationSub,
    required this.aboutScanSub,
    required this.helpFaqSub,
    required this.languageSub,
    required this.feedbackSub,
    required this.termsSub,
    required this.footerNote,
    required this.textSizeWarnTitle,
    required this.textSizeWarnBody,
    required this.textSizeKeep,
    required this.textSizeRevert,
  });

  static SettingsStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = SettingsStrings(
    title: 'Settings',
    personalization: 'Personalization',
    aboutApplication: 'About Application',
    helpFaq: 'Help/FAQ',
    feedback: 'Feedback',
    terms: 'Terms and conditions',
    signIn: 'Sign in',
    logOut: 'Log Out',
    loggingOut: 'Logging out...',
    logOutError: 'Could not log out. Please try again.',
    logOutConfirmTitle: 'Log out?',
    logOutConfirmMessage: 'Are you sure you want to log out?',
    logOutConfirmCancel: 'Cancel',
    logOutConfirmButton: 'Log out',
    aboutLegalese:
        'A multi-platform AI-integrated first aid guide for wounds, '
        'minor injuries, and skin issues assessment.',
    closeButton: 'Close',
    language: 'Language',
    english: 'English',
    tagalog: 'Tagalog',
    banner: 'Manage your preferences and app settings.',
    personalizationSub: 'Customize your text size.',
    aboutApplicationSub: 'App version and other information.',
    aboutScanSub: 'Learn about AI scan accuracy.',
    helpFaqSub: 'Find answer to common questions.',
    languageSub: 'Choose your preferred language.',
    feedbackSub: 'Send us your suggestions or report an issue.',
    termsSub: 'Read our terms and policies.',
    footerNote:
        'For further concern, reach out to us for further information; '
        'reach out on the official FineAid website.',
    textSizeWarnTitle: 'Text size is very large',
    textSizeWarnBody:
        'The text size is set too large for optimal viewing. Some UI '
        'elements may be clipped or overflow.',
    textSizeKeep: 'Keep this size',
    textSizeRevert: 'Go back',
  );

  static const tl = SettingsStrings(
    title: 'Mga Setting',
    personalization: 'Personalisasyon',
    aboutApplication: 'Tungkol sa Application',
    helpFaq: 'Tulong/FAQ',
    feedback: 'Feedback',
    terms: 'Mga tuntunin at kundisyon',
    signIn: 'Mag-sign in',
    logOut: 'Mag-log out',
    loggingOut: 'Nagla-log out...',
    logOutError: 'Hindi nakapag-log out. Pakisubukang muli.',
    logOutConfirmTitle: 'Mag-log out?',
    logOutConfirmMessage: 'Sigurado ka bang gusto mong mag-log out?',
    logOutConfirmCancel: 'Kanselahin',
    logOutConfirmButton: 'Mag-log out',
    aboutLegalese:
        'Isang multi-platform at AI-integrated na gabay sa first aid para '
        'sa pagsusuri ng mga sugat, maliliit na pinsala, at problema sa '
        'balat.',
    closeButton: 'Isara',
    language: 'Wika',
    english: 'English',
    tagalog: 'Tagalog',
    banner: 'Pamahalaan ang iyong mga kagustuhan at mga setting ng app.',
    personalizationSub: 'I-customize ang laki ng iyong teksto.',
    aboutApplicationSub: 'Bersyon ng app at iba pang impormasyon.',
    aboutScanSub: 'Alamin ang katumpakan ng AI scan.',
    helpFaqSub: 'Hanapin ang sagot sa mga karaniwang tanong.',
    languageSub: 'Piliin ang gusto mong wika.',
    feedbackSub: 'Ipadala ang iyong mungkahi o mag-ulat ng isyu.',
    termsSub: 'Basahin ang aming mga tuntunin at patakaran.',
    footerNote:
        'Para sa iba pang alalahanin, makipag-ugnayan sa amin para sa '
        'karagdagang impormasyon; makipag-ugnayan sa opisyal na website ng '
        'FineAid.',
    textSizeWarnTitle: 'Napakalaki ng laki ng teksto',
    textSizeWarnBody:
        'Masyadong malaki ang laki ng teksto para sa pinakamainam na '
        'pagtingin. Maaaring maputol o lumampas sa screen ang ilang bahagi '
        'ng app.',
    textSizeKeep: 'Panatilihin ang laking ito',
    textSizeRevert: 'Bumalik',
  );
}

/// The camera screen's "camera access is off" message (shown when the
/// camera permission was refused), English + Tagalog.
class CameraPermissionStrings {
  final String title;
  final String blockedMessage;
  final String askMessage;
  final String openSettings;
  final String tryAgain;

  const CameraPermissionStrings({
    required this.title,
    required this.blockedMessage,
    required this.askMessage,
    required this.openSettings,
    required this.tryAgain,
  });

  static CameraPermissionStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = CameraPermissionStrings(
    title: 'Camera access is off',
    blockedMessage:
        'Fine Aid needs the camera to scan wounds. Open Settings '
        'and allow Camera for Fine Aid, then come back.',
    askMessage:
        'Fine Aid needs camera access to scan wounds. Allow it '
        'when asked, or turn it on in Settings.',
    openSettings: 'Open Settings',
    tryAgain: 'Try Again',
  );

  static const tl = CameraPermissionStrings(
    title: 'Naka-off ang access sa camera',
    blockedMessage:
        'Kailangan ng Fine Aid ang camera para ma-scan ang mga sugat. '
        'Buksan ang Settings at payagan ang Camera para sa Fine Aid, saka '
        'bumalik.',
    askMessage:
        'Kailangan ng Fine Aid ng access sa camera para ma-scan ang mga '
        'sugat. Payagan ito kapag tinanong, o i-on sa Settings.',
    openSettings: 'Buksan ang Settings',
    tryAgain: 'Subukang Muli',
  );
}
