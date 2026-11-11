import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/data/health_profile_summary.dart';
import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/chatbot/screens/chatbot_screen.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/features/settings/screens/guest_profile_gate_screen.dart';
import 'package:fine_aid/features/settings/screens/profile_screen.dart';
import 'package:fine_aid/i18n/ai_scan_stats_strings.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/checklist_strings.dart';
import 'package:fine_aid/i18n/profile_strings.dart';
import 'package:fine_aid/i18n/registration_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  // ------------------------------------------------------------------ 1
  group('1. no "Not sure" option in the Health Profile', () {
    Future<void> pumpChecklist(
      WidgetTester tester, {
      Map<String, dynamic>? saved,
      AppLanguage lang = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: lang,
          child: MaterialApp(
            home: HealthChecklistScreen(initialProfile: saved),
          ),
        ),
      );
      await tester.pump();
    }

    Finder ticked() =>
        find.byWidgetPredicate((w) => w is Checkbox && w.value == true);

    test('the source has no "Not sure" text or id left', () {
      final text = [
        'lib/i18n/checklist_strings.dart',
        'lib/features/auth/screens/health_checklist_screen.dart',
      ].map((f) => File(f).readAsStringSync()).join('\n').toLowerCase();
      expect(text, isNot(contains('not sure')));
      expect(text, isNot(contains('hindi sigurado')));
      expect(text, isNot(contains('notsure')));
    });

    for (final lang in [AppLanguage.en, AppLanguage.tl]) {
      testWidgets('${lang.name}: diabetes and blood disorder lists have only '
          'real options', (tester) async {
        final s = lang == AppLanguage.en
            ? ChecklistStrings.en
            : ChecklistStrings.tl;
        await pumpChecklist(tester, lang: lang);
        await tester.tap(find.text(s.diabetes));
        await tester.pumpAndSettle();
        // four diabetes types, each tappable
        for (final name in [
          s.diabetesType1,
          s.diabetesType2,
          s.diabetesGestational,
          s.diabetesPrediabetes,
        ]) {
          expect(find.text(name), findsOneWidget);
        }

        await tester.tap(find.text(s.hemophilia));
        await tester.pumpAndSettle();
        expect(find.text(s.hemophiliaA), findsOneWidget);
        expect(find.text(s.bloodDisorderOther), findsOneWidget);
        // 4 + 2 options (+ "none of the above") = 7 boxes, none ticked
        expect(find.byType(Checkbox), findsNWidgets(7));
        expect(ticked(), findsNothing);
      });
    }

    testWidgets(
      'an old saved "Not sure" counts as unanswered, without crashing',
      (tester) async {
        await pumpChecklist(
          tester,
          saved: {
            'diabetes': true,
            'diabetesType': 'notSure',
            'hemophiliaOrBloodDisorders': true,
            'bloodDisorderType': 'notSure',
            'severeAllergies': false,
            'allergyTypes': <String>[],
            'noneOfTheAbove': false,
          },
        );
        expect(tester.takeException(), isNull);
        // the conditions are still there, so the cards are open to choose from
        expect(find.text(ChecklistStrings.en.diabetesType1), findsOneWidget);
        expect(find.text(ChecklistStrings.en.hemophiliaA), findsOneWidget);
        // ...but no type is chosen: only the two "condition without a type"
        // rows are ticked (so they can be unticked)
        expect(ticked(), findsNWidgets(2));
      },
    );

    testWidgets('editing starts from what was saved and says Save changes', (
      tester,
    ) async {
      await pumpChecklist(
        tester,
        saved: {
          'diabetes': true,
          'diabetesType': 'type2',
          'otherCondition': 'Asthma',
          'medications': ['Metformin'],
        },
      );
      final s = ChecklistStrings.en;
      expect(ticked(), findsOneWidget); // Type 2
      expect(find.text('Asthma'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Metformin'), findsOneWidget);
      expect(find.text(s.saveChanges), findsOneWidget);
      expect(find.text(s.continueButton), findsNothing);
    });
  });

  // ------------------------------------------------------------------ 2
  group('2. result screen: satisfaction instead of the evaluation', () {
    final result = File(
      'lib/features/camera/screens/assessment_result_screen.dart',
    ).readAsStringSync();

    test('the Evaluation is gone from the result screen', () {
      expect(result, isNot(contains('EvaluationCard')));
      expect(result, isNot(contains('_evaluationData')));
      expect(result, isNot(contains('evaluation_card.dart')));
    });

    test(
      'the result screen asks "Are you satisfied?" and counts the answer',
      () {
        expect(result, contains('_buildSatisfaction'));
        expect(result, contains('recordRating'));
        expect(
          AiScanStatsStrings.en.feedbackQuestion,
          'Are you satisfied with the result?',
        );
        expect(AiScanStatsStrings.tl.feedbackQuestion, isNot(contains('Tama')));
      },
    );

    test('the admin/scan labels say satisfied, not correct or wrong', () {
      expect(AiScanStatsStrings.en.ratedCorrect, 'Satisfied');
      expect(AiScanStatsStrings.en.ratedNotCorrect, 'Not satisfied');
      expect(AiScanStatsStrings.en.accuracyRate, contains('Satisfaction'));
      final admin = File(
        'lib/features/admin/screens/widgets/admin_performance_card.dart',
      ).readAsStringSync();
      expect(admin, contains("'Not satisfied'"));
      expect(admin, isNot(contains("'Marked wrong'")));
      expect(admin, isNot(contains('Erroneous (marked wrong)')));
    });

    test('the prompts ask for simple words a child could understand', () {
      final prompt = File(
        'lib/services/api/gemini_service.dart',
      ).readAsStringSync();
      expect(prompt, contains('Use simple words a child could understand.'));
      expect(prompt, contains('Avoid '));
      for (final pair in [
        '"tepid water"',
        '"debris"',
        '"apply"',
        '"irrigate"',
        '"sterile"',
      ]) {
        expect(prompt, contains(pair));
      }
      // the first-aid format example no longer says "sterile non-stick dressing"
      expect(prompt, isNot(contains('a sterile non-stick dressing)')));
    });
  });

  // ------------------------------------------------------------------ 3
  group('3. Profile shows the full details', () {
    final s = ProfileStrings.en;
    final r = RegistrationStrings.en;

    Map<String, String> rows(Map<String, dynamic> data) => {
      for (final row in profileAccountRows(data, s, r)) row.label: row.value,
    };

    test('the sign-up details are listed, as in the design', () {
      final shown = rows({
        'firstName': 'Bernadeth',
        'lastName': 'Soriano',
        'username': 'weepy',
        'phoneNumber': '+639058171544',
        'email': 'weepy@fineaid.app',
        'recoveryEmail': 'iris@example.com',
        'dateOfBirth': Timestamp.fromDate(DateTime(2004, 4, 8)),
        'gender': 'female',
      });
      expect(shown['Full Name'], 'Bernadeth Soriano');
      expect(shown['Username'], 'weepy');
      expect(shown['Phone number'], '0905 817 1544');
      // the email is the one the person entered, never the internal address
      expect(shown['Email Address'], 'iris@example.com');
      expect(shown['Birthday'], '04 / 08 / 2004');
      expect(shown['Gender'], 'Female');
    });

    test('an older account with fewer details shows "Not provided"', () {
      final shown = rows({'username': 'old', 'email': 'old@fineaid.app'});
      expect(shown['Username'], 'old');
      for (final label in [
        'Full Name',
        'Phone number',
        'Email Address',
        'Birthday',
        'Gender',
      ]) {
        expect(shown[label], 'Not provided', reason: label);
      }
    });

    test('phone numbers are shown the local way', () {
      expect(formatPhoneForDisplay('+639171234567'), '0917 123 4567');
      expect(formatPhoneForDisplay('09171234567'), '0917 123 4567');
      expect(formatPhoneForDisplay('12345'), '12345');
    });

    test('the Health Profile summary lists conditions and medications', () {
      final c = ChecklistStrings.en;
      final health = profileHealthRows(
        {
          'diabetes': true,
          'diabetesType': 'type1',
          'hemophiliaOrBloodDisorders': true,
          'bloodDisorderType': 'hemophiliaA',
          'medications': ['Insulin', 'Warfarin'],
        },
        s,
        c,
        'and',
      );
      expect(health[0].value, 'Type 1 Diabetes and Hemophilia A');
      expect(health[1].value, 'Insulin and Warfarin');
    });

    test('nothing ticked reads None; no profile at all reads Not set yet', () {
      final c = ChecklistStrings.en;
      final none = profileHealthRows({'noneOfTheAbove': true}, s, c, 'and');
      expect(none.map((r) => r.value), ['None', 'None']);
      final unset = profileHealthRows(null, s, c, 'and');
      expect(unset.map((r) => r.value), ['Not set yet', 'Not set yet']);
    });

    test('an old "Not sure" diabetes type still reads as just Diabetes', () {
      final labels = profileConditionLabels({
        'diabetes': true,
        'diabetesType': 'notSure',
      }, ChecklistStrings.en);
      expect(labels, ['Diabetes']);
    });

    test('Tagalog labels exist for every row', () {
      final tl = ProfileStrings.tl;
      for (final row in profileAccountRows({}, tl, RegistrationStrings.tl)) {
        expect(row.label, isNotEmpty);
      }
      expect(tl.edit, isNot(s.edit));
    });
  });

  // ------------------------------------------------------------------ 4
  group('4. online and offline screens', () {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: AppLanguage.en,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
    }

    testWidgets('chat: First Aid Assistance header and banner, no language '
        'button', (tester) async {
      await pump(tester, const ChatbotScreen());
      expect(find.text('First Aid Assistance'), findsOneWidget);
      expect(find.text('Filipino'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Describe your concern'), findsOneWidget);
    });

    testWidgets('chat: the assistant has its avatar and the first message', (
      tester,
    ) async {
      await pump(tester, const ChatbotScreen());
      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing); // voice input is gone
    });

    testWidgets('kit: banner, question and a card for each injury', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const FirstAidKitScreen());
      expect(find.text('First Aid Health Kit'), findsOneWidget);
      expect(
        find.text('A preloaded library for basic first-aid guidance.'),
        findsOneWidget,
      );
      expect(
        find.text('Works completely offline - no Wi-Fi or data needed.'),
        findsOneWidget,
      );
      expect(
        find.text('What type of injury do you need help with?'),
        findsOneWidget,
      );
      for (final name in [
        'Laceration',
        'Minor Cut',
        'Scratch',
        'Abrasion',
        'Puncture Wound',
        'Burn',
        'Bruise',
        'Swelling',
        'Rash',
        'Other Skin Issue',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      // no dropdown any more
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    });

    testWidgets('kit: a card goes straight to the questions (no concern box)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const FirstAidKitScreen());
      await tester.tap(find.text('Minor Cut'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Describe your concern (optional)'), findsNothing);
      expect(find.textContaining('Question 1 of'), findsOneWidget);
    });

    testWidgets('kit: the X on a question cancels the check, it is not a No', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const FirstAidKitScreen());
      await tester.tap(find.text('Minor Cut'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Question 1 of'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      // back on the injury list; no question left, no result shown
      expect(find.textContaining('Question 1 of'), findsNothing);
      expect(find.text('Basic First-Aid Steps'), findsNothing);
      expect(find.text('Minor Cut'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('kit: no language button (it follows the app language)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const FirstAidKitScreen());
      expect(find.text('Filipino'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);
    });
  });

  // ------------------------------------------------------------------ guest
  group('Guest Profile (locked)', () {
    Future<void> open(WidgetTester tester, AppLanguage lang) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: lang,
          child: MaterialApp(
            routes: {
              '/registration': (_) => const Scaffold(body: Text('SIGNUP PAGE')),
              '/login': (_) => const Scaffold(body: Text('LOGIN PAGE')),
            },
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GuestProfileGateScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the lock, the message and the two buttons', (
      tester,
    ) async {
      await open(tester, AppLanguage.en);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Unlock Your Profile'), findsOneWidget);
      expect(
        find.text(
          'A personalized profile is available for registered members.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
      expect(
        find.widgetWithText(
          OutlinedButton,
          'Already have an account? Log In here',
        ),
        findsOneWidget,
      );
      // the avatar's lock badge and the big padlock
      expect(find.byIcon(Icons.lock), findsNWidgets(2));
      // both buttons are pills
      final signUp = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      expect(signUp.style?.shape?.resolve({}), isA<StadiumBorder>());
    });

    testWidgets('is translated', (tester) async {
      await open(tester, AppLanguage.tl);
      expect(find.text(ProfileStrings.tl.unlockTitle), findsOneWidget);
      expect(find.text(ProfileStrings.tl.signUp), findsOneWidget);
      expect(find.text('Unlock Your Profile'), findsNothing);
    });

    testWidgets('Sign Up goes to registration, Log In to login', (
      tester,
    ) async {
      await open(tester, AppLanguage.en);
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('SIGNUP PAGE'), findsOneWidget);
    });

    testWidgets('Log In here goes to login', (tester) async {
      await open(tester, AppLanguage.en);
      await tester.tap(find.text('Already have an account? Log In here'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    });

    testWidgets('the back arrow closes it', (tester) async {
      await open(tester, AppLanguage.en);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.byType(GuestProfileGateScreen), findsNothing);
    });
  });
}
