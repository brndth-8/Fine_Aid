import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the date picker pop-up (titles, field labels, errors, buttons),
/// English + Tagalog. Month and weekday names come from calendar_strings.dart
/// (one source for every calendar in the app). Review the Tagalog before
/// release.
class DatePickerStrings {
  final String titleSingle;
  final String titleRange;
  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final String hint;
  final String invalidDate;
  final String endBeforeStart;
  final String onOrAfterFormat; // {date}
  final String onOrBeforeFormat; // {date}
  final String cancel;
  final String ok;
  final String previousMonth;
  final String nextMonth;

  const DatePickerStrings({
    required this.titleSingle,
    required this.titleRange,
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.hint,
    required this.invalidDate,
    required this.endBeforeStart,
    required this.onOrAfterFormat,
    required this.onOrBeforeFormat,
    required this.cancel,
    required this.ok,
    required this.previousMonth,
    required this.nextMonth,
  });

  static DatePickerStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = DatePickerStrings(
    titleSingle: 'Select date',
    titleRange: 'Select date range',
    dateLabel: 'Date',
    startLabel: 'Start date',
    endLabel: 'End date',
    hint: 'MM/DD/YYYY',
    invalidDate: 'Please enter a valid date',
    endBeforeStart: 'End date must be after the start date',
    onOrAfterFormat: 'Date must be on or after {date}',
    onOrBeforeFormat: 'Date must be on or before {date}',
    cancel: 'Cancel',
    ok: 'OK',
    previousMonth: 'Previous month',
    nextMonth: 'Next month',
  );

  static const tl = DatePickerStrings(
    titleSingle: 'Pumili ng petsa',
    titleRange: 'Pumili ng saklaw ng petsa',
    dateLabel: 'Petsa',
    startLabel: 'Simula',
    endLabel: 'Katapusan',
    hint: 'MM/DD/YYYY',
    invalidDate: 'Maglagay ng wastong petsa',
    endBeforeStart: 'Dapat pagkatapos ng simula ang petsa ng katapusan',
    onOrAfterFormat: 'Dapat sa o pagkatapos ng {date} ang petsa',
    onOrBeforeFormat: 'Dapat sa o bago ang {date} ang petsa',
    cancel: 'Kanselahin',
    ok: 'OK',
    previousMonth: 'Nakaraang buwan',
    nextMonth: 'Susunod na buwan',
  );
}
