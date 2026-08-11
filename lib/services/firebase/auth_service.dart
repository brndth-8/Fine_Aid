import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    required String email,
    required String verificationMethod,
    String? phoneNumber,
  }) async {
    final taken = await isUsernameTaken(username);
    if (taken) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'This username is already taken.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (verificationMethod == 'email') {
      await credential.user?.sendEmailVerification();
    }

    final uid = credential.user!.uid;

    await _firestore
        .collection('users')
        .doc(uid)
        .set({
          'username': username.trim(),
          'email': email.trim(),
          'phoneNumber': phoneNumber?.trim(),
          'verificationMethod': verificationMethod,
          'createdAt': FieldValue.serverTimestamp(),
          'phoneVerified': false,
          'emailVerified': false,
          'onboardingComplete': false,
        })
        .timeout(const Duration(seconds: 10));

    await _firestore
        .collection('usernames')
        .doc(username.trim().toLowerCase())
        .set({'email': email.trim(), 'uid': uid})
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
