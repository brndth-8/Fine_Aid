import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usernames are case-insensitive: "johndoe" and "JohnDoe" are the same
  // account. The lookup key is always the lowercased form, so this matches
  // regardless of how the username was typed — `usernameExact` (stored at
  // registration) is kept only for display purposes elsewhere, never used
  // to gate sign-in.
  Future<String?> _emailForUsername(String username) async {
    try {
      final doc = await _firestore
          .collection('usernames')
          .doc(username.trim().toLowerCase())
          .get();
      if (!doc.exists) return null;
      return doc.data()?['email'] as String?;
    } catch (e) {
      debugPrint('_emailForUsername error: $e');
      return null;
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      final doc = await _firestore
          .collection('usernames')
          .doc(username.trim().toLowerCase())
          .get()
          .timeout(const Duration(seconds: 10));
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<UserCredential> registerWithUsername({
    required String username,
    required String password,
    required String phoneNumber,
    // Optional — a real address the user can additionally use for account
    // recovery via Forgot Password's email option. Never used as the
    // Firebase Auth login email itself (that's always the generated
    // username@fineaid.app one below), so leaving it out just means that
    // recovery option stays unavailable until it's added, here or later
    // from Edit Profile.
    String? recoveryEmail,
    // 'phone' (default) or 'email' — which channel OtpScreen verifies
    // this account through right after registration. 'email' requires
    // recoveryEmail to be set, since that's where the code goes.
    String verificationMethod = 'phone',
  }) async {
    final taken = await isUsernameTaken(username);
    if (taken) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'This username is already taken.',
      );
    }

    // Auto-generate email from username — never shown to user
    final generatedEmail = '${username.trim().toLowerCase()}@fineaid.app';

    final credential = await _auth.createUserWithEmailAndPassword(
      email: generatedEmail,
      password: password,
    );

    final uid = credential.user!.uid;
    final trimmedRecoveryEmail = recoveryEmail?.trim();

    // Write full profile to users collection
    await _firestore
        .collection('users')
        .doc(uid)
        .set({
          'username': username.trim(),
          'email': generatedEmail,
          if (trimmedRecoveryEmail != null && trimmedRecoveryEmail.isNotEmpty)
            'recoveryEmail': trimmedRecoveryEmail,
          'phoneNumber': phoneNumber.trim(),
          'verificationMethod': verificationMethod,
          'createdAt': FieldValue.serverTimestamp(),
          'phoneVerified': false,
          'onboardingComplete': false,
        })
        .timeout(const Duration(seconds: 10));

    // Write to public usernames collection. `usernameExact` preserves the
    // case the user actually registered with, so sign-in can require it to
    // match exactly even though the doc ID itself is lowercased.
    await _firestore
        .collection('usernames')
        .doc(username.trim().toLowerCase())
        .set({
          'email': generatedEmail,
          'uid': uid,
          'usernameExact': username.trim(),
        })
        .timeout(const Duration(seconds: 10));

    return credential;
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

  /// Fetches every per-step onboarding flag for [uid] in a single read, so
  /// the app can resume onboarding at whichever step is actually
  /// incomplete instead of restarting the whole flow (eg, from OTP) every
  /// time the user reopens the app mid-setup.
  Future<Map<String, bool>> fetchOnboardingFlags(String uid) async {
    const defaults = {
      'phoneVerified': true,
      'termsAccepted': true,
      'permissionStepComplete': true,
      'healthProfileComplete': true,
      'onboardingComplete': true,
    };

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      if (data == null) return defaults;

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
    } catch (_) {
      return defaults;
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

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
