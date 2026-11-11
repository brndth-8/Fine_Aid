import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

/// Phone (SMS) verification codes. The app holds no SMS key and no code: the
/// Cloud Functions send the text (the Semaphore key is a server secret) and
/// check the code, then mark the account verified.
///
///  * `sendAccountVerificationOtpSms` — sends the code.
///  * `verifyAccountVerificationOtp`  — checks it (also used for email codes).
class SemaphoreService {
  static final SemaphoreService _instance = SemaphoreService._internal();
  factory SemaphoreService() => _instance;
  SemaphoreService._internal();

  /// Sends a code to [phoneNumber] ("+639..." / "09..."). True when the SMS
  /// was handed to the carrier; false for any failure (not signed in, bad
  /// number, asked too often, SMS service refused).
  Future<bool> sendOtp({required String phoneNumber}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('SemaphoreService: no user logged in');
      return false;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendAccountVerificationOtpSms')
          .call({'phoneNumber': phoneNumber});
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('SemaphoreService sendOtp: ${e.code}');
      return false;
    }
  }

  /// Checks [code] on the server. On success the server also marks the
  /// account's phone verified and deletes the code.
  Future<OtpVerificationResult> verifyOtp({required String code}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return OtpVerificationResult.error;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyAccountVerificationOtp')
          .call({'code': code.trim()});
      return OtpVerificationResult.success;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('SemaphoreService verifyOtp: ${e.code}');
      return resultForCode(e.code);
    } catch (e) {
      debugPrint('SemaphoreService verifyOtp error: $e');
      return OtpVerificationResult.error;
    }
  }

  /// How the server's error code reads in the app.
  @visibleForTesting
  static OtpVerificationResult resultForCode(String code) {
    switch (code) {
      case 'permission-denied':
        return OtpVerificationResult.invalid;
      case 'deadline-exceeded':
        return OtpVerificationResult.expired;
      case 'resource-exhausted':
        return OtpVerificationResult.tooManyAttempts;
      case 'not-found':
        return OtpVerificationResult.notFound;
      default:
        return OtpVerificationResult.error;
    }
  }
}

enum OtpVerificationResult {
  success,
  invalid,
  expired,
  notFound,
  tooManyAttempts,
  error,
}
