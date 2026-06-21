import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isUsernameTaken(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 10));
    return query.docs.isNotEmpty;
  }

  /// Looks up the real email linked to a username, for sign-in and
  /// password reset purposes (the user never sees or types this email).
  Future<String?> _emailForUsername(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['email'] as String?;
  }

  Future<UserCredential> registerWithUsername({
    required String username,
    required String password,
    required String email,
    required String verificationMethod, // email or phone
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

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
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

  /// Sends a real Firebase password reset email, looked up by username.
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

  Future<bool> hasCompletedOnboarding(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['onboardingComplete'] == true;
  }

  Future<void> markOnboardingComplete(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'onboardingComplete': true,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
