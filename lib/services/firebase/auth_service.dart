import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _emailFromUsername(String username) {
    final normalized = username.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    return '$normalized@fineaid.app';
  }

  Future<bool> isUsernameTaken(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<UserCredential> registerWithUsername({
    required String username,
    required String password,
  }) async {
    final taken = await isUsernameTaken(username);
    if (taken) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'This username is already taken.',
      );
    }

    final email = _emailFromUsername(username);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(credential.user!.uid).set({
      'username': username.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'phoneVerified': false,
    });

    return credential;
  }

  Future<UserCredential> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _emailFromUsername(username);
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
