import 'dart:io';
import 'package:fine_aid/core/widgets/phone_otp_dialog.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/phone_otp_strings.dart';
import 'package:fine_aid/services/api/semaphore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('Done button after the scan', () {
    final screen = source(
      'lib/features/camera/screens/assessment_result_screen.dart',
    );

    test('shown under the result, and goes back to the Dashboard', () {
      expect(screen, contains('ScreenText.of(context).done'));
      expect(screen, contains('Navigator.maybePop(context)'));
      // only once a result is on screen
      expect(
        screen,
        contains('if (!_isAnalyzing && _error == null && assessment != null)'),
      );
    });
  });

  group('A new phone number is verified before it is saved', () {
    List<String> sent = [];
    String? bool_;

    Future<void> open(
      WidgetTester tester, {
      required Future<bool> Function(String) send,
      required Future<OtpVerificationResult> Function(String) verify,
      AppLanguage language = AppLanguage.en,
      void Function(bool)? done,
    }) async {
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final ok = await showPhoneOtpDialog(
                    context,
                    phoneNumber: '+639171234567',
                    sendCode: send,
                    verifyCode: verify,
                  );
                  done?.call(ok);
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    setUp(() {
      sent = [];
      bool_ = null;
    });

    testWidgets('a code is sent to the new number when the box opens', (
      tester,
    ) async {
      await open(
        tester,
        send: (n) async {
          sent.add(n);
          return true;
        },
        verify: (_) async => OtpVerificationResult.success,
      );
      expect(sent, ['+639171234567']);
      expect(find.textContaining('+639171234567'), findsOneWidget);
    });

    testWidgets('Verify needs all 6 digits; the right code returns true', (
      tester,
    ) async {
      final s = PhoneOtpStrings.en;
      await open(
        tester,
        send: (_) async => true,
        verify: (code) async => code == '123456'
            ? OtpVerificationResult.success
            : OtpVerificationResult.invalid,
        done: (ok) => bool_ = '$ok',
      );
      ElevatedButton verifyButton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, s.verify),
      );

      expect(verifyButton().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(verifyButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();
      await tester.tap(find.text(s.verify));
      await tester.pumpAndSettle();
      expect(find.text(s.incorrect), findsOneWidget); // stays open
      expect(bool_, isNull);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(find.text(s.verify));
      await tester.pumpAndSettle();
      expect(bool_, 'true');
    });

    testWidgets('Cancel returns false, so nothing is saved', (tester) async {
      await open(
        tester,
        send: (_) async => true,
        verify: (_) async => OtpVerificationResult.success,
        done: (ok) => bool_ = '$ok',
      );
      await tester.tap(find.text(PhoneOtpStrings.en.cancel));
      await tester.pumpAndSettle();
      expect(bool_, 'false');
    });

    testWidgets('if the code cannot be sent it says so and cannot verify', (
      tester,
    ) async {
      final s = PhoneOtpStrings.en;
      await open(
        tester,
        send: (_) async => false,
        verify: (_) async => OtpVerificationResult.success,
      );
      expect(find.text(s.couldNotSend), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, s.verify),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('an expired code asks for a new one; Tagalog works too', (
      tester,
    ) async {
      final s = PhoneOtpStrings.tl;
      await open(
        tester,
        send: (_) async => true,
        verify: (_) async => OtpVerificationResult.expired,
        language: AppLanguage.tl,
      );
      expect(find.text(s.title), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(find.text(s.verify));
      await tester.pumpAndSettle();
      expect(find.text(s.expired), findsOneWidget);
    });

    test('Edit Profile only saves after it, and only for a changed number', () {
      final edit = source(
        'lib/features/settings/screens/edit_profile_screen.dart',
      );
      expect(edit, contains('showPhoneOtpDialog('));
      final verifyAt = edit.indexOf('phoneChanged && !await _verifyNewPhone()');
      final savingAt = edit.indexOf('setState(() => _isSaving = true);');
      expect(verifyAt, greaterThan(0));
      expect(verifyAt, lessThan(savingAt));
      expect(edit, contains('_phoneController.text != _originalPhoneDigits'));
    });
  });

  group('A new birthday under 18 asks for the notice again', () {
    final edit = source(
      'lib/features/settings/screens/edit_profile_screen.dart',
    );

    test('shown before saving, only when the birthday changed', () {
      expect(edit, contains('showUnderageNotice(context)'));
      expect(
        edit,
        contains('_dob != _originalDob && calculateAge(_dob!) < kAdultAge'),
      );
      expect(
        edit.indexOf('showUnderageNotice(context)'),
        lessThan(edit.indexOf('setState(() => _isSaving = true);')),
      );
    });

    test('the acknowledgement is recorded like at sign-up', () {
      expect(edit, contains("'underageAcknowledged': true"));
      expect(
        edit,
        contains("'underageAcknowledgedAt': FieldValue.serverTimestamp()"),
      );
    });
  });
}
