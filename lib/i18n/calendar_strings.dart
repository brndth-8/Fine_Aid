import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Month names, weekday headings and labels for the app's month calendars
/// (the Dashboard calendar and the Journal calendar), English + Tagalog.
/// Review the Tagalog before release.
class CalendarStrings {
  /// January to December.
  final List<String> months;

  /// Sunday to Saturday, two letters each.
  final List<String> weekdays;
  final String today;
  final String jumpToToday;

  const CalendarStrings({
    required this.months,
    required this.weekdays,
    required this.today,
    required this.jumpToToday,
  });

  static CalendarStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  /// "October 5" / "Oktubre 5".
  String monthDay(DateTime date) => '${months[date.month - 1]} ${date.day}';

  static const en = CalendarStrings(
    months: [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    weekdays: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
    today: 'Today',
    jumpToToday: 'Back to today',
  );

  static const tl = CalendarStrings(
    months: [
      'Enero',
      'Pebrero',
      'Marso',
      'Abril',
      'Mayo',
      'Hunyo',
      'Hulyo',
      'Agosto',
      'Setyembre',
      'Oktubre',
      'Nobyembre',
      'Disyembre',
    ],
    // Linggo, Lunes, Martes, Miyerkules, Huwebes, Biyernes, Sabado.
    weekdays: ['Li', 'Lu', 'Ma', 'Mi', 'Hu', 'Bi', 'Sa'],
    today: 'Ngayon',
    jumpToToday: 'Bumalik sa ngayon',
  );
}
