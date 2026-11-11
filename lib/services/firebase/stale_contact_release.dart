import 'package:cloud_functions/cloud_functions.dart';

/// Asks the server (Cloud Function `releaseStaleContact`) to free a phone
/// number or email ([kind]: 'phone' or 'email') that is "already registered"
/// but held by a ghost: a sign-up that was never finished, or an account that
/// no longer exists. A finished, in-use account is never touched. True when
/// the number/email is now free; false when it really is in use, or when the
/// server could not be asked.
Future<bool> askServerToReleaseContact(String kind, String value) async {
  try {
    final result = await FirebaseFunctions.instance
        .httpsCallable('releaseStaleContact')
        .call<Map<Object?, Object?>>({'kind': kind, 'value': value})
        .timeout(const Duration(seconds: 12));
    return result.data['released'] == true;
  } catch (_) {
    return false;
  }
}
