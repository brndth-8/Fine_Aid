import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for Offline Mode: the general "unavailable while offline" message, the
/// Health Journal's offline pop-up and the note after an offline save.
/// English + Tagalog. Review the Tagalog before release.
class OfflineStrings {
  /// Shown wherever a feature needs the internet and there is none.
  final String unavailable;

  // Health Journal: the pop-up shown when it is opened offline.
  final String popupTitle;
  final String popupBody;
  final String proceed;

  /// Snack bar after an entry is written offline.
  final String savedOffline;

  // Offline form: the pink note under the top bar.
  final String journalNotice;

  // A text-only entry: the yellow notice and the "Offline Mode" label.
  final String healingNotice;
  final String offlineModeLabel;

  // Health Kit: the notice shown when it is opened in Offline Mode.
  final String kitNoticeTitle;
  final String kitNoticeBody;
  final String understood;

  const OfflineStrings({
    required this.unavailable,
    required this.popupTitle,
    required this.popupBody,
    required this.proceed,
    required this.savedOffline,
    required this.journalNotice,
    required this.healingNotice,
    required this.offlineModeLabel,
    required this.kitNoticeTitle,
    required this.kitNoticeBody,
    required this.understood,
  });

  static OfflineStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = OfflineStrings(
    unavailable: 'This feature is unavailable while you are offline.',
    popupTitle: 'No Internet Connection',
    popupBody:
        'You are currently offline. You can still write journal entries, but '
        'some features are unavailable.',
    proceed: 'Proceed',
    savedOffline:
        'Entry saved on this device. It will sync when you are back online.',
    journalNotice:
        'This health journal is for users who don\'t have an internet '
        'connection. Your journal entries will be saved only in the app.',
    healingNotice:
        'Healing time estimates are currently unavailable.\n'
        'We apologize.\n\n'
        'Due to limited offline functionality, certain health journal '
        'features are temporarily restricted. However, your well-being '
        'remains our top priority. You can still use the journal to log your '
        'symptoms and notes textually.\n\n'
        'Please describe how you are feeling, we are here for you.',
    offlineModeLabel: 'Offline Mode',
    kitNoticeTitle: 'Health Kit',
    kitNoticeBody:
        'This is only for users with no recognized health conditions. If you '
        'have a specific medical condition, we advise you to seek '
        'professional help to ensure you receive specialized care.',
    understood: 'I understand',
  );

  static const tl = OfflineStrings(
    unavailable: 'Hindi magagamit ang feature na ito habang offline ka.',
    popupTitle: 'Walang Koneksyon sa Internet',
    popupBody:
        'Offline ka ngayon. Maaari ka pa ring magsulat ng mga journal entry, '
        'ngunit may ilang feature na hindi magagamit.',
    proceed: 'Magpatuloy',
    savedOffline:
        'Nai-save ang entry sa device na ito. Magsi-sync ito kapag online ka '
        'na ulit.',
    journalNotice:
        'Ang health journal na ito ay para sa mga user na walang koneksyon '
        'sa internet. Ang iyong mga journal entry ay mase-save lamang sa app.',
    healingNotice:
        'Kasalukuyang hindi available ang tantiya ng oras ng paggaling.\n'
        'Humihingi kami ng paumanhin.\n\n'
        'Dahil sa limitadong offline na kakayahan, pansamantalang limitado '
        'ang ilang feature ng health journal. Gayunpaman, ang iyong '
        'kapakanan pa rin ang aming pinakamahalagang priyoridad. Maaari mo '
        'pa ring gamitin ang journal para itala ang iyong mga sintomas at '
        'tala sa anyong teksto.\n\n'
        'Pakilarawan kung ano ang nararamdaman mo, narito kami para sa iyo.',
    offlineModeLabel: 'Offline Mode',
    kitNoticeTitle: 'Health Kit',
    kitNoticeBody:
        'Para lamang ito sa mga user na walang kinikilalang kondisyong '
        'pangkalusugan. Kung mayroon kang partikular na kondisyong medikal, '
        'pinapayuhan ka naming humingi ng propesyonal na tulong upang '
        'makatanggap ng espesyalisadong pangangalaga.',
    understood: 'Naiintindihan ko',
  );
}
