import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/services/firebase/notification_service.dart';
import 'package:fine_aid/services/notification_inbox_store.dart';
import 'package:fine_aid/features/dashboard/screens/notifications_screen.dart';

void main() {
  group('healingMilestoneBody', () {
    test('uses the exact default sentence when no wound type is given', () {
      expect(healingMilestoneBody(null), healingMilestoneDefaultBody);
      expect(healingMilestoneBody(''), healingMilestoneDefaultBody);
    });

    test('folds in the wound type when available', () {
      expect(
        healingMilestoneBody('Burn'),
        'Your Burn has reached its healing time frame. Are you feeling '
        'better?',
      );
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
        title: healingMilestoneTitle,
        body: healingMilestoneBody('Burn'),
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
