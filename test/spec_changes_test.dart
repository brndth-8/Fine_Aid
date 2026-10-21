import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/core/age_utils.dart';
import 'package:fine_aid/core/navigation/app_navigator.dart';
import 'package:fine_aid/core/nearby_intent.dart';
import 'package:fine_aid/core/widgets/help_tour_overlay.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_user_info.dart';

void main() {
  group('age', () {
    test('goes up on the birthday, not before', () {
      final dob = DateTime(2008, 6, 15);
      expect(calculateAge(dob, today: DateTime(2026, 6, 14)), 17);
      expect(calculateAge(dob, today: DateTime(2026, 6, 15)), 18);
    });

    test('never negative', () {
      expect(calculateAge(DateTime(2030), today: DateTime(2026)), 0);
    });
  });

  group('admin user info', () {
    test('shows N/A for users without the new fields', () {
      final rows = adminUserInfoRows({'username': 'old'});
      final map = {for (final (k, v) in rows) k: v};
      expect(map['Username'], 'old');
      for (final k in [
        'First Name',
        'Last Name',
        'Date of Birth',
        'Age',
        'Gender',
      ]) {
        expect(map[k], 'N/A', reason: k);
      }
    });

    test('shows the saved details and a computed age', () {
      final rows = adminUserInfoRows({
        'username': 'juan',
        'firstName': 'Juan',
        'lastName': 'Dela Cruz',
        'dateOfBirth': Timestamp.fromDate(DateTime(2000, 1, 15)),
        'gender': 'other',
      }, today: DateTime(2026, 1, 14));
      final map = {for (final (k, v) in rows) k: v};
      expect(map['First Name'], 'Juan');
      expect(map['Last Name'], 'Dela Cruz');
      expect(map['Age'], '25');
      expect(map['Gender'], 'Other / Prefer not to say');
    });
  });

  group('asksForNearbyHealthcare', () {
    test('location questions match', () {
      for (final q in [
        'Where is the nearest hospital?',
        'find a pharmacy near me',
        'saan may malapit na klinika',
        'Where can I find an ER',
        'looking for a doctor',
      ]) {
        expect(asksForNearbyHealthcare(q), isTrue, reason: q);
      }
    });

    test('other questions do not', () {
      for (final q in [
        'Should I see a doctor?',
        'How do I clean a cut?',
        'where should I put the bandage',
      ]) {
        expect(asksForNearbyHealthcare(q), isFalse, reason: q);
      }
    });
  });

  testWidgets('resetToLogin clears the whole stack', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => Text('route:${settings.name}'),
        ),
        initialRoute: '/dashboard',
      ),
    );
    key.currentState!.push(
      MaterialPageRoute(builder: (_) => const Text('settings')),
    );
    await tester.pumpAndSettle();

    resetToLogin(key.currentState!);
    await tester.pumpAndSettle();

    expect(find.text('route:/'), findsOneWidget);
    expect(key.currentState!.canPop(), isFalse);
  });

  testWidgets('Skip Tour sits left of Next on the same row', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HelpTourOverlay(
          onFinished: () {},
          // Short labels: the test font is far wider than a real one.
          skipLabel: 'Skip',
          nextLabel: 'Go',
          steps: const [
            HelpTourStep(title: 'One', description: 'First'),
            HelpTourStep(title: 'Two', description: 'Second'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final skip = tester.getCenter(find.text('Skip'));
    final next = tester.getCenter(find.text('Go'));
    expect(skip.dx, lessThan(next.dx));
    expect((skip.dy - next.dy).abs(), lessThan(4));
  });
}
