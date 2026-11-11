import 'package:fine_aid/core/widgets/app_date_picker.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/date_picker_strings.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'date_boxes_helpers.dart';

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

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    AppLanguage language = AppLanguage.en,
  }) async {
    _ignoreListTileInkWarning();
    // wide, because the test font draws text much wider than a real one
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  final en = DatePickerStrings.en;

  group('New Entry date', () {
    final today = DateUtils.dateOnly(DateTime.now());
    final journal = JournalEntryStrings.en;

    Future<void> openEntry(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
    }) async {
      await pump(tester, const NewEntryScreen(), language: language);
      // the guest notice shown on entry
      await tester.tap(
        find.text(ScreenText.forLanguage(language).continueAsGuest),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows today, and tapping it opens the picker', (tester) async {
      await openEntry(tester);
      expect(find.text(journal.formatDate(today)), findsOneWidget);
      await tester.tap(find.text(journal.formatDate(today)));
      await tester.pumpAndSettle();
      expect(find.text(en.titleSingle), findsOneWidget);
    });

    testWidgets('an earlier date can be chosen and is shown', (tester) async {
      await openEntry(tester);
      await tester.tap(find.text(journal.formatDate(today)));
      await tester.pumpAndSettle();
      final earlier = today.subtract(const Duration(days: 3));
      await enterDate(
        tester,
        'start',
        formatDateInput(earlier).replaceAll('/', ''),
      );
      await tester.pump();
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(find.text(journal.formatDate(earlier)), findsOneWidget);
    });

    testWidgets('a future date is refused', (tester) async {
      await openEntry(tester);
      await tester.tap(find.text(journal.formatDate(today)));
      await tester.pumpAndSettle();
      final later = today.add(const Duration(days: 3));
      await enterDate(
        tester,
        'start',
        formatDateInput(later).replaceAll('/', ''),
      );
      await tester.pump();
      expect(find.textContaining('on or before'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, en.ok))
            .onPressed,
        isNull,
      );
    });

    testWidgets('more than a year back is refused', (tester) async {
      await openEntry(tester);
      await tester.tap(find.text(journal.formatDate(today)));
      await tester.pumpAndSettle();
      final old = today.subtract(const Duration(days: 500));
      await enterDate(
        tester,
        'start',
        formatDateInput(old).replaceAll('/', ''),
      );
      await tester.pump();
      expect(find.textContaining('on or after'), findsOneWidget);
    });

    testWidgets('Cancel keeps the date', (tester) async {
      await openEntry(tester);
      await tester.tap(find.text(journal.formatDate(today)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.cancel),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(journal.formatDate(today)), findsOneWidget);
    });

    testWidgets('the date and the picker are in Tagalog', (tester) async {
      await openEntry(tester, language: AppLanguage.tl);
      final tlJournal = JournalEntryStrings.tl;
      await tester.tap(find.text(tlJournal.formatDate(today)));
      await tester.pumpAndSettle();
      expect(find.text(DatePickerStrings.tl.titleSingle), findsOneWidget);
      // Month names stay in English, even in Filipino.
      expect(
        find.text(
          '${CalendarStrings.en.months[today.month - 1]} ${today.year}',
        ),
        findsOneWidget,
      );
    });
  });

  group('Dashboard calendar', () {
    testWidgets('tapping the month opens the picker and jumps to the date', (
      tester,
    ) async {
      await pump(tester, const DashboardScreen());
      // A guest sees the Help Tour first; skip it.
      final skip = find.byTooltip('Skip Tour');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip);
        await tester.pumpAndSettle();
      }
      final now = DateTime.now();
      final title = '${CalendarStrings.en.months[now.month - 1]} ${now.year}';
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text(en.titleSingle), findsOneWidget);

      await enterDate(tester, 'start', '03152026');
      await tester.pump();
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      // Let the dashboard's own timers run out before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  });

  group('Journal list filter', () {
    testWidgets('has a date-range filter that can be set and cleared', (
      tester,
    ) async {
      await pump(tester, const JournalListScreen());
      final j = JournalEntryStrings.en;
      expect(find.text(j.filterByDate), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text(j.filterByDate));
      await tester.pumpAndSettle();
      expect(find.text(en.titleRange), findsOneWidget);

      await enterDate(tester, 'start', '01012026');
      await enterDate(tester, 'end', '01312026');
      await tester.pump();
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(find.text('01/01/2026 – 01/31/2026'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text(j.filterByDate), findsOneWidget);
    });

    testWidgets('the filter texts are translated', (tester) async {
      await pump(tester, const JournalListScreen(), language: AppLanguage.tl);
      expect(find.text(JournalEntryStrings.tl.filterByDate), findsOneWidget);
      expect(
        JournalEntryStrings.tl.noEntriesInRange,
        isNot(JournalEntryStrings.en.noEntriesInRange),
      );
    });
  });
}
