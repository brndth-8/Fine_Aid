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
  final String rateApp;
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
  final String language;
  final String english;
  final String tagalog;

  const SettingsStrings({
    required this.title,
    required this.personalization,
    required this.aboutApplication,
    required this.helpFaq,
    required this.rateApp,
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
    required this.language,
    required this.english,
    required this.tagalog,
  });

  static SettingsStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = SettingsStrings(
    title: 'Settings',
    personalization: 'Personalization',
    aboutApplication: 'About Application',
    helpFaq: 'Help/FAQ',
    rateApp: 'Rate this app',
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
    language: 'Language',
    english: 'English',
    tagalog: 'Tagalog',
  );

  static const tl = SettingsStrings(
    title: 'Mga Setting',
    personalization: 'Personalisasyon',
    aboutApplication: 'Tungkol sa Application',
    helpFaq: 'Tulong/FAQ',
    rateApp: 'I-rate ang app na ito',
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
    language: 'Wika',
    english: 'English',
    tagalog: 'Tagalog',
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
