import 'dart:io';

import 'package:fine_aid/core/widgets/assessment_questions.dart';
import 'package:fine_aid/i18n/assessment_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C1. A guest is asked about existing health conditions', () {
    Future<AssessmentAnswers?> ask(
      WidgetTester tester,
      Future<void> Function() script, {
      bool askConditions = true,
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
                    askConditions: askConditions,
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

    Future<void> rate(WidgetTester tester, int n) async {
      await tester.tap(find.text('$n').first);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    final title = AssessmentStrings.en.conditionsQuestionTitle;
    ElevatedButton cont(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );

    testWidgets('after the pain rating, before medication: Yes + choices', (
      tester,
    ) async {
      final answers = await ask(tester, () async {
        await rate(tester, 2);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Do you take any medication?'), findsNothing);
        // nothing chosen yet
        expect(cont(tester).onPressed, isNull);
        await tester.tap(find.text('Yes'));
        await tester.pump();
        // Yes needs at least one choice
        expect(cont(tester).onPressed, isNull);
        await tester.tap(find.text('Diabetes'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Eczema');
        await tester.pump();
        expect(cont(tester).onPressed, isNotNull);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        // then the medication question, as before
        expect(find.text('Do you take any medication?'), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      });
      expect(answers!.pain, 2);
      expect(answers.conditions, {
        'diabetes': true,
        'otherCondition': 'Eczema',
      });
      expect(answers.medications, isEmpty);
    });

    testWidgets('No gives an empty answer', (tester) async {
      final answers = await ask(tester, () async {
        await rate(tester, 1);
        await tester.tap(find.text('No'));
        await tester.pump();
        expect(cont(tester).onPressed, isNotNull);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      });
      expect(answers!.conditions, isEmpty);
    });

    testWidgets('a signed-in user is not asked (the profile is used)', (
      tester,
    ) async {
      final answers = await ask(tester, () async {
        await rate(tester, 3);
        expect(find.text(title), findsNothing);
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }, askConditions: false);
      expect(answers!.conditions, isNull);
    });

    test('the result screen asks guests and shows what they said', () {
      final result = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(result, contains('askConditions:'));
      expect(result, contains('FirebaseAuth.instance.currentUser == null'));
      expect(result, contains('profile: profile ?? answers.conditions'));
      expect(result, contains('_profile = answers!.conditions'));
    });

    test('the question exists in both languages', () {
      expect(
        AssessmentStrings.tl.conditionsQuestionTitle,
        isNot(AssessmentStrings.en.conditionsQuestionTitle),
      );
      expect(
        AssessmentStrings.tl.conditionsQuestionBody,
        isNot(AssessmentStrings.en.conditionsQuestionBody),
      );
    });
  });

  group('C2. Guest feedback', () {
    test('the form marks a guest\'s feedback and keeps userId empty', () {
      final f = source('lib/features/settings/screens/feedback_screen.dart');
      expect(f, contains("if (user == null) 'source': 'guest'"));
      expect(f, contains("'userId': user?.uid"));
    });

    test('the rules let a guest create (only) a strictly checked item', () {
      final rules = source('firestore.rules');
      expect(rules, contains('function validGuestFeedback()'));
      expect(rules, contains("d.source == 'guest'"));
      expect(rules, contains('d.message.size() <= 100'));
      expect(rules, contains('d.submittedAt == request.time'));
      expect(rules, contains('(!isSignedIn() && validGuestFeedback())'));
      // reading stays admin-only
      expect(rules, contains('allow read, delete: if isAdmin();'));
    });

    test('the admin side labels a guest\'s feedback "Guest"', () {
      final admin = source(
        'lib/features/admin/screens/sections/admin_feedback.dart',
      );
      expect(admin, contains("data['source'] == 'guest'"));
      expect(admin, contains("? 'Guest'"));
      // every place that showed the sender's name now goes through it
      expect(admin, isNot(contains("_names.nameFor(data['userId']")));
    });
  });
}
