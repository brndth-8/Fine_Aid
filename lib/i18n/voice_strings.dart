import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Short messages for the voice question feature (recording a spoken
/// question and playing the clip back), English + Tagalog. Review the
/// Tagalog before release.
class VoiceStrings {
  final String tagalogUnavailable;
  final String recordingOnly;
  final String couldNotStart;
  final String backgroundStopped;
  final String couldNotPlay;

  const VoiceStrings({
    required this.tagalogUnavailable,
    required this.recordingOnly,
    required this.couldNotStart,
    required this.backgroundStopped,
    required this.couldNotPlay,
  });

  static VoiceStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = VoiceStrings(
    tagalogUnavailable:
        'A Tagalog voice isn\'t available on this phone, so your phone\'s '
        'default language was used. You can also type your question.',
    recordingOnly:
        'Speech recognition didn\'t start, so the words may not be picked '
        'up. You can also type your question.',
    couldNotStart:
        'Voice input couldn\'t start right now. Please try again, or type '
        'your question instead.',
    backgroundStopped:
        'Recording stopped because the app went to the background.',
    couldNotPlay: 'Couldn\'t play this recording. Please try again.',
  );

  static const tl = VoiceStrings(
    tagalogUnavailable:
        'Walang Tagalog na boses sa teleponong ito, kaya ginamit ang default '
        'na wika ng iyong telepono. Maaari mo ring i-type ang iyong tanong.',
    recordingOnly:
        'Hindi nagsimula ang speech recognition, kaya maaaring hindi '
        'maunawaan ang mga salita. Maaari mo ring i-type ang iyong tanong.',
    couldNotStart:
        'Hindi makapagsimula ang voice input ngayon. Pakisubukan muli, o '
        'i-type na lang ang iyong tanong.',
    backgroundStopped:
        'Huminto ang pag-record dahil napunta ang app sa background.',
    couldNotPlay: 'Hindi mapatugtog ang recording. Pakisubukan muli.',
  );
}
