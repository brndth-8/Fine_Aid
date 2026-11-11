import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase/login_lockout_config.dart';
import 'admin_config.dart';

/// The security settings an admin can change on the System Security page:
///  - the idle session timeout (on/off and how many idle minutes), applied by
///    this admin portal;
///  - the failed-login lockout (on/off, how many wrong passwords, how many
///    minutes locked), applied by the app's sign-in screen.
/// They live in Firestore (adminSettings/security), are read live by every
/// open admin portal, and are written only by the updateSecuritySettings
/// Cloud Function, which validates and audit-logs each change.
class AdminSecuritySettings {
  const AdminSecuritySettings({
    required this.idleTimeoutEnabled,
    required this.idleTimeoutMinutes,
    this.lockoutEnabled = true,
    this.lockoutMaxAttempts = 5,
    this.lockoutMinutes = 15,
  });

  /// Choices on the page (the function accepts only these).
  static const allowedMinutes = [5, 10, 15, 30, 60];
  static const allowedLockoutAttempts = LoginLockoutConfig.allowedAttempts;
  static const allowedLockoutMinutes = LoginLockoutConfig.allowedMinutes;

  /// What applies until someone changes it: both on, with the defaults from
  /// admin_config.dart and the sign-in screen's long-standing 5 / 15.
  static final defaults = AdminSecuritySettings(
    idleTimeoutEnabled: true,
    idleTimeoutMinutes: kAdminIdleTimeout.inMinutes,
    lockoutEnabled: LoginLockoutConfig.defaults.enabled,
    lockoutMaxAttempts: LoginLockoutConfig.defaults.maxAttempts,
    lockoutMinutes: LoginLockoutConfig.defaults.minutes,
  );

  final bool idleTimeoutEnabled;
  final int idleTimeoutMinutes;
  final bool lockoutEnabled;
  final int lockoutMaxAttempts;
  final int lockoutMinutes;

  Duration get idleTimeout => Duration(minutes: idleTimeoutMinutes);

  /// Reads a saved document, falling back to the defaults for anything
  /// missing or not one of the allowed values.
  factory AdminSecuritySettings.fromData(Map<String, dynamic>? data) {
    final enabled = data?['idleTimeoutEnabled'];
    final minutes = data?['idleTimeoutMinutes'];
    final lock = LoginLockoutConfig.fromData(data);
    return AdminSecuritySettings(
      idleTimeoutEnabled: enabled is bool
          ? enabled
          : defaults.idleTimeoutEnabled,
      idleTimeoutMinutes: minutes is int && allowedMinutes.contains(minutes)
          ? minutes
          : defaults.idleTimeoutMinutes,
      lockoutEnabled: lock.enabled,
      lockoutMaxAttempts: lock.maxAttempts,
      lockoutMinutes: lock.minutes,
    );
  }

  /// Live settings. Errors end the stream (callers keep showing the defaults).
  static Stream<AdminSecuritySettings> watch() => FirebaseFirestore.instance
      .doc('adminSettings/security')
      .snapshots()
      .map((snap) => AdminSecuritySettings.fromData(snap.data()));

  /// Saves through the Cloud Function and returns every setting as it now
  /// stands. Send the idle group, the lockout group, or both (each group
  /// complete). Throws if it could not be applied, so callers only report
  /// success after it is.
  static Future<AdminSecuritySettings> save({
    bool? idleTimeoutEnabled,
    int? idleTimeoutMinutes,
    bool? lockoutEnabled,
    int? lockoutMaxAttempts,
    int? lockoutMinutes,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('updateSecuritySettings')
        .call<Map<Object?, Object?>>({
          'idleTimeoutEnabled': ?idleTimeoutEnabled,
          'idleTimeoutMinutes': ?idleTimeoutMinutes,
          'lockoutEnabled': ?lockoutEnabled,
          'lockoutMaxAttempts': ?lockoutMaxAttempts,
          'lockoutMinutes': ?lockoutMinutes,
        });
    return AdminSecuritySettings.fromData({
      for (final e in result.data.entries) e.key as String: e.value,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is AdminSecuritySettings &&
      other.idleTimeoutEnabled == idleTimeoutEnabled &&
      other.idleTimeoutMinutes == idleTimeoutMinutes &&
      other.lockoutEnabled == lockoutEnabled &&
      other.lockoutMaxAttempts == lockoutMaxAttempts &&
      other.lockoutMinutes == lockoutMinutes;

  @override
  int get hashCode => Object.hash(
    idleTimeoutEnabled,
    idleTimeoutMinutes,
    lockoutEnabled,
    lockoutMaxAttempts,
    lockoutMinutes,
  );
}
