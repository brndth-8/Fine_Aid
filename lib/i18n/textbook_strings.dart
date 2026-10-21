import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Messages for opening a textbook that is loaded from Firebase (shown while
/// it downloads, or when it can't be loaded), English + Tagalog. Review the
/// Tagalog before release.
class TextbookStrings {
  final String downloadingFormat; // {percent}
  final String needsInternet;
  final String notAvailable;
  final String couldNotLoad;

  const TextbookStrings({
    required this.downloadingFormat,
    required this.needsInternet,
    required this.notAvailable,
    required this.couldNotLoad,
  });

  static TextbookStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String downloading(int percent) =>
      downloadingFormat.replaceFirst('{percent}', '$percent');

  static const en = TextbookStrings(
    downloadingFormat: 'Downloading… {percent}%',
    needsInternet:
        'This book needs an internet connection the first time you open it. '
        'After that it stays on your phone.',
    notAvailable:
        'This book isn\'t available right now. Please try again '
        'later.',
    couldNotLoad: 'Could not load PDF. Please try again.',
  );

  static const tl = TextbookStrings(
    downloadingFormat: 'Dina-download… {percent}%',
    needsInternet:
        'Kailangan ng internet ang aklat na ito sa unang pagbukas. Pagkatapos '
        'nito, mananatili na ito sa iyong telepono.',
    notAvailable:
        'Hindi available ang aklat na ito ngayon. Pakisubukan muli mamaya.',
    couldNotLoad: 'Hindi ma-load ang PDF. Pakisubukan muli.',
  );
}
