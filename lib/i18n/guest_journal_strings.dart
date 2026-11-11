import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for journal entries written in Guest Mode (kept on the phone, then
/// moved into the account at sign-up), English + Tagalog. Review the Tagalog
/// before release.
class GuestJournalStrings {
  /// The Guest Mode pop-up on the Add Entry screen.
  final String warning;

  /// Snack bar after a guest saves an entry.
  final String savedOnDevice;

  /// Small tag on an entry that is only on this phone.
  final String onThisDevice;

  /// After sign-up / sign-in moved entries into the account. {n} = count.
  final String movedOne;
  final String movedMany;

  const GuestJournalStrings({
    required this.warning,
    required this.savedOnDevice,
    required this.onThisDevice,
    required this.movedOne,
    required this.movedMany,
  });

  static GuestJournalStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String moved(int n) =>
      (n == 1 ? movedOne : movedMany).replaceFirst('{n}', '$n');

  static const en = GuestJournalStrings(
    warning:
        'You are currently in Guest Mode. Journal entries are saved on this '
        'device only, without photos.\n\nCreate an account to keep them '
        'safely: they will be moved into your journal.',
    savedOnDevice:
        'Entry saved on this device. Create an account to keep it in your '
        'journal.',
    onThisDevice: 'On this device',
    movedOne: '{n} journal entry from Guest Mode was added to your journal.',
    movedMany:
        '{n} journal entries from Guest Mode were added to your journal.',
  );

  static const tl = GuestJournalStrings(
    warning:
        'Nasa Guest Mode ka ngayon. Ang mga journal entry ay naka-save sa '
        'device na ito lamang, at walang litrato.\n\nGumawa ng account para '
        'mapanatili ang mga ito nang ligtas: ililipat ang mga ito sa iyong '
        'journal.',
    savedOnDevice:
        'Nai-save ang entry sa device na ito. Gumawa ng account para '
        'mapanatili ito sa iyong journal.',
    onThisDevice: 'Nasa device na ito',
    movedOne:
        'Naidagdag sa iyong journal ang {n} journal entry mula sa Guest Mode.',
    movedMany:
        'Naidagdag sa iyong journal ang {n} journal entry mula sa Guest Mode.',
  );
}
