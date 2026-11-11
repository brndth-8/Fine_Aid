import 'package:fine_aid/features/admin/screens/sections/admin_feedback.dart';
import 'package:fine_aid/features/settings/screens/feedback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 100-character limit (no minimum) belongs to what a USER types in the
/// feedback form. The admin's reply has its own, separate rule (see
/// test/admin/admin_round2_test.dart); nothing is shared between the two.
void main() {
  group('user feedback rule', () {
    test('any length up to 100 is accepted, with no minimum', () {
      expect(userFeedbackProblem('x'), isNull);
      expect(userFeedbackProblem('hi'), isNull);
      expect(userFeedbackProblem('x' * 59), isNull);
      expect(userFeedbackProblem('x' * 100), isNull);
    });

    test('over 100 is refused', () {
      expect(userFeedbackProblem('x' * 101), contains('100 characters'));
    });

    test('an empty form is left to the existing "write something" message', () {
      expect(userFeedbackProblem(''), isNull);
    });
  });

  test('the user form and the admin reply use separate rules', () {
    expect(userFeedbackMaxLength, 100);
    expect(adminFeedbackResponseMax, isNot(userFeedbackMaxLength));
    expect(adminFeedbackResponseProblem('x' * 5), isNull);
  });

  group('the feedback form', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: FeedbackScreen()));
    }

    testWidgets('shows a live X / 100 counter and no minimum text', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('0 / 100'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Short note');
      await tester.pump();
      expect(find.text('10 / 100'), findsOneWidget);
      expect(find.textContaining('At least'), findsNothing);
      expect(find.textContaining('more needed'), findsNothing);
    });

    testWidgets('blocks typing and pasting past 100', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'z' * 250);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 100);
      expect(find.text('100 / 100'), findsOneWidget);
    });
  });
}
