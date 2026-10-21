import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'both languages have 12 months and 7 weekday headings, Sunday first',
    () {
      for (final c in [CalendarStrings.en, CalendarStrings.tl]) {
        expect(c.months.length, 12);
        expect(c.weekdays.length, 7);
        expect(c.months.toSet().length, 12);
        expect(c.weekdays.toSet().length, 7);
      }
      expect(CalendarStrings.en.weekdays.first, 'Su');
      expect(CalendarStrings.tl.weekdays.first, 'Li'); // Linggo
      expect(CalendarStrings.tl.weekdays.last, 'Sa'); // Sabado
    },
  );

  test('Tagalog is actually translated', () {
    expect(CalendarStrings.tl.months[0], 'Enero');
    expect(CalendarStrings.tl.months[9], 'Oktubre');
    expect(CalendarStrings.tl.today, isNot(CalendarStrings.en.today));
    expect(
      CalendarStrings.tl.jumpToToday,
      isNot(CalendarStrings.en.jumpToToday),
    );
  });

  test('monthDay reads "October 5" / "Oktubre 5"', () {
    final d = DateTime(2026, 10, 5);
    expect(CalendarStrings.en.monthDay(d), 'October 5');
    expect(CalendarStrings.tl.monthDay(d), 'Oktubre 5');
  });
}
