import 'package:fine_aid/core/widgets/password_checklist.dart';
import 'package:fine_aid/features/settings/screens/edit_profile_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _ignoreListTileInkWarning() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains(
      'ListTile background color or ink splashes may be invisible',
    )) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('password change rules (Edit Profile)', () {
    test('current password is required', () {
      expect(currentPasswordRequiredError(''), 'Current password is required');
      expect(currentPasswordRequiredError('anything'), isNull);
    });

    test('new password is required', () {
      expect(
        newPasswordError(current: 'Old#Pass1', newPw: ''),
        'New password is required',
      );
    });

    test('the shared Sign Up strength rules apply', () {
      expect(
        newPasswordError(current: 'Old#Pass1', newPw: 'short1!A'),
        isNull, // 8 chars with upper, lower, number, special = valid
      );
      for (final weak in [
        'alllowercase1!',
        'ALLUPPERCASE1!',
        'NoNumber!!',
        'NoSpecial11',
        'Sh0rt!',
      ]) {
        expect(
          newPasswordError(current: 'Old#Pass1', newPw: weak),
          isNotNull,
          reason: weak,
        );
      }
    });

    test('the new password must differ from the current one', () {
      expect(
        newPasswordError(current: 'Same#Pass1', newPw: 'Same#Pass1'),
        'New password must be different from your current password',
      );
      expect(
        newPasswordError(current: 'Same#Pass1', newPw: 'Other#Pass1'),
        isNull,
      );
    });

    test('confirmation must match', () {
      expect(
        confirmPasswordError(newPw: 'New#Pass1', confirm: 'New#Pass2'),
        'Passwords do not match',
      );
      expect(
        confirmPasswordError(newPw: 'New#Pass1', confirm: ''),
        'Passwords do not match',
      );
      expect(
        confirmPasswordError(newPw: 'New#Pass1', confirm: 'New#Pass1'),
        isNull,
      );
    });
  });

  group('shared password checklist', () {
    testWidgets('lists all five requirements and ticks the ones met', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PasswordChecklist(password: 'abc')),
        ),
      );
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('At least 1 uppercase letter'), findsOneWidget);
      expect(find.text('At least 1 lowercase letter'), findsOneWidget);
      expect(find.text('At least 1 number'), findsOneWidget);
      expect(find.text('At least 1 special character'), findsOneWidget);
      // only "lowercase" is met by 'abc'
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PasswordChecklist(password: 'Abcdef1!')),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
    });
  });

  group('Settings no longer has the healing-reminder toggle', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    testWidgets('no switch and no reminder label', (tester) async {
      _ignoreListTileInkWarning();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('Healing milestone'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
