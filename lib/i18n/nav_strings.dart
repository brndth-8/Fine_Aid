import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Labels of the Dashboard's bottom navigation bar, English + Tagalog.
/// Review the Tagalog before release.
class NavStrings {
  final String healthJournal;
  final String aiVisionCamera;
  final String helpAndSupport;

  const NavStrings({
    required this.healthJournal,
    required this.aiVisionCamera,
    required this.helpAndSupport,
  });

  static NavStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = NavStrings(
    healthJournal: 'Health Journal',
    aiVisionCamera: 'AI Vision Camera',
    helpAndSupport: 'Help and Support',
  );

  static const tl = NavStrings(
    healthJournal: 'Health Journal',
    aiVisionCamera: 'AI Vision Camera',
    helpAndSupport: 'Tulong at Suporta',
  );
}
