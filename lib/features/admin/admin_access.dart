import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_two_step.dart';

/// Whether [user]'s sign-in token carries the server-set `admin` claim.
///
/// The token is refreshed first so a claim granted since sign-in (or after a
/// session started before claims existed) is picked up. The claim can only be
/// set by the Admin SDK (functions/scripts/set-admin-claims.js), never from a
/// browser; Firestore rules and the admin Cloud Functions require it too, so
/// this check is just what keeps a non-admin out of the portal screens.
Future<bool> hasAdminClaim(User user) async {
  try {
    final result = await user.getIdTokenResult(true);
    return result.claims?['admin'] == true;
  } catch (_) {
    return false;
  }
}

/// Whether [user] may use the portal as far as two-step verification goes:
/// true when it isn't required, or when this sign-in used an authenticator
/// code. (When it IS required and the sign-in had no code, the admin has to
/// set one up and sign in again; the server and the rules refuse them
/// meanwhile.)
Future<bool> twoStepSatisfied(User user) async {
  if (!await adminTwoStepRequired()) return true;
  try {
    return signedInWithAuthenticator((await user.getIdTokenResult()).claims);
  } catch (_) {
    return false;
  }
}

/// Asks the server to log a sign-in on the admin portal. The server decides
/// whether it was a real admin (success) or someone who shouldn't be here
/// (refused) from the verified token, so this can't be used to fake either.
/// Best-effort and quick: it never blocks or breaks the sign-in.
Future<void> recordAdminSignIn() async {
  try {
    await FirebaseFunctions.instance
        .httpsCallable('recordAdminSignIn')
        .call<Object?>()
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}

/// Logs a failed admin sign-in. Only recorded when the email belongs to an
/// admin (the server checks), and the answer never says whether it did.
/// [firebaseCode] is the FirebaseAuthException code.
Future<void> recordAdminSignInFailure(String email, String firebaseCode) async {
  final reason = switch (firebaseCode) {
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'wrong_password',
    'invalid-verification-code' => 'wrong_code',
    'user-disabled' => 'user_disabled',
    'too-many-requests' => 'too_many_attempts',
    _ => null,
  };
  if (reason == null) return;
  try {
    await FirebaseFunctions.instance
        .httpsCallable('recordAdminSignInFailure')
        .call<Object?>({'email': email.trim(), 'reason': reason})
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}
