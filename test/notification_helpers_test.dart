import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/i18n/notification_strings.dart';
import 'package:fine_aid/services/notification_inbox_store.dart';
import 'package:fine_aid/features/dashboard/screens/notifications_screen.dart';

void main() {
  group('check-in wording', () {
    test('the notification only asks "Are you feeling better?"', () {
      expect(NotificationStrings.en.checkInBody, 'Are you feeling better?');
      expect(NotificationStrings.en.actionBetter, 'Feeling Better');
      expect(NotificationStrings.en.actionNotYet, 'Not Yet');
      expect(NotificationStrings.en.actionWorse, 'It\'s Worse');
    });
  });

  group('AppNotification.isVisible', () {
    test('visible when there is no scheduledFor', () {
      final n = AppNotification(
        id: '1',
        type: AppNotificationType.reminder,
        title: 't',
        body: 'b',
        createdAt: DateTime.now(),
      );
      expect(n.isVisible, isTrue);
    });

    test('hidden while scheduledFor is still in the future', () {
      final n = AppNotification(
        id: '1',
        type: AppNotificationType.healingMilestone,
        title: 't',
        body: 'b',
        createdAt: DateTime.now(),
        scheduledFor: DateTime.now().add(const Duration(days: 1)),
      );
      expect(n.isVisible, isFalse);
    });

    test('visible once scheduledFor has passed', () {
      final n = AppNotification(
        id: '1',
        type: AppNotificationType.healingMilestone,
        title: 't',
        body: 'b',
        createdAt: DateTime.now(),
        scheduledFor: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(n.isVisible, isTrue);
    });
  });

  group('AppNotification JSON round-trip', () {
    test('serializes and deserializes without losing data', () {
      final original = AppNotification(
        id: 'healing_abc_end',
        type: AppNotificationType.healingMilestone,
        title: NotificationStrings.en.checkInTitle,
        body: NotificationStrings.en.checkInBody,
        createdAt: DateTime(2026, 1, 1, 9),
        scheduledFor: DateTime(2026, 1, 2, 9),
        entryId: 'abc',
        woundTypeLabel: 'Burn',
        isRead: true,
        readAt: DateTime(2026, 1, 2, 10),
      );

      final restored = AppNotification.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.entryId, original.entryId);
      expect(restored.woundTypeLabel, original.woundTypeLabel);
      expect(restored.isRead, isTrue);
      expect(restored.scheduledFor, original.scheduledFor);
    });

    test('a malformed/missing type falls back to reminder, never crashes', () {
      final restored = AppNotification.fromJson({'id': 'x'});
      expect(restored.type, AppNotificationType.reminder);
      expect(restored.title, 'Notification');
    });
  });

  group('announcements for a new account', () {
    final created = DateTime(2026, 10, 1, 12);

    test('sent before the account existed -> not shown', () {
      expect(
        isAnnouncementForAccount(DateTime(2026, 9, 30, 11, 34), created),
        isFalse,
      );
      expect(
        isAnnouncementForAccount(DateTime(2026, 10, 1, 11, 59), created),
        isFalse,
      );
    });

    test('sent at or after the account was created -> shown', () {
      expect(isAnnouncementForAccount(created, created), isTrue);
      expect(
        isAnnouncementForAccount(DateTime(2026, 10, 5, 9), created),
        isTrue,
      );
    });

    test('unknown creation time -> nothing is hidden', () {
      expect(isAnnouncementForAccount(DateTime(2020), null), isTrue);
    });
  });

  group('friendlyNotificationTime', () {
    test('formats today as "Today, ..."', () {
      final now = DateTime.now();
      expect(friendlyNotificationTime(now), startsWith('Today,'));
    });

    test('formats yesterday as "Yesterday, ..."', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(friendlyNotificationTime(yesterday), startsWith('Yesterday,'));
    });
  });
}
