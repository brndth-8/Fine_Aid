import 'dart:io';

import 'package:fine_aid/features/admin/screens/sections/admin_notifications.dart';
import 'package:fine_aid/services/firebase/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Push notifications: the link in a push, and that the admin portal, the
/// phone app and the server agree on the same list of links.
void main() {
  group('where a tapped push opens', () {
    test('our links open the screen they name', () {
      expect(appLinkTarget('fineaid://notifications'), 'notifications');
      expect(appLinkTarget('fineaid://journal'), 'journal');
    });

    test('anything else is never followed', () {
      expect(appLinkTarget(null), isNull);
      expect(appLinkTarget(''), isNull);
      expect(appLinkTarget('https://example.com'), isNull);
      expect(appLinkTarget('fineaid://admin'), isNull);
      expect(appLinkTarget('fineaid://journal/../x'), isNull);
    });
  });

  test('the admin portal offers exactly the links the app understands', () {
    final offered = kNotificationLinks.map((l) => l.$2).toSet();
    expect(offered, {kLinkNotifications, kLinkJournal});
    for (final link in offered) {
      expect(appLinkTarget(link), isNotNull, reason: link);
    }
  });

  test('the server accepts exactly the same links', () {
    final server = File('functions/lib/jobs.js').readAsStringSync();
    for (final link in [kLinkNotifications, kLinkJournal]) {
      expect(server, contains('"$link"'), reason: link);
    }
    final index = File('functions/index.js').readAsStringSync();
    for (final link in [kLinkNotifications, kLinkJournal]) {
      expect(index, contains('"$link"'), reason: link);
    }
  });

  test('the database rules cover devices and the private schedule list', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('match /devices/{deviceId}'));
    expect(rules, contains('match /scheduledNotifications/{notifId}'));
    final indexes = File('firestore.indexes.json').readAsStringSync();
    expect(indexes, contains('"scheduledNotifications"'));
  });

  test('the phone app registers its token and cleans up on account change', () {
    final app = File(
      'lib/services/firebase/notification_service.dart',
    ).readAsStringSync();
    expect(app, contains("collection('devices')"));
    expect(app, contains('onTokenRefresh'));
    expect(app, contains('deleteToken'));
    expect(app, contains('onMessageOpenedApp'));
    expect(app, contains('getInitialMessage'));
  });
}
