import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'email_reservation.dart';

/// Why a sign-up did not complete. The screen turns each one into its own
/// message (see RegistrationStrings) instead of one generic "went wrong".
enum RegistrationError {
  /// Someone else's complete account already uses this username.
  usernameTaken,

  /// The sign-in account for this username exists, but it is not ours to
  /// finish (different password) or it already belongs to a verified user.
  alreadyRegistered,

  /// Another account already uses this email address.
  emailTaken,

  /// No connection, so nothing could be saved.
  network,

  /// The connection was too slow and the step gave up waiting.
  timeout,
  weakPassword,
  tooManyRequests,

  /// The server refused to store the profile.
  saveFailed,
  unknown,
}

class RegistrationException implements Exception {
  const RegistrationException(this.error, [this.cause]);

  final RegistrationError error;
  final Object? cause;

  @override
  String toString() => 'RegistrationException($error, $cause)';
}

/// What the server says about a user's profile document.
class RegistrationProfile {
  const RegistrationProfile({
    required this.exists,
    required this.markedComplete,
    required this.hasProgress,
  });

  final bool exists;

  /// `registrationComplete == true` — written together with the username
  /// reservation, in one transaction.
  final bool markedComplete;

  /// The person already verified their phone or finished onboarding, so this
  /// is a real, in-use account that must never be re-registered over.
  final bool hasProgress;
}

/// The Firebase calls registration needs, kept behind an interface so the
/// all-or-nothing logic below can be tested without Firebase.
abstract class RegistrationBackend {
  /// uid that owns [username] in the public `usernames` collection, or null
  /// when it is free. Throws (never returns "free") if it cannot be read.
  Future<String?> usernameOwner(String username);

  /// Creates the sign-in account and leaves it signed in. Returns its uid.
  Future<String> createAuthUser(String email, String password);

  /// Signs in and returns the uid.
  Future<String> signIn(String email, String password);

  /// Reads the profile from the server (not the cache).
  Future<RegistrationProfile> readProfile(String uid);

  /// One transaction: if [username] belongs to someone else returns false and
  /// writes nothing; otherwise writes `users/{uid}` (with
  /// `registrationComplete: true`) and `usernames/{username}` together.
  Future<bool> claim({
    required String uid,
    required String username,
    required String email,
    required Map<String, Object?> profile,
  });

  Future<void> deleteCurrentAuthUser();
  Future<void> signOut();
}

/// All-or-nothing registration.
///
/// The sign-in account and the Firestore documents cannot share a single
/// transaction, so the order is chosen so that every failure leaves nothing
/// half-made that anyone else can see or trip over:
///
///  1. Check the username and the password-less parts first; create nothing.
///  2. Create the sign-in account.
///  3. Write the profile and the username reservation in ONE transaction. A
///     transaction fails when offline (a plain write would queue and land
///     later, which is what used to create "failed" sign-ups that appeared
///     anyway), and the username can't be claimed twice.
///  4. If step 3 definitely did not happen, delete the sign-in account and
///     sign out. If the outcome is unknown (timeout, still offline) the
///     account is kept and the next attempt with the same password simply
///     continues — it never reports the person's own attempt as "taken".
class RegistrationFlow {
  RegistrationFlow(
    this.backend, {
    this.authTimeout = const Duration(seconds: 20),
    this.stepTimeout = const Duration(seconds: 15),
    this.claimTimeout = const Duration(seconds: 25),
  });

  final RegistrationBackend backend;
  final Duration authTimeout;
  final Duration stepTimeout;
  final Duration claimTimeout;

  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@fineaid.app';

