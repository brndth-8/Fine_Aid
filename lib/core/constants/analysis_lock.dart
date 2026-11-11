/// Lets only ONE image analysis (the photo check and the wound assessment, both
/// sent to Gemini) run at a time, so a double-tap or a second request can never
/// start a duplicate call. A small class of static members. Whoever gets the lock must release it in a `finally`.
class AnalysisLock {
  AnalysisLock._();

  static bool _held = false;

  /// True while an analysis is running.
  static bool get isBusy => _held;

  /// Takes the lock. False (and nothing changes) when it is already taken.
  static bool tryAcquire() {
    if (_held) return false;
    _held = true;
    return true;
  }

  /// Gives the lock back. Safe to call more than once.
  static void release() => _held = false;
}
