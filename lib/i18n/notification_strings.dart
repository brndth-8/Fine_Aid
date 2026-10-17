import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';

/// Wording for the healing check-in notification and everything around it,
/// English + Tagalog. Deliberately neutral: it only asks "Are you feeling
/// better?" and never says a wound is better or worse — this is a
/// preliminary check-in, not a diagnosis. Review the Tagalog before release.
///
/// A notification fires without a screen to read the language from, so
/// [load] reads the saved Settings > Language straight from the device.
class NotificationStrings {
  final String checkInTitle;
  final String checkInBody;
  // The three answers: short labels for the notification's buttons, longer
  // ones for the in-app check-in.
  final String actionBetter;
  final String actionNotYet;
  final String actionWorse;
  final String dialogBetter;
  final String dialogNotYet;
  final String dialogWorse;
  final String notYetSnack;
  // Shown after "No": a recommendation, never a diagnosis.
  final String seeProfessional;
  final String entryUnavailable;
  final String guestTitle;
  final String guestBody;
  final String guestSignIn;
  final String remindMeTitle;
  final String remindMeSubtitle;
  final String noBenchmark;

  const NotificationStrings({
    required this.checkInTitle,
    required this.checkInBody,
    required this.actionBetter,
    required this.actionNotYet,
    required this.actionWorse,
    required this.dialogBetter,
    required this.dialogNotYet,
    required this.dialogWorse,
    required this.notYetSnack,
    required this.seeProfessional,
    required this.entryUnavailable,
    required this.guestTitle,
    required this.guestBody,
    required this.guestSignIn,
    required this.remindMeTitle,
    required this.remindMeSubtitle,
    required this.noBenchmark,
  });

  static NotificationStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static NotificationStrings forLanguage(AppLanguage language) =>
      language == AppLanguage.tl ? tl : en;

  /// The strings for the language saved on this device (English if none).
  static Future<NotificationStrings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getString('app_language') == 'tl' ? tl : en;
    } catch (_) {
      return en;
    }
  }

  static const en = NotificationStrings(
    checkInTitle: 'Healing check-in',
    checkInBody: 'Are you feeling better?',
    actionBetter: 'Feeling Better',
    actionNotYet: 'Not Yet',
    actionWorse: 'It\'s Worse',
    dialogBetter: 'Yes, I\'m feeling better',
    dialogNotYet: 'Not yet',
    dialogWorse: 'It\'s getting worse',
    notYetSnack: 'Okay — we\'ll check in again tomorrow.',
    seeProfessional:
        'We recommend getting checked by a healthcare professional.',
    entryUnavailable: 'That journal entry is no longer available.',
    guestTitle: 'Notifications are for signed-in users',
    guestBody:
        'Create an account or log in to see your notifications and get '
        'healing check-ins.',
    guestSignIn: 'Log in or create an account',
    remindMeTitle: 'Remind me',
    remindMeSubtitle: 'Check in with me when the standard healing time is up.',
    noBenchmark:
        'No reminder was set: there is no standard healing time for this '
        'type yet.',
  );

  static const tl = NotificationStrings(
    checkInTitle: 'Pagsusuri sa paggaling',
    checkInBody: 'Bumubuti na ba ang pakiramdam mo?',
    actionBetter: 'Bumubuti na',
    actionNotYet: 'Hindi pa',
    actionWorse: 'Lumalala',
    dialogBetter: 'Oo, bumubuti na ang pakiramdam ko',
    dialogNotYet: 'Hindi pa',
    dialogWorse: 'Lumalala ito',
    notYetSnack: 'Sige — kukumustahin ka namin ulit bukas.',
    seeProfessional:
        'Inirerekomenda naming magpatingin sa isang healthcare professional.',
    entryUnavailable: 'Wala na ang journal entry na iyon.',
    guestTitle: 'Para sa mga naka-sign in ang mga notification',
    guestBody:
        'Gumawa ng account o mag-log in para makita ang iyong mga '
        'notification at makatanggap ng pagsusuri sa paggaling.',
    guestSignIn: 'Mag-log in o gumawa ng account',
    remindMeTitle: 'Paalalahanan ako',
    remindMeSubtitle:
        'Kumustahin ako kapag tapos na ang karaniwang oras ng paggaling.',
    noBenchmark:
        'Walang naitakdang paalala: wala pang karaniwang oras ng paggaling '
        'para sa uri na ito.',
  );
}
