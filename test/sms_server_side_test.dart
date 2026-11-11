import 'dart:io';

import 'package:fine_aid/services/api/semaphore_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The SMS key and the verification code live on the server only.
void main() {
  String source(String path) => File(path).readAsStringSync();

  test('the app holds no key file and no direct Semaphore call', () {
    expect(File('lib/core/constants/api_keys.dart').existsSync(), isFalse);
    final service = source('lib/services/api/semaphore_service.dart');
    expect(service, isNot(contains('api.semaphore.co')));
    expect(service, isNot(contains('apikey')));
    expect(service, isNot(contains('api_keys')));
    expect(service, isNot(contains("package:http")));
    // it asks the Cloud Functions instead
    expect(service, contains('sendAccountVerificationOtpSms'));
    expect(service, contains('verifyAccountVerificationOtp'));
  });

  test('no code is made or stored on the phone, and the phone cannot verify itself', () {
    final service = source('lib/services/api/semaphore_service.dart');
    expect(service, isNot(contains('otpVerifications')));
    expect(service, isNot(contains('Random')));
    expect(service, isNot(contains('phoneVerified')));
    expect(service, isNot(contains('clearOtp')));
  });

  test('nothing else in the app reads a key constant', () {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      expect(text, isNot(contains('ApiKeys.')), reason: entity.path);
      expect(text, isNot(contains('constants/api_keys.dart')), reason: entity.path);
    }
  });

  test('the server answers read as the right result in the app', () {
    OtpVerificationResult of(String code) => SemaphoreService.resultForCode(code);
    expect(of('permission-denied'), OtpVerificationResult.invalid);
    expect(of('deadline-exceeded'), OtpVerificationResult.expired);
    expect(of('resource-exhausted'), OtpVerificationResult.tooManyAttempts);
    expect(of('not-found'), OtpVerificationResult.notFound);
    expect(of('internal'), OtpVerificationResult.error);
    expect(of('unauthenticated'), OtpVerificationResult.error);
  });

  test('the rules close the old client-side path once the switch is on', () {
    final rules = source('firestore.rules');
    expect(rules, contains('appConfig/smsVerification'));
    expect(rules, contains('allow read, write: if isOwner(uid) && !smsEnforced();'));
    expect(rules, contains('notSelfVerifiedOnUpdate()'));
  });
}