  Future<void> register({
    required String username,
    required String password,
    required String phoneNumber,
    String? recoveryEmail,
    String verificationMethod = 'phone',
    // Personal details (all optional here so older callers keep working).
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    bool underageAcknowledged = false,
  }) async {
    final name = username.trim();
    final email = emailFor(name);

    // 1. Nothing is created until this passes.
    String? owner;
    try {
      owner = await backend.usernameOwner(name).timeout(stepTimeout);
    } catch (e) {
      throw _map(e);
    }

    String uid;
    var resumed = false;
    if (owner != null) {
      // Taken — but it may be this very person's earlier attempt that did
      // finish on the server while the app gave up waiting.
      final mine = await _trySignIn(email, password);
      if (mine == null || mine != owner) {
        await _quietSignOut();
        throw const RegistrationException(RegistrationError.usernameTaken);
      }
      uid = mine;
      resumed = true;
    } else {
      try {
        uid = await backend
            .createAuthUser(email, password)
            .timeout(authTimeout);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') throw _map(e);
        // An unfinished sign-up of this username (or one that differs only
        // by letter case). Ours only if the password matches.
        final mine = await _trySignIn(email, password);
        if (mine == null) {
          throw const RegistrationException(
            RegistrationError.alreadyRegistered,
          );
        }
        uid = mine;
        resumed = true;
      } on TimeoutException {
        // The account may have been created just as we gave up.
        final mine = await _trySignIn(email, password);
        if (mine == null) {
          throw const RegistrationException(RegistrationError.timeout);
        }
        uid = mine;
      } catch (e) {
        throw _map(e);
      }
    }

    // A pre-existing sign-in account: see what is already saved for it.
    if (resumed) {
      final RegistrationProfile profile;
      try {
        profile = await backend.readProfile(uid).timeout(stepTimeout);
      } catch (e) {
        await _quietSignOut();
        throw _map(e);
      }
      if (profile.hasProgress) {
        // A real, in-use account — never register over it.
        await _quietSignOut();
        throw const RegistrationException(RegistrationError.alreadyRegistered);
      }
      if (profile.markedComplete) {
        // Our earlier attempt did finish. Carry on to verification.
        return;
      }
    }

    // 3. One transaction for the profile and the username.
    // Stored trimmed and lower-case, the same way the email reservation is
    // keyed (see EmailReservation).
    final trimmedRecovery = recoveryEmail == null
        ? null
        : normalizeEmail(recoveryEmail);
    final profile = <String, Object?>{
      'username': name,
      'email': email,
      if (trimmedRecovery != null && trimmedRecovery.isNotEmpty)
        'recoveryEmail': trimmedRecovery,
      'phoneNumber': phoneNumber.trim(),
      'verificationMethod': verificationMethod,
      'phoneVerified': false,
      'onboardingComplete': false,
      // New fields are only written when given, so nothing existing changes.
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
      if (dateOfBirth != null)
        'dateOfBirth': Timestamp.fromDate(
          DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day),
        ),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (underageAcknowledged) ...{
        'underageAcknowledged': true,
        'underageAcknowledgedAt': FieldValue.serverTimestamp(),
      },
    };

    Object? failure;
    var claimed = false;
    try {
      claimed = await backend
          .claim(uid: uid, username: name, email: email, profile: profile)
          .timeout(claimTimeout);
      if (claimed) return;
    } catch (e) {
      failure = e;
    }

    if (!claimed && failure == null) {
      // Someone else claimed the username in the meantime.
      await _rollback();
      throw const RegistrationException(RegistrationError.usernameTaken);
    }

    // The email belongs to another account: nothing was saved, so remove the
    // sign-in account made for this attempt and say so.
    if (failure is RegistrationException &&
        failure.error == RegistrationError.emailTaken) {
      await _rollback();
      throw failure;
    }

