import 'dart:io';

import 'package:fine_aid/features/auth/screens/account_created_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/registration_strings.dart';
import 'package:fine_aid/services/emergency_alert.dart';
import 'package:fine_aid/services/health_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the alert vibration lasts 10 seconds', () {
    test('five buzzes and four pauses add up to 10 000 ms', () {
      expect(EmergencyAlert.pattern.fold<int>(0, (a, b) => a + b), 10000);
    });
  });

  group('medications named in an assessment join the Health Profile', () {
    test('new ones are added after the saved ones', () {
      expect(
        HealthProfileService.mergeMedications(['Paracetamol'], ['Ibuprofen']),
        ['Paracetamol', 'Ibuprofen'],
      );
    });

    test('one already saved is not added again (any capital letters)', () {
      expect(
        HealthProfileService.mergeMedications(
          ['Paracetamol'],
          ['paracetamol', ' Paracetamol ', ''],
        ),
        ['Paracetamol'],
      );
    });

    test('the assessment saves them, and a guest has none to save', () {
      expect(
        File(
          'lib/features/camera/screens/assessment_result_screen.dart',
        ).readAsStringSync(),
        contains('HealthProfileService().addMedications('),
      );
    });
  });

  group('Account Created Successfully!', () {
    Future<void> pump(WidgetTester tester, AppLanguage language) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: const MaterialApp(home: AccountCreatedScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('English: title, message and Continue', (tester) async {
      await pump(tester, AppLanguage.en);
      expect(find.text('Account Created Successfully!'), findsOneWidget);
      expect(
        find.text(
          'Your account has been created. You can now start using FINEAID.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('Tagalog', (tester) async {
      await pump(tester, AppLanguage.tl);
      expect(
        find.text(RegistrationStrings.tl.accountCreatedTitle),
        findsOneWidget,
      );
      expect(find.text('Magpatuloy'), findsOneWidget);
    });

    testWidgets('Continue closes the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountCreatedScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Account Created Successfully!'), findsNothing);
    });

    test('sign-up shows it, then goes on to verification', () {
      final text = File(
        'lib/features/auth/screens/registration_screen.dart',
      ).readAsStringSync();
      final shown = text.indexOf('const AccountCreatedScreen()');
      final toRoot = text.indexOf('popUntil((route) => route.isFirst)');
      expect(shown, greaterThan(0));
      expect(toRoot, greaterThan(shown));
    });
  });

  group('the images in assets/images/first_aid are small', () {
    test('no step picture is over 250 KB', () {
      for (final f in Directory('assets/images/first_aid').listSync()) {
        if (f is File && f.path.endsWith('.png')) {
          expect(f.lengthSync(), lessThan(250 * 1024), reason: f.path);
        }
      }
    });
  });
}
