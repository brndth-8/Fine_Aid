import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vibration/vibration.dart';

/// The vibration for a severe result: long pulses that repeat, like a
/// national emergency alert. Always stopped by [stop] (the pop-up calls it
/// when it closes). Never throws: a phone with no vibrator, a missing plugin
/// (tests) or any error just means no vibration.
class EmergencyAlert {
  EmergencyAlert._();

  /// Wait, buzz, wait, buzz... in milliseconds (the first number is the wait
  /// before the first buzz). Five buzzes and four pauses: 10 seconds in all.
  static const List<int> pattern = [
    0,
    1600,
    500,
    1600,
    500,
    1600,
    500,
    1600,
    500,
    1600,
  ];

  static Future<void> start() async {
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(pattern: pattern);
    } catch (e) {
      debugPrint('EmergencyAlert.start: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('EmergencyAlert.stop: $e');
    }
  }
}
