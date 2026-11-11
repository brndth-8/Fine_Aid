import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fine_aid/features/admin/admin_two_step.dart';
import 'package:fine_aid/features/admin/screens/admin_two_step_setup_screen.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_audit_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the plain browser error object the web library can throw.
class _RawJsError {
  _RawJsError(this.code, this.message);
  final String code;
  final String message;
}

/// A browser error whose properties can't be read, only its text.
class _TextOnlyError {
  _TextOnlyError(this.text);
  final String text;
  @override
  String toString() => text;
}

void main() {
  group('reading the sign-in token', () {
    test('a sign-in through an authenticator code is recognised', () {
      expect(
        signedInWithAuthenticator({
          'firebase': {
            'sign_in_provider': 'password',
            'sign_in_second_factor': 'totp',
          },
        }),
        isTrue,
      );
    });

    test('a password-only sign-in, other factors and bad data are not', () {
      expect(
        signedInWithAuthenticator({
          'firebase': {'sign_in_provider': 'password'},
        }),
        isFalse,
      );
      expect(
        signedInWithAuthenticator({
          'firebase': {'sign_in_second_factor': 'phone'},
        }),
        isFalse,
      );
      expect(signedInWithAuthenticator({'admin': true}), isFalse);
      expect(signedInWithAuthenticator({'firebase': 'totp'}), isFalse);
      expect(signedInWithAuthenticator(null), isFalse);
    });
  });

  group('the code', () {
    test('is exactly six digits (spaces are ignored)', () {
      expect(isValidAuthenticatorCode('123456'), isTrue);
      expect(isValidAuthenticatorCode('123 456'), isTrue);
      expect(isValidAuthenticatorCode('12345'), isFalse);
      expect(isValidAuthenticatorCode('1234567'), isFalse);
      expect(isValidAuthenticatorCode('12345a'), isFalse);
      expect(isValidAuthenticatorCode(''), isFalse);
    });

    testWidgets('the box takes digits only, at most six, and submits', (
      tester,
    ) async {
      final controller = TextEditingController();
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthenticatorCodeField(
              controller: controller,
              onSubmit: () => submitted++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '12ab34 5678');
      expect(controller.text, '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 1);
    });
  });

  group('error messages', () {
    test('a wrong code says so plainly', () {
      expect(
        describeTwoStepError(
          FirebaseAuthException(code: 'invalid-verification-code'),
        ),
        contains("isn't right"),
      );
    });

    test(
      'a project without authenticator codes switched on says how to fix it',
      () {
        expect(
          describeTwoStepError(
            FirebaseAuthException(code: 'operation-not-allowed'),
          ),
          contains('Firebase console'),
        );
      },
    );

    test(
      'a raw browser error is read for its auth/ code, never "JSObject"',
      () {
        expect(
          describeTwoStepError(_RawJsError('auth/operation-not-allowed', 'x')),
          contains('Firebase console'),
        );
        expect(
          describeTwoStepError(
            _RawJsError('', 'Firebase: Error (auth/unverified-email).'),
          ),
          contains('verification email'),
        );
        expect(
          describeTwoStepError(_RawJsError('auth/internal-error', 'x')),
          'Something went wrong (internal-error). Please try again.',
        );
        expect(
          needsVerifiedEmail(_RawJsError('auth/unverified-email', '')),
          isTrue,
        );
      },
    );

    test('an error that only has text is read from that text', () {
      expect(
        describeTwoStepError(
          _TextOnlyError(
            'FirebaseError: Firebase: Error (auth/operation-not-allowed).',
          ),
        ),
        contains('Firebase console'),
      );
      expect(
        describeTwoStepError(_TextOnlyError('TypeError: x is not a function')),
        'Something went wrong (TypeError: x is not a function). Please try again.',
      );
      expect(
        describeTwoStepError(_TextOnlyError("Instance of 'JSObject'")),
        'Something went wrong (_TextOnlyError). Please try again.',
      );
    });

    test('an unverified email says to verify it first', () {
      final e = FirebaseAuthException(code: 'unverified-email');
      expect(describeTwoStepError(e), contains('verification email'));
      expect(needsVerifiedEmail(e), isTrue);
      expect(
        needsVerifiedEmail(FirebaseAuthException(code: 'internal-error')),
        isFalse,
      );
    });

    test('an old sign-in is told to sign in again', () {
      expect(
        describeTwoStepError(
          FirebaseAuthException(code: 'requires-recent-login'),
        ),
        contains('sign in again'),
      );
    });

    test(
      "the server's own explanation is shown (e.g. sign in with a code first)",
      () {
        final e = FirebaseFunctionsException(
          code: 'failed-precondition',
          message:
              'Set up an authenticator app and sign in with its code first.',
        );
        expect(
          describeTwoStepError(e),
          contains('sign in with its code first'),
        );
      },
    );

    test('anything else gets a calm generic message', () {
      expect(
        describeTwoStepError(StateError('x')),
        'Something went wrong (Bad state: x). Please try again.',
      );
      // The real code is kept, so the next report says what happened.
      expect(
        describeTwoStepError(FirebaseAuthException(code: 'internal-error')),
        'Something went wrong (internal-error). Please try again.',
      );
    });
  });

  group('QR code', () {
    const url =
        'otpauth://totp/Fine%20Aid%20Admin:admin@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Fine%20Aid%20Admin';

    test('is a real QR matrix: square, with the three corner markers', () {
      final m = qrMatrix(url);
      expect(m.length, greaterThanOrEqualTo(21));
      expect(m.every((row) => row.length == m.length), isTrue);
      final n = m.length;
      for (final (r, c) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
        // A finder marker: dark ring, light ring, dark 3x3 centre.
        expect(m[r][c], isTrue);
        expect(m[r][c + 6], isTrue);
        expect(m[r + 6][c], isTrue);
        expect(m[r + 1][c + 1], isFalse);
        expect(m[r + 3][c + 3], isTrue);
      }
    });

    test('different text gives a different code', () {
      expect(qrMatrix(url), isNot(qrMatrix('$url&x=1')));
      expect(qrMatrix(url), qrMatrix(url));
    });

    testWidgets('draws dark squares on white, with a quiet margin', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: AuthenticatorQr(data: url, size: 300),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      int red(double x, double y) =>
          data.getUint8((y.round() * image.width + x.round()) * 4);
      final modules = qrMatrix(url).length + 8;
      final cell = 300 / modules;
      // The quiet margin is white; the first module of the top-left marker is
      // black.
      expect(red(cell * 2, cell * 2), 255);
      expect(red(cell * 4.5, cell * 4.5), 0);
    });
  });

  group('plain-language audit entries', () {
    test('signing in with a code', () {
      expect(
        describeAudit({
          'action': 'Admin signed in',
          'reason': 'authenticator_code',
        }, 'maria'),
        "'maria' signed in to the admin portal with an authenticator code",
      );
      expect(
        describeAudit({'action': 'Admin signed in'}, 'maria'),
        "'maria' signed in to the admin portal",
      );
    });

    test('a wrong code, and switching the requirement', () {
      expect(
        describeAudit({
          'action': 'Failed admin sign-in attempt',
          'reason': 'wrong_code',
        }, 'maria'),
        contains('the authenticator code was wrong'),
      );
      expect(
        describeAudit({
          'action': 'Two-step verification turned on for admins',
        }, 'maria'),
        contains('turned on authenticator codes'),
      );
      expect(
        describeAudit({
          'action': 'Two-step verification turned off for admins',
        }, 'maria'),
        contains('turned off the authenticator code requirement'),
      );
    });
  });

  testWidgets('the set-up screen explains and offers the two choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminTwoStepSetupScreen()));
    expect(find.text('Set up two-step verification'), findsOneWidget);
    expect(find.text('Set up authenticator app'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
