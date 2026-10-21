import 'package:fine_aid/core/widgets/app_date_picker.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/date_picker_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = DatePickerStrings.en;

  group('typed dates', () {
    test('MM/DD/YYYY is read, impossible dates are not', () {
      expect(parseDateInput('10/05/2026'), DateTime(2026, 10, 5));
      expect(parseDateInput('1/5/2026'), DateTime(2026, 1, 5));
      expect(parseDateInput('02/29/2028'), DateTime(2028, 2, 29)); // leap year
      for (final bad in [
        '',
        '13/01/2026',
        '00/10/2026',
        '02/30/2026',
        '02/29/2027',
        '10-05-2026',
        '10/05/26',
        'ab/cd/efgh',
      ]) {
        expect(parseDateInput(bad), isNull, reason: bad);
      }
    });

    test('formatting round-trips', () {
      expect(formatDateInput(DateTime(2026, 3, 7)), '03/07/2026');
      expect(
        parseDateInput(formatDateInput(DateTime(2026, 3, 7))),
        DateTime(2026, 3, 7),
      );
    });
  });

  // Opens a picker and returns what it answered through [result].
  late Object? result;
  late bool answered;

  Future<void> open(
    WidgetTester tester, {
    bool range = false,
    DateTime? initial,
    DateTimeRange? initialRange,
    DateTime? first,
    DateTime? last,
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    result = null;
    answered = false;
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  if (range) {
                    result = await showAppDateRangePicker(
                      context,
                      initial: initialRange,
                      firstDate: first ?? DateTime(2026, 1, 1),
                      lastDate: last ?? DateTime(2026, 12, 31),
                    );
                  } else {
                    result = await showAppDatePicker(
                      context,
                      initial: initial,
                      firstDate: first ?? DateTime(2026, 1, 1),
                      lastDate: last ?? DateTime(2026, 12, 31),
                    );
                  }
                  answered = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder day(int y, int m, int d) => find.byKey(ValueKey('day-$y-$m-$d'));

  ElevatedButton okButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, en.ok));

  group('single date', () {
    testWidgets('tap a day on the calendar, press OK', (tester) async {
      await open(tester, initial: DateTime(2026, 10, 5));
      await tester.tap(day(2026, 10, 14));
      await tester.pump();
      // the typed field follows the calendar
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('start-field')))
            .controller!
            .text,
        '10/14/2026',
      );
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 14));
    });

    testWidgets('type a date and the calendar follows', (tester) async {
      await open(tester, initial: DateTime(2026, 10, 5));
      await tester.enterText(
        find.byKey(const ValueKey('start-field')),
        '03082026',
      );
      await tester.pumpAndSettle();
      // formatted with slashes while typing, and the calendar moved to March
      expect(find.text('03/08/2026'), findsOneWidget);
      expect(find.text('${CalendarStrings.en.months[2]} 2026'), findsOneWidget);
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 3, 8));
    });

    testWidgets('an invalid date shows an error and blocks OK', (tester) async {
      await open(tester, initial: DateTime(2026, 10, 5));
      await tester.enterText(
        find.byKey(const ValueKey('start-field')),
        '02302026',
      );
      await tester.pump();
      expect(find.text(en.invalidDate), findsOneWidget);
      expect(okButton(tester).onPressed, isNull);
    });

    testWidgets('a date outside the allowed range is refused', (tester) async {
      await open(
        tester,
        initial: DateTime(2026, 10, 5),
        first: DateTime(2026, 6, 1),
        last: DateTime(2026, 10, 20),
      );
      await tester.enterText(
        find.byKey(const ValueKey('start-field')),
        '12252026',
      );
      await tester.pump();
      expect(find.textContaining('on or before 10/20/2026'), findsOneWidget);
      expect(okButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('start-field')),
        '01012026',
      );
      await tester.pump();
      expect(find.textContaining('on or after 06/01/2026'), findsOneWidget);
    });

    testWidgets('days outside the limits cannot be tapped', (tester) async {
      await open(
        tester,
        initial: DateTime(2026, 10, 5),
        first: DateTime(2026, 10, 3),
        last: DateTime(2026, 10, 20),
      );
      await tester.tap(day(2026, 10, 25), warnIfMissed: false); // too late
      await tester.tap(day(2026, 10, 1), warnIfMissed: false); // too early
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('start-field')))
            .controller!
            .text,
        '10/05/2026',
      );
    });

    testWidgets('month arrows stop at the limits', (tester) async {
      await open(
        tester,
        initial: DateTime(2026, 10, 5),
        first: DateTime(2026, 9, 1),
        last: DateTime(2026, 11, 30),
      );
      IconButton arrow(IconData icon) =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
      expect(arrow(Icons.chevron_left).onPressed, isNull);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
      expect(arrow(Icons.chevron_right).onPressed, isNull);
    });

    testWidgets('Cancel returns nothing', (tester) async {
      await open(tester, initial: DateTime(2026, 10, 5));
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(result, isNull);
    });
  });

  group('date range', () {
    testWidgets('two taps pick the range and it is highlighted', (
      tester,
    ) async {
      await open(tester, range: true);
      expect(okButton(tester).onPressed, isNull);
      await tester.tap(day(2026, 10, 10));
      await tester.pump();
      expect(okButton(tester).onPressed, isNull, reason: 'no end yet');
      await tester.tap(day(2026, 10, 15));
      await tester.pump();
      expect(okButton(tester).onPressed, isNotNull);
      expect(find.text('10/10/2026'), findsOneWidget);
      expect(find.text('10/15/2026'), findsOneWidget);

      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(
        result,
        DateTimeRange(
          start: DateTime(2026, 10, 10),
          end: DateTime(2026, 10, 15),
        ),
      );
    });

    testWidgets('tapping an earlier day second makes it the new start', (
      tester,
    ) async {
      await open(tester, range: true);
      await tester.tap(day(2026, 10, 15));
      await tester.tap(day(2026, 10, 10));
      await tester.pump();
      expect(find.text('10/10/2026'), findsOneWidget);
      expect(okButton(tester).onPressed, isNull, reason: 'end still needed');
    });

    testWidgets('a single day is a valid range', (tester) async {
      await open(tester, range: true);
      await tester.tap(day(2026, 10, 12));
      await tester.tap(day(2026, 10, 12));
      await tester.pump();
      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();
      expect(
        result,
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 12),
        ),
      );
    });

    testWidgets('typing both ends works; end before start is an error', (
      tester,
    ) async {
      await open(tester, range: true);
      await tester.enterText(
        find.byKey(const ValueKey('start-field')),
        '10202026',
      );
      await tester.enterText(
        find.byKey(const ValueKey('end-field')),
        '10102026',
      );
      await tester.pump();
      expect(find.text(en.endBeforeStart), findsOneWidget);
      expect(okButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('end-field')),
        '10252026',
      );
      await tester.pump();
      expect(find.text(en.endBeforeStart), findsNothing);
      expect(okButton(tester).onPressed, isNotNull);
    });

    testWidgets('an existing range is shown filled in', (tester) async {
      await open(
        tester,
        range: true,
        initialRange: DateTimeRange(
          start: DateTime(2026, 10, 3),
          end: DateTime(2026, 10, 9),
        ),
      );
      expect(find.text('10/03/2026'), findsOneWidget);
      expect(find.text('10/09/2026'), findsOneWidget);
      expect(okButton(tester).onPressed, isNotNull);
    });
  });

  group('language', () {
    testWidgets('Tagalog month and weekday names and texts', (tester) async {
      await open(
        tester,
        initial: DateTime(2026, 10, 5),
        language: AppLanguage.tl,
      );
      final tl = DatePickerStrings.tl;
      expect(find.text('Oktubre 2026'), findsOneWidget);
      for (final name in CalendarStrings.tl.weekdays.toSet()) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.text(tl.titleSingle), findsOneWidget);
      expect(find.text(tl.cancel), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);
    });

    test('every text is translated', () {
      final tl = DatePickerStrings.tl;
      expect(tl.titleSingle, isNot(en.titleSingle));
      expect(tl.titleRange, isNot(en.titleRange));
      expect(tl.invalidDate, isNot(en.invalidDate));
      expect(tl.endBeforeStart, isNot(en.endBeforeStart));
      expect(tl.cancel, isNot(en.cancel));
    });
  });
}
