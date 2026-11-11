import 'dart:io';
import 'package:fine_aid/features/journal/screens/entry_detail_screen.dart';
import 'package:fine_aid/features/settings/screens/feedback_screen.dart';
import 'package:fine_aid/i18n/ai_scan_stats_strings.dart';
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

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Feedback: top bar, pink rating card with five stars', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: FeedbackScreen()));
    expect(find.widgetWithText(AppBar, 'Feedback'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.text('Submit Feedback'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

  testWidgets('Health Journal entry: facts box, steps and the Evaluation', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EntryDetailScreen(
          entryId: 'e1',
          data: {
            'source': 'ai_camera',
            'title': 'AI Camera Assessment',
            'description':
                'Wound type: Bruise\nTriage: Self Care\nPain score: 2/5\n\n'
                'FIRST AID STEPS:\n1. Before: Wash your hands. — keeps it clean\n'
                '2. During: Place a cold pack.\n3. After: Seek care if it '
                'swells.',
            'classification': 'Bruise',
            'firstAidSteps': [
              'Before: Wash your hands with soap and water. — keeps it clean',
              'During: Place a wrapped cold pack.',
              'After: Seek medical care if swelling increases.',
            ],
            'painScore': 2,
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Health Journal'), findsOneWidget);
    // the facts, as bold label + value
    expect(
      find.textContaining('Wound type: Bruise', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Pain score: 2/5', findRichText: true),
      findsOneWidget,
    );
    // steps, numbered on across Before / During / After
    expect(find.text('First Aid Steps'), findsOneWidget);
    expect(find.text('Wash your hands with soap and water.'), findsOneWidget);
    expect(
      find.text('Seek medical care if swelling increases.'),
      findsOneWidget,
    );
    // the saved text is not shown a second time as raw text
    expect(find.textContaining('FIRST AID STEPS:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('About the AI scan: ring, rates and the Scan Summary card', (
    tester,
  ) async {
    final s = AiScanStatsStrings.en;
    expect(s.scanSummary, 'Scan Summary');
    expect(AiScanStatsStrings.tl.scanSummary, isNot(s.scanSummary));
  });

  group('every redesigned page has the maroon top bar', () {
    for (final entry in {
      'lib/features/dashboard/screens/notifications_screen.dart': 'AppBar(',
      'lib/features/settings/screens/ai_scan_info_screen.dart': 'AppBar(',
      'lib/features/settings/screens/personalization_screen.dart': 'AppBar(',
      'lib/features/settings/screens/edit_profile_screen.dart': 'AppBar(',
      'lib/features/settings/screens/feedback_screen.dart': 'AppBar(',
      'lib/features/journal/screens/day_entries_screen.dart': 'AppBar(',
      'lib/features/journal/screens/entry_detail_screen.dart': 'AppBar(',
      'lib/features/camera/screens/multi_injury_screen.dart': 'AppBar(',
    }.entries) {
      test(entry.key.split('/').last, () {
        expect(source(entry.key), contains(entry.value));
      });
    }
  });

  test(
    'Edit Profile follows the design order, with Age and required marks',
    () {
      final edit = source(
        'lib/features/settings/screens/edit_profile_screen.dart',
      );
      int at(String needle) => edit.indexOf(needle);
      final order = [
        'firstNameLabel',
        'lastNameLabel',
        'dobLabel',
        'r.ageLabel',
        'genderLabel',
        'ScreenText.of(context).username,',
        'ProfileStrings.of(context).phone',
        'ScreenText.of(context).email,',
        "'Current Password'",
      ];
      var previous = -1;
      for (final piece in order) {
        final index = at(piece);
        expect(index, greaterThan(previous), reason: piece);
        previous = index;
      }
      expect(edit, contains('required: true'));
      expect(edit, contains('accountDetails'));
    },
  );

  test('the calendar uses the pink card with a month pill', () {
    final text = source('lib/features/journal/screens/day_entries_screen.dart');
    expect(text, contains('0xFFF1DCDC'));
    expect(text, contains('0xFFDBADAD'));
    expect(text, contains('edit_calendar_outlined'));
  });
}
