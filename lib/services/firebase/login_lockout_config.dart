import 'package:cloud_firestore/cloud_firestore.dart';

/// The failed-login lockout the admin sets on the System Security page:
/// whether it is on, how many wrong passwords are allowed, and how long the
/// account is then locked. The sign-in screen reads it before every attempt,
/// so a change applies straight away.
///
/// It is read from `appConfig/loginSecurity` (a public, read-only copy; the
/// sign-in screen runs before anyone is signed in). If it can't be read
/// (offline, slow, never set), the long-standing defaults apply: on, 5 wrong
/// passwords, 15 minutes.
class LoginLockoutConfig {
  const LoginLockoutConfig({
    required this.enabled,
    required this.maxAttempts,
    required this.minutes,
  });

  static const defaults = LoginLockoutConfig(
    enabled: true,
    maxAttempts: 5,
    minutes: 15,
  );

  static const allowedAttempts = [3, 5, 10];
  static const allowedMinutes = [5, 15, 30, 60];

  final bool enabled;
  final int maxAttempts;
  final int minutes;

  Duration get lockDuration => Duration(minutes: minutes);

  /// True when [failedAttempts] wrong passwords are enough to lock the account.
  bool shouldLock(int failedAttempts) =>
      enabled && failedAttempts >= maxAttempts;

  /// Anything missing or not one of the allowed values uses the default.
  factory LoginLockoutConfig.fromData(Map<String, dynamic>? data) {
    final enabled = data?['lockoutEnabled'];
    final attempts = data?['lockoutMaxAttempts'];
    final minutes = data?['lockoutMinutes'];
    return LoginLockoutConfig(
      enabled: enabled is bool ? enabled : defaults.enabled,
      maxAttempts: attempts is int && allowedAttempts.contains(attempts)
          ? attempts
          : defaults.maxAttempts,
      minutes: minutes is int && allowedMinutes.contains(minutes)
          ? minutes
          : defaults.minutes,
    );
  }

  /// Reads the current setting (never throws, never waits long).
  static Future<LoginLockoutConfig> load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc('appConfig/loginSecurity')
          .get()
          .timeout(const Duration(seconds: 3));
      return LoginLockoutConfig.fromData(snap.data());
    } catch (_) {
      return defaults;
    }
  }
}
