import 'dart:io';

import 'package:fine_aid/features/camera/screens/ai_camera_screen.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/i18n/tour_strings.dart';
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

  group('2. The AI Vision Camera disclaimer follows the language', () {
    Future<void> open(WidgetTester tester, AppLanguage l) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: l,
          child: const MaterialApp(home: AiCameraScreen()),
        ),
      );
      await tester.pump();
      tester.takeException(); // no camera in a test
    }

    testWidgets('English, then Tagalog while it is open, then English', (
      tester,
    ) async {
      await open(tester, AppLanguage.en);
      expect(find.text('Medical Disclaimer'), findsOneWidget);
      expect(
        find.text(
          'This is only for initial assessment and not for diagnosis. '
          'Seek professional help.',
        ),
        findsOneWidget,
      );

      Future<void> switchTo(AppLanguage l) async {
        await tester.pumpWidget(
          AppLanguageScope(
            language: l,
            child: const MaterialApp(home: AiCameraScreen()),
          ),
        );
        await tester.pump();
        tester.takeException();
      }

      await switchTo(AppLanguage.tl);
      expect(find.text(ScreenText.tl.cameraDisclaimerTitle), findsOneWidget);
      expect(find.text(ScreenText.tl.cameraDisclaimerBody), findsOneWidget);
      expect(find.text('Medical Disclaimer'), findsNothing);

      await switchTo(AppLanguage.en);
      expect(find.text('Medical Disclaimer'), findsOneWidget);
      expect(find.text(ScreenText.tl.cameraDisclaimerTitle), findsNothing);
    });

    test('the full Tagalog text is there, and nothing is hard-coded', () {
      expect(ScreenText.tl.cameraDisclaimerTitle, isNot('Medical Disclaimer'));
      expect(
        ScreenText.tl.cameraDisclaimerBody,
        isNot(ScreenText.en.cameraDisclaimerBody),
      );
      final camera = source(
        'lib/features/camera/screens/ai_camera_screen.dart',
      );
      expect(camera, isNot(contains("'Medical Disclaimer'")));
      expect(
        camera,
        isNot(contains('initial assessment and not for diagnosis')),
      );
    });
  });

  group('3. The calendar month stays English', () {
    final title = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^[A-Z][a-z]+ \d{4}$').hasMatch(w.data!),
    );

    testWidgets('dashboard calendar, in Tagalog', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const AppLanguageScope(
          language: AppLanguage.tl,
          child: MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final skip = find.byTooltip(TourStrings.tl.skipTour);
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(
        find.text('${CalendarStrings.en.months[now.month - 1]} ${now.year}'),
        findsOneWidget,
      );
      expect(
        find.text('${CalendarStrings.tl.months[now.month - 1]} ${now.year}'),
        findsNothing,
      );
      // and the weekday labels too
      for (final d in CalendarStrings.en.weekdays) {
        expect(find.text(d), findsWidgets, reason: d);
      }
      // next month's name is English as well
      final nextButton = find.widgetWithIcon(IconButton, Icons.chevron_right);
      await tester.ensureVisible(nextButton);
      await tester.pumpAndSettle();
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      final next = DateTime(now.year, now.month + 1);
      expect(
        find.text('${CalendarStrings.en.months[next.month - 1]} ${next.year}'),
        findsOneWidget,
      );
      expect(title, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });

    test(
      'the Journal calendar (shown to signed-in people) uses English too',
      () {
        final text = source(
          'lib/features/journal/screens/day_entries_screen.dart',
        );
        expect(
          text,
          contains('CalendarStrings.en.months[_displayedMonth.month - 1]'),
        );
        expect(text, isNot(contains('c.months[')));
      },
    );

    test('the other calendar text (not the month) is still translated', () {
      expect(CalendarStrings.tl.months, isNot(CalendarStrings.en.months));
      expect(
        CalendarStrings.tl.jumpToToday,
        isNot(CalendarStrings.en.jumpToToday),
      );
    });
  });
}
