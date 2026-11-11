import 'package:flutter/widgets.dart';
import '../i18n/calendar_strings.dart';
import '../i18n/notification_strings.dart';
import '../services/firebase/notification_service.dart';

/// "Reminder set: we will check in on October 28, 2026 at 9:00 AM." — shown
/// after an entry is saved, so the person knows when the first notification
/// will arrive.
String reminderScheduledMessage(BuildContext context, DateTime due) {
  final months = CalendarStrings.of(context).months;
  final when = '${months[due.month - 1]} ${due.day}, ${due.year}';
  return NotificationStrings.of(
    context,
  ).reminderScheduled.replaceFirst('{date}', when);
}

/// Sets the "reminder set" message and shows it as a real notification right
/// away (the notification is what the reminders will look like when they
/// arrive). Returns the message, for the snackbar.
Future<String> announceReminderSet(
  BuildContext context, {
  required String entryId,
  required DateTime due,
}) async {
  final text = NotificationStrings.of(context);
  final message = reminderScheduledMessage(context, due);
  await NotificationService().showReminderSet(
    entryId: entryId,
    title: text.reminderSetTitle,
    body: message,
  );
  return message;
}
