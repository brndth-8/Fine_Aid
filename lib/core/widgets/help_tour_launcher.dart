import 'package:flutter/foundation.dart';

/// Lightweight signal used to re-open the Help Tour from a screen (like
/// Help & Support) that isn't the Dashboard itself. The Dashboard listens
/// for this and shows its tour overlay; nothing else needs to know how
/// the tour is implemented.
class HelpTourLauncher {
  HelpTourLauncher._();
  static final HelpTourLauncher instance = HelpTourLauncher._();

  final ValueNotifier<int> requestToken = ValueNotifier<int>(0);

  void requestTour() => requestToken.value++;
}
