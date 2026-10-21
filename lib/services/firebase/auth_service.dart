import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'registration_flow.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usernames are case-sensitive: "Juan" and "juan" are different accounts.
  // New registrations reserve their doc under the exact-case username
  // itself (`usernames/{exactUsername}`). Accounts created before this
  // change still have their doc under the lowercased form (with the
  // originally-typed case preserved in `usernameExact`) — those are only
  // matched when the exact case typed at login matches `usernameExact`,
  // so a legacy account's sign-in behavior doesn't change, but a new
  // "juan" no longer silently resolves to an existing "Juan" account.
  Future<String?> _emailForUsername(String username) async {
    final trimmed = username.trim();
    try {
      final exactDoc = await _firestore
          .collection('usernames')
          .doc(trimmed)
          .get();
      if (exactDoc.exists) {
        return exactDoc.data()?['email'] as String?;
      }

      final legacyDoc = await _firestore
          .collection('usernames')
          .doc(trimmed.toLowerCase())
          .get();
      if (legacyDoc.exists && legacyDoc.data()?['usernameExact'] == trimmed) {
        return legacyDoc.data()?['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('_emailForUsername error: $e');
      return null;
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    final trimmed = username.trim();
    try {
      final exactDoc = await _firestore
          .collection('usernames')
          .doc(trimmed)
          .get()
          .timeout(const Duration(seconds: 10));
      if (exactDoc.exists) return true;

      final legacyDoc = await _firestore
          .collection('usernames')
          .doc(trimmed.toLowerCase())
          .get()
          .timeout(const Duration(seconds: 10));
      return legacyDoc.exists && legacyDoc.data()?['usernameExact'] == trimmed;
    } catch (_) {
      return false;
    }
  }

  // While a sign-up is running, the auth-state change that createUser causes
  // must not send AuthGate to the app: the profile document does not exist
  // yet, and a missing profile reads as "fully onboarded". fetchOnboardingFlags
  // waits for this first. After a successful sign-up the hold stays until the
  // Sign Up screen calls [releaseRegistrationHold] (once it has gone back to
  // the root, so the verification step starts on top of a clean screen).
  static Completer<void>? _registrationHold;

  static void releaseRegistrationHold() {
    final hold = _registrationHold;
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  /// All-or-nothing sign-up — see [RegistrationFlow]. Throws a
  /// [RegistrationException] saying which step failed.
  Future<void> registerWithUsername({
    required String username,
    required String password,
    required String phoneNumber,
    // Optional — a real address the user can additionally use for account
    // recovery via Forgot Password's email option. Never used as the
    // Firebase Auth login email itself (that's always the generated
    // username@fineaid.app one), so leaving it out just means that
    // recovery option stays unavailable until it's added, here or later
    // from Edit Profile.
    String? recoveryEmail,
    // 'phone' (default) or 'email' — which channel OtpScreen verifies
    // this account through right after registration. 'email' requires
    // recoveryEmail to be set, since that's where the code goes.
    String verificationMethod = 'phone',
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    bool underageAcknowledged = false,
  }) {
    releaseRegistrationHold();
    final hold = _registrationHold = Completer<void>();
    final run =
        RegistrationFlow(
          FirebaseRegistrationBackend(auth: _auth, firestore: _firestore),
        ).register(
          username: username,
          password: password,
          phoneNumber: phoneNumber,
          recoveryEmail: recoveryEmail,
          verificationMethod: verificationMethod,
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: dateOfBirth,
          gender: gender,
          underageAcknowledged: underageAcknowledged,
        );
    // A failed sign-up has nothing to hold the gate for.
    run.catchError((_) {
      if (!hold.isCompleted) hold.complete();
    });
    return run;
  }

  Future<UserCredential> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final email = await _emailForUsername(username);
    if (email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found with that username.',
      );
    }
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordReset({required String username}) async {
    final email = await _emailForUsername(username);
    if (email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found with that username.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<bool> hasCompletedOnboarding(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists) {
        return doc.data()?['onboardingComplete'] == true;
      }
    } catch (_) {}

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.data()?['onboardingComplete'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> markOnboardingComplete(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'onboardingComplete': true,
    });
  }

  static const Map<String, bool> _onboardingFlagDefaults = {
    'phoneVerified': true,
    'termsAccepted': true,
    'permissionStepComplete': true,
    'healthProfileComplete': true,
    'onboardingComplete': true,
  };

  Map<String, bool> _onboardingFlagsFromData(Map<String, dynamic>? data) {
    if (data == null) return _onboardingFlagDefaults;

    // Users onboarded before per-step tracking existed only ever had
    // `onboardingComplete`; grandfather them in rather than forcing them
    // back through Terms/Permission/Health Profile retroactively.
    final legacyComplete = data['onboardingComplete'] == true;

    return {
      'phoneVerified': data['phoneVerified'] == true,
      'termsAccepted': legacyComplete || data['termsAccepted'] == true,
      'permissionStepComplete':
          legacyComplete || data['permissionStepComplete'] == true,
      'healthProfileComplete':
          legacyComplete || data['healthProfileComplete'] == true,
      'onboardingComplete': legacyComplete,
    };
  }

  /// Fetches every per-step onboarding flag for [uid] in a single read, so
  /// the app can resume onboarding at whichever step is actually
  /// incomplete instead of restarting the whole flow (eg, from OTP) every
  /// time the user reopens the app mid-setup.
  ///
  /// Tries the on-device cache first — instant, no network wait — so app
  /// launch stays fast offline; only falls through to a live (short-
  /// timeout) read when there's no cache yet (eg the very first launch on
  /// a device, before anything has ever synced).
  Future<Map<String, bool>> fetchOnboardingFlags(String uid) async {
    await _registrationHold?.future;
    try {
      final cacheDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (cacheDoc.exists) {
        return _onboardingFlagsFromData(cacheDoc.data());
      }
    } catch (_) {
      // No cache yet — fall through to a live read below.
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      return _onboardingFlagsFromData(doc.data());
    } catch (_) {
      return _onboardingFlagDefaults;
    }
  }

  Future<bool> isAdmin(String uid) async {
    try {
      debugPrint('Checking admin for uid: $uid');
      final doc = await _firestore
          .collection('admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      debugPrint('Admin doc exists: ${doc.exists}');
      return doc.exists;
    } catch (e) {
      debugPrint('isAdmin error: $e');
      return false;
    }
  }

  /// Whether the user's account is deactivated — either flagged outright, or
  /// its scheduled deactivation date (set by an admin after a grace period)
  /// has passed. Fails open: a read error or a missing profile (eg an admin
  /// account, which has no `users` doc) never locks anyone out.
  Future<bool> isAccountDeactivated(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      if (data == null) return false;
      if (data['deactivated'] == true) return true;
      final deactivateAt = data['deactivateAt'];
      return deactivateAt is Timestamp &&
          !deactivateAt.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Whether the signed-in admin [uid] must change their password before
  /// reaching the dashboard (set by the seed_admin script for newly created
  /// accounts). Defaults to false — including on read errors — so a lookup
  /// hiccup can never lock an existing admin out of their own dashboard.
  Future<bool> adminMustChangePassword(String uid) async {
    try {
      final doc = await _firestore
          .collection('admins')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.data()?['mustChangePassword'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Clears the forced-password-change flag after the admin sets their own
  /// password. Firestore rules only allow an admin to flip this one field
  /// on their own doc to false — nothing else.
  Future<void> clearAdminMustChangePassword(String uid) async {
    await _firestore.collection('admins').doc(uid).update({
      'mustChangePassword': false,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
