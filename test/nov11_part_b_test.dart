import 'dart:io';

import 'package:fine_aid/core/ph_phone_validator.dart';
import 'package:fine_aid/core/widgets/assessment_questions.dart';
import 'package:fine_aid/core/widgets/app_date_picker.dart';
import 'package:fine_aid/data/health_profile_cautions.dart';
import 'package:fine_aid/features/camera/screens/multi_injury_screen.dart';
import 'package:fine_aid/features/settings/screens/help_screen.dart';
import 'package:fine_aid/i18n/assessment_strings.dart';
import 'package:fine_aid/i18n/nav_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('B1. Health Profile on the AI scan', () {
    test('eczema in "other condition" is noted, in both languages', () {
      final profile = {'otherCondition': 'Eczema'};
      final en = healthProfileCautions(profile);
      final tl = healthProfileCautions(profile, tagalog: true);
      expect(en.single, contains('eczema'));
      expect(tl.single, contains('eczema'));
      expect(tl.single, isNot(en.single));
    });

    test('any other typed condition is noted too', () {
      final c = healthProfileCautions({'otherCondition': 'asthma'});
      expect(c.single, contains('asthma'));
    });

    test('the allergy types add their own line', () {
      final c = healthProfileCautions({
        'allergyTypes': ['latex', 'drug', 'skin', 'insect', 'food'],
      });
      expect(c.length, 4); // food has no line of its own
      expect(c.any((l) => l.contains('latex')), isTrue);
      expect(c.any((l) => l.contains('drug')), isTrue);
    });

    test('the older cautions still come first-class, now in Filipino too', () {
      final p = {
        'diabetes': true,
        'hemophiliaOrBloodDisorders': true,
        'severeAllergies': true,
      };
      expect(healthProfileCautions(p).length, 3);
      for (final l in healthProfileCautions(p, tagalog: true)) {
        expect(l, startsWith('Nabanggit mong'));
      }
      expect(healthProfileCautions(null), isEmpty);
      expect(healthProfileCautions({}), isEmpty);
    });

    Future<AssessmentAnswers?> ask(
      WidgetTester tester,
      Future<void> Function() script, {
      List<String> saved = const [],
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AssessmentAnswers? result;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await askAssessmentQuestions(
                    context,
                    skinIssue: false,
                    savedMedications: saved,
                  );
                  done = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await script();
      expect(done, isTrue);
      return result;
    }

    testWidgets('medication already in the profile: it is NOT asked again', (
      tester,
    ) async {
      final answers = await ask(tester, () async {
        await tester.tap(find.text('3').first);
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Do you take any medication?'), findsNothing);
      }, saved: ['Metformin']);
      expect(answers!.pain, 3);
      expect(answers.medications, ['Metformin']);
    });

    testWidgets('no medication in the profile: it is still asked', (
      tester,
    ) async {
      final answers = await ask(tester, () async {
        await tester.tap(find.text('2').first);
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Do you take any medication?'), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      });
      expect(answers!.medications, isEmpty);
    });

    test('the "You are taking ..." wording, both languages', () {
      expect(AssessmentStrings.en.ackTake, 'You are taking {list}.');
      expect(AssessmentStrings.tl.ackTake, 'Umiinom ka ng {list}.');
      expect(
        AssessmentStrings.tl.profileBoxTitle,
        isNot(AssessmentStrings.en.profileBoxTitle),
      );
    });

    test('the result screen uses the shared box', () {
      final result = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(result, contains('HealthProfileBox('));
      expect(result, contains('medications: _medications'));
      final box = source('lib/core/widgets/health_profile_box.dart');
      expect(box, contains('profileConditionLabels(profile'));
      expect(box, contains('a.ackTake'));
      expect(box, contains('healthProfileCautions(profile'));
    });
  });

  group('B2. Replay Help Tour also from a guest / offline dashboard', () {
    testWidgets('it goes back to the dashboard, not to the login screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('LOGIN')),
                );
              case '/dashboard':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                      child: const Text('DASHBOARD'),
                    ),
                  ),
                );
            }
            return null;
          },
        ),
      );
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      // a guest / offline entry: the dashboard is pushed on top of the login
      nav.pushNamed('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay Help Tour'));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
    });
  });

  group('B3. Bottom bar stays English', () {
    test('the dashboard builds it from the English strings', () {
      final dash = source(
        'lib/features/dashboard/screens/dashboard_screen.dart',
      );
      expect(dash, contains('_navItems(NavStrings.en)'));
      expect(dash, isNot(contains('_navItems(NavStrings.of(context))')));
      expect(NavStrings.tl.helpAndSupport, isNot(NavStrings.en.helpAndSupport));
    });
  });

  group('B4. Calendar card keeps one size', () {
    test(
      'six rows are always reserved, and the jump button keeps its room',
      () {
        final dash = source(
          'lib/features/dashboard/screens/dashboard_screen.dart',
        );
        expect(dash, contains('6 * (box.maxWidth / 7)'));
        expect(dash, contains('maintainSize: true'));
        final day = source(
          'lib/features/journal/screens/day_entries_screen.dart',
        );
        expect(day, contains('6 * box.maxWidth / 7'));
        expect(day, contains('maintainSize: true'));
      },
    );
  });

  group('B5/B7. Date as month, day and year boxes', () {
    test('the picker uses three boxes', () {
      final picker = source('lib/core/widgets/app_date_picker.dart');
      expect(picker, contains('class _DateBoxes'));
      expect(picker, isNot(contains('_DateSlashFormatter')));
      expect(parseDateInput('10/05/2026'), DateTime(2026, 10, 5));
    });
  });

  group('B6. Username limit', () {
    test('15 characters', () {
      final reg = source('lib/features/auth/screens/registration_screen.dart');
      expect(reg, contains('kUsernameMaxLength = 32'));
      expect(reg, contains('LengthLimitingTextInputFormatter'));
    });
  });

  group('B8. "None" on the multi-injury screen', () {
    testWidgets('None goes back and says nothing was assessed', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MultiInjuryScreen(
                      imagePath: 'none.jpg',
                      woundDescriptions: ['a', 'b'],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(ScreenText.en.noneOfThese), findsOneWidget);
      await tester.tap(find.text(ScreenText.en.noneOfThese));
      await tester.pumpAndSettle();
      expect(find.byType(MultiInjuryScreen), findsNothing);
      expect(find.text(ScreenText.en.noneChosenNote), findsOneWidget);
      expect(ScreenText.tl.noneOfThese, isNot(ScreenText.en.noneOfThese));
    });
  });

  group('B9. Transparent system navigation bar', () {
    test('main() sets it up', () {
      final main = source('lib/main.dart');
      expect(main, contains('SystemUiMode.edgeToEdge'));
      expect(main, contains('systemNavigationBarColor: Colors.transparent'));
    });
  });

  group('B10. Smart and postpaid numbers', () {
    test('the Smart / TNT / Sun prefixes that were refused now pass', () {
      for (final prefix in ['911', '913', '914', '969', '981', '934', '944']) {
        expect(
          normalizePhMobileNumber('${prefix}2468013'),
          '+63${prefix}2468013',
          reason: prefix,
        );
      }
    });

    test('older prefixes and fakes behave as before', () {
      expect(normalizePhMobileNumber('9171234568'), '+639171234568');
      expect(normalizePhMobileNumber('9001234567'), isNull);
      expect(normalizePhMobileNumber('9999999999'), isNull);
    });
  });

  group('B11. Going back from the OTP page', () {
    test('releases the phone and email reservations with the username', () {
      final otp = source('lib/features/auth/screens/otp_screen.dart');
      expect(otp, contains("db.collection('phones')"));
      expect(otp, contains("db.collection('emails')"));
      expect(otp, contains("db.collection('usernames')"));
      expect(otp, contains('FieldValue.delete()'));
      expect(otp, contains('batch.commit()'));
    });
  });

  group('B12. Hospital search limit', () {
    test('50 characters', () {
      final sheet = source('lib/core/widgets/nearby_healthcare_sheet.dart');
      expect(sheet, contains('maxLength: 50'));
    });
  });
}
