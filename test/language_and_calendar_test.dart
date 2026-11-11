import 'dart:io';

import 'package:fine_aid/features/camera/screens/multi_injury_screen.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  String source(String path) => File(path).readAsStringSync();

  Future<void> phone(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('Settings has no Rate this app row (the app is not published)', () {
    final settings = source(
      'lib/features/settings/screens/settings_screen.dart',
    );
    expect(settings, isNot(contains('rateApp')));
  });

  group('2. Language', () {
    test('the calendar weekday labels stay English in Tagalog', () {
      expect(CalendarStrings.tl.weekdays, CalendarStrings.en.weekdays);
      expect(CalendarStrings.tl.months, isNot(CalendarStrings.en.months));
    });

    testWidgets('Health Journal banner changes with the language', (
      tester,
    ) async {
      await phone(tester);
      Widget app(AppLanguage l) => AppLanguageScope(
        language: l,
        child: const MaterialApp(home: JournalListScreen()),
      );
      await tester.pumpWidget(app(AppLanguage.en));
      await tester.pump();
      expect(find.text(ScreenText.en.journalBannerSubtitle), findsOneWidget);
      // switched while the screen is already open
      await tester.pumpWidget(app(AppLanguage.tl));
      await tester.pump();
      expect(find.text(ScreenText.tl.journalBannerSubtitle), findsOneWidget);
      expect(find.text(ScreenText.en.journalBannerSubtitle), findsNothing);
    });

    group('multiple injuries screen', () {
      Future<void> open(WidgetTester tester, AppLanguage l) async {
        await phone(tester);
        await tester.pumpWidget(
          AppLanguageScope(
            language: l,
            child: const MaterialApp(
              home: MultiInjuryScreen(
                imagePath: 'missing.jpg',
                woundDescriptions: ['first', 'second'],
              ),
            ),
          ),
        );
        await tester.pump();
        tester.takeException(); // the photo file isn't there in a test
      }

      testWidgets('English', (tester) async {
        await open(tester, AppLanguage.en);
        expect(find.text('Multiple injuries detected'), findsOneWidget);
        expect(
          find.text('Tap the wound you want to focus on for assessment.'),
          findsOneWidget,
        );
        expect(find.text('Select a wound to continue'), findsOneWidget);
        await tester.tap(find.text('Wound 2'));
        await tester.pump();
        expect(find.text('Selected: Wound 2'), findsOneWidget);
        expect(find.text('Assess Selected Wound'), findsOneWidget);
        // no description under the label
        expect(find.textContaining('second'), findsNothing);
      });

      testWidgets('Tagalog: the wound number stays dynamic', (tester) async {
        await open(tester, AppLanguage.tl);
        final tl = ScreenText.tl;
        expect(find.text(tl.multipleInjuries), findsOneWidget);
        expect(find.text(tl.multiTip), findsOneWidget);
        expect(find.text(tl.selectWound), findsOneWidget);
        await tester.tap(find.text('Sugat 1'));
        await tester.pump();
        expect(find.text('Napili: Sugat 1'), findsOneWidget);
        await tester.tap(find.text('Sugat 2'));
        await tester.pump();
        expect(find.text('Napili: Sugat 2'), findsOneWidget);
        expect(find.text(tl.assessSelected), findsOneWidget);
        expect(find.text('Selected: Wound 2'), findsNothing);
      });

      testWidgets('switching language while it is open updates it', (
        tester,
      ) async {
        await open(tester, AppLanguage.en);
        await tester.tap(find.text('Wound 1'));
        await tester.pump();
        await tester.pumpWidget(
          const AppLanguageScope(
            language: AppLanguage.tl,
            child: MaterialApp(
              home: MultiInjuryScreen(
                imagePath: 'missing.jpg',
                woundDescriptions: ['first', 'second'],
              ),
            ),
          ),
        );
        await tester.pump();
        tester.takeException();
        expect(find.text('Napili: Sugat 1'), findsOneWidget);
        expect(find.text('Selected: Wound 1'), findsNothing);
      });
    });

    test('the wound type is shown by its Tagalog name in Tagalog', () {
      for (final category in WoundCategories.all) {
        expect(ScreenText.en.categoryName(category), category);
        expect(
          ScreenText.tl.categoryName(category),
          isNot(category),
          reason: category,
        );
      }
      expect(ScreenText.tl.categoryName('Burn'), 'Paso');
    });

    test('every new string has a Tagalog that differs from the English', () {
      final pairs = {
        'firstAidStepsTitle': (
          ScreenText.en.firstAidStepsTitle,
          ScreenText.tl.firstAidStepsTitle,
        ),
        'disclaimerTitle': (
          ScreenText.en.disclaimerTitle,
          ScreenText.tl.disclaimerTitle,
        ),
        'disclaimerBody': (
          ScreenText.en.disclaimerBody,
          ScreenText.tl.disclaimerBody,
        ),
        'categoryLabel': (
          ScreenText.en.categoryLabel,
          ScreenText.tl.categoryLabel,
        ),
        'seekUrgent': (ScreenText.en.seekUrgent, ScreenText.tl.seekUrgent),
        'seekEmergency': (
          ScreenText.en.seekEmergency,
          ScreenText.tl.seekEmergency,
        ),
        'professionalEval': (
          ScreenText.en.professionalEval,
          ScreenText.tl.professionalEval,
        ),
        'followUpLabel': (
          ScreenText.en.followUpLabel,
          ScreenText.tl.followUpLabel,
        ),
        'describeHint': (
          ScreenText.en.describeHint,
          ScreenText.tl.describeHint,
        ),
        'saveToJournal': (
          ScreenText.en.saveToJournal,
          ScreenText.tl.saveToJournal,
        ),
        'noWoundTitle': (
          ScreenText.en.noWoundTitle,
          ScreenText.tl.noWoundTitle,
        ),
        'assessSelected': (
          ScreenText.en.assessSelected,
          ScreenText.tl.assessSelected,
        ),
      };
      pairs.forEach((name, v) => expect(v.$2, isNot(v.$1), reason: name));
      // the number / label placeholders are kept
      expect(ScreenText.tl.woundN, contains('{n}'));
      expect(ScreenText.tl.selectedWound, contains('{label}'));
      expect(ScreenText.tl.categoryLabel, contains('{category}'));
    });

    test('the AI request carries the language', () {
      expect(assessmentLanguageBlock(tagalog: false), isEmpty);
      final tl = assessmentLanguageBlock(tagalog: true);
      expect(tl, contains('Tagalog'));
      expect(tl, contains('first_aid_steps_tl'));
      expect(tl, contains('uncertainties_tl'));
      // the English fields the app reads its labels and pictures from stay
      expect(tl, contains('in English'));
    });

    test('the Tagalog steps and details in the reply are read', () {
      final a = parseWoundAssessment('''{
        "is_wound": true, "confidence": 0.9, "wound_type": "burn",
        "triage": "FIRST_AID", "red_flags": [],
        "first_aid_steps": ["Before: Wash your hands — Keeps germs away."],
        "first_aid_steps_tl": ["Before: Maghugas ng kamay — Iwas mikrobyo."],
        "uncertainties": ["blurry edge"], "uncertainties_tl": ["malabong gilid"]
      }''');
      expect(a.firstAidSteps.single, startsWith('Before:'));
      expect(a.firstAidStepsTl.single, contains('Maghugas'));
      expect(a.uncertaintiesTl.single, 'malabong gilid');
      final plain = parseWoundAssessment(
        '{"is_wound": true, "wound_type": "burn", "first_aid_steps": []}',
      );
      expect(plain.firstAidStepsTl, isEmpty);
    });

    test('the result screen passes the language and uses the new strings', () {
      final text = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(text, contains('tagalog: tagalog'));
      for (final gone in [
        "'First Aid Steps',",
        "'Disclaimer',",
        "hintText: 'Describe your concern...'",
        "'Ask a follow-up question',",
        ": 'Save to Health Journal',",
        "'Seek Urgent Medical Care'",
        "'Category: \$category'",
      ]) {
        expect(text, isNot(contains(gone)), reason: gone);
      }
      // Tagalog steps and replies show without tapping "Translate"
      expect(text, contains('AppLanguageScope.isTagalog(context)'));
      expect(text, contains('_ensureTagalogSteps'));
      expect(
        source('lib/features/camera/screens/ai_camera_screen.dart'),
        isNot(contains("Text('No Wound Detected')")),
      );
    });
  });

  group('3. Bottom bar lift', () {
    test('icons and labels moved up a little more (4 -> 8)', () {
      expect(
        source('lib/core/widgets/custom_bottom_nav_bar.dart'),
        contains('static const double _contentLift = 8;'),
      );
    });
  });

  group('4. Calendar', () {
    Future<void> openDashboard(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pumpAndSettle();
      final skip = find.byTooltip('Skip Tour');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
    }

    Finder grid() => find.byWidgetPredicate(
      (w) =>
          w is GridView &&
          w.gridDelegate is SliverGridDelegateWithFixedCrossAxisCount &&
          (w.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                  .crossAxisCount ==
              7,
    );

    for (final width in [320.0, 360.0, 430.0, 900.0]) {
      testWidgets('at ${width.toInt()} px: seven equal columns under the '
          'weekdays, equal rows, month centred, for 5 and 6 week months', (
        tester,
      ) async {
        await openDashboard(tester, width);
        final rowCounts = <int>{};

        for (var month = 0; month < 14; month++) {
          expect(tester.takeException(), isNull);
          final g = tester.getRect(grid());
          final delegate =
              tester.widget<GridView>(grid()).gridDelegate
                  as SliverGridDelegateWithFixedCrossAxisCount;
          final row = delegate.mainAxisExtent!;
          final columnWidth = g.width / 7;

          // equal rows, filling the grid exactly (no gap, no clipping)
          final rows = g.height / row;
          expect(rows, closeTo(rows.roundToDouble(), 0.001));
          rowCounts.add(rows.round());

          // each weekday is centred over its own column
          for (var i = 0; i < 7; i++) {
            final header = tester.getCenter(
              find.text(CalendarStrings.en.weekdays[i]).last,
            );
            expect(
              header.dx,
              closeTo(g.left + (i + 0.5) * columnWidth, 1),
              reason: 'weekday $i, month $month',
            );
          }

          // dates sit in the same columns as the headings
          final first = tester.getCenter(find.text('1').last);
          final column = ((first.dx - g.left) / columnWidth).floor();
          expect(column, inInclusiveRange(0, 6));
          expect(
            first.dx,
            closeTo(g.left + (column + 0.5) * columnWidth, 1),
            reason: 'day 1, month $month',
          );

          // the grid fills the card: same space on the left and the right
          final title = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                RegExp(r'^[A-Z][a-z]+ \d{4}$').hasMatch(w.data!),
          );
          expect(
            tester.getCenter(title).dx,
            closeTo(g.center.dx, 2),
            reason: 'month title, month $month',
          );

          await tester.tap(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          );
          await tester.pumpAndSettle();
        }

        // every month (5 or 6 weeks) has the same six-row grid, so the card
        // never changes size
        expect(rowCounts, {6}, reason: 'saw $rowCounts');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 2));
      });
    }
  });
}