    // 4. The transaction threw. Did it commit anyway?
    final definitive =
        failure is FirebaseException && failure.code == 'permission-denied';
    if (definitive) {
      await _rollback();
      throw _map(failure);
    }
    try {
      final saved = await backend.readProfile(uid).timeout(stepTimeout);
      if (saved.markedComplete) return; // it did commit
      await _rollback(); // read the server: nothing was saved
    } catch (_) {
      // Cannot tell. Keep the sign-in account (the next attempt continues
      // from it) and just sign out.
      await _quietSignOut();
    }
    throw _map(failure);
  }

  Future<String?> _trySignIn(String email, String password) async {
    try {
      return await backend.signIn(email, password).timeout(authTimeout);
    } on FirebaseAuthException catch (e) {
      const wrongCredentials = {
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-email',
      };
      if (wrongCredentials.contains(e.code)) return null;
      throw _map(e);
    } on TimeoutException {
      throw const RegistrationException(RegistrationError.timeout);
    }
  }

  Future<void> _rollback() async {
    try {
      await backend.deleteCurrentAuthUser().timeout(stepTimeout);
    } catch (_) {
      // Left behind at worst as a sign-in account with no profile: invisible
      // to the Admin portal, and the next attempt with the same password
      // continues from it.
    }
    await _quietSignOut();
  }

  Future<void> _quietSignOut() async {
    try {
      await backend.signOut().timeout(stepTimeout);
    } catch (_) {}
  }

  static RegistrationException _map(Object? e) {
    if (e is RegistrationException) return e;
    if (e is TimeoutException) {
      return RegistrationException(RegistrationError.timeout, e);
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'network-request-failed':
          return RegistrationException(RegistrationError.network, e);
        case 'weak-password':
          return RegistrationException(RegistrationError.weakPassword, e);
        case 'too-many-requests':
          return RegistrationException(RegistrationError.tooManyRequests, e);
        case 'email-already-in-use':
          return RegistrationException(RegistrationError.alreadyRegistered, e);
      }
      return RegistrationException(RegistrationError.unknown, e);
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unavailable':
        case 'network-request-failed':
          return RegistrationException(RegistrationError.network, e);
        case 'deadline-exceeded':
          return RegistrationException(RegistrationError.timeout, e);
        case 'permission-denied':
          return RegistrationException(RegistrationError.saveFailed, e);
      }
    }
    return RegistrationException(RegistrationError.unknown, e);
  }
}

/// The real Firebase implementation.
class FirebaseRegistrationBackend implements RegistrationBackend {
  FirebaseRegistrationBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<String?> usernameOwner(String username) async {
    final exact = await _firestore.collection('usernames').doc(username).get();
    if (exact.exists) return exact.data()?['uid'] as String? ?? '';

    // Accounts made before usernames became case-sensitive are stored under
    // the lowercased name, with the typed case kept in `usernameExact`.
    final lower = username.toLowerCase();
    if (lower == username) return null;
    final legacy = await _firestore.collection('usernames').doc(lower).get();
    if (legacy.exists && legacy.data()?['usernameExact'] == username) {
      return legacy.data()?['uid'] as String? ?? '';
    }
    return null;
  }

  @override
  Future<String> createAuthUser(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<String> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<RegistrationProfile> readProfile(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    return RegistrationProfile(
      exists: doc.exists,
      markedComplete: data?['registrationComplete'] == true,
      hasProgress:
          data?['phoneVerified'] == true || data?['onboardingComplete'] == true,
    );
  }

  @override
  Future<bool> claim({
    required String uid,
    required String username,
    required String email,
    required Map<String, Object?> profile,
  }) {
    final names = _firestore.collection('usernames');
    return _firestore.runTransaction<bool>(
      (tx) async {
        final exactRef = names.doc(username);
        final exact = await tx.get(exactRef);
        if (exact.exists && exact.data()?['uid'] != uid) return false;

        final lower = username.toLowerCase();
        if (lower != username) {
          final legacy = await tx.get(names.doc(lower));
          if (legacy.exists &&
              legacy.data()?['usernameExact'] == username &&
              legacy.data()?['uid'] != uid) {
            return false;
          }
        }

        // One account per email: the reservation is claimed in this same
        // transaction (all reads first), and the rules refuse a profile with
        // an email it doesn't hold.
        final applyEmail = await EmailReservation.prepare(
          tx,
          _firestore,
          uid: uid,
          newEmail: profile['recoveryEmail'] as String?,
        ).onError<EmailTakenException>(
          (e, _) => throw const RegistrationException(
            RegistrationError.emailTaken,
          ),
        );

        tx.set(_firestore.collection('users').doc(uid), {
          ...profile,
          'createdAt': FieldValue.serverTimestamp(),
          'registrationComplete': true,
        });
        applyEmail();
        tx.set(exactRef, {
          'email': email,
          'uid': uid,
          'usernameExact': username,
        });
        return true;
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 2,
    );
  }

  @override
  Future<void> deleteCurrentAuthUser() async {
    await _auth.currentUser?.delete();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
