import 'dart:io';

import 'package:fine_aid/data/healing_durations.dart';
import 'package:fine_aid/i18n/notification_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:fine_aid/services/firebase/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app asked Android to do, recorded from the notification plugin's
/// channel, so these tests run the real scheduling code and check exactly
/// which notifications would be set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'canScheduleExactNotifications' => false,
            'areNotificationsEnabled' => true,
            _ => null,
          };
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  setUp(() {
    // On a phone the app's plugin registrant installs the Android
    // implementation; here it is installed by hand.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    calls.clear();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  List<Map<dynamic, dynamic>> scheduled() => [
    for (final c in calls)
      if (c.method == 'zonedSchedule') c.arguments as Map<dynamic, dynamic>,
  ];

  Future<({List<int> ids, DateTime? checkInAt})> schedule(
    String category,
    int days, {
    DateTime? from,
    bool overdueNextMorning = false,
  }) => NotificationService().scheduleCheckInSeries(
    uid: 'user1',
    entryId: 'entry-$category',
    classification: category,
    healingDays: days,
    from: from ?? DateTime.now(),
    nextMorningIfOverdue: overdueNextMorning,
  );

  final en = NotificationStrings.en;

  test('a laceration: the check-in, a halfway nudge and a daily wound-care '
      'reminder', () async {
    final result = await schedule(WoundCategories.laceration, 10);

    final all = scheduled();
    // 1 check-in + 1 halfway + 9 daily reminders (days 1 to 9)
    expect(all.length, 11);
    expect(result.ids.length, 11);
    expect(result.ids.toSet().length, 11, reason: 'every id is different');

    final checkIns = all.where((a) => a['body'] == en.checkInBody).toList();
    expect(checkIns.length, 2);
    expect(checkIns.every((a) => a['title'] == en.checkInTitle), isTrue);
    expect(en.checkInBody, 'How are you feeling?');

    final care = all.where((a) => a['body'] == en.woundCareBody).toList();
    expect(care.length, 9);
    expect(care.every((a) => a['title'] == en.woundCareTitle), isTrue);
    expect(en.woundCareBody, "It's time to clean your wound.");

    // the check-in at the end of the 10 days, at 9:00 a.m.
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 10, 9);
    expect(result.checkInAt, due);
  });

  test('every scheduled time is in the future, and the daily reminders are '
      'one day apart', () async {
    await schedule(WoundCategories.laceration, 10);
    final times = [
      for (final a in scheduled().where((a) => a['body'] == en.woundCareBody))
        DateTime.parse(a['scheduledDateTime'] as String),
    ]..sort();
    expect(times.every((t) => t.isAfter(DateTime.now().toUtc())), isTrue);
    for (var i = 1; i < times.length; i++) {
      // a day apart (the clocks changing can make it 23 or 25 hours)
      final gap = times[i].difference(times[i - 1]).inHours;
      expect(gap, inInclusiveRange(23, 25));
    }
  });

  test('a bruise has no wound to clean: only the check-ins', () async {
    final result = await schedule(WoundCategories.bruise, 10);
    expect(scheduled().length, 2);
    expect(result.ids.length, 2);
    expect(scheduled().any((a) => a['body'] == en.woundCareBody), isFalse);
  });

  test('a one-day healing time: just the check-in', () async {
    final result = await schedule(WoundCategories.minorCut, 1);
    expect(scheduled().length, 1);
    final now = DateTime.now();
    expect(result.checkInAt, DateTime(now.year, now.month, now.day + 1, 9));
  });

  test(
    'the "reminder set" notification is shown at once, with the entry',
    () async {
      await NotificationService().showReminderSetFor(
        uid: 'user1',
        entryId: 'entry-1',
        title: en.reminderSetTitle,
        body: 'Reminder set: we will check in on October 28, 2026 at 9:00 AM.',
      );
      final shown = [
        for (final c in calls)
          if (c.method == 'show') c,
      ];
      expect(shown.length, 1);
      final args = shown.single.arguments as Map;
      expect(args['title'], 'Reminder set');
      expect(args['payload'], buildHealingPayload('user1', 'entry-1'));
      expect(scheduled(), isEmpty, reason: 'shown now, not scheduled');
    },
  );

  test('burn healing time is 10 days', () {
    expect(healingDurationDays[WoundCategories.burn], 10);
  });

  test('the check-in offers the three answers', () async {
    await schedule(WoundCategories.minorCut, 7);
    final withActions = scheduled().first['platformSpecifics'] as Map;
    final actions = withActions['actions'] as List;
    expect(
      [for (final a in actions) (a as Map)['title']],
      ['Feeling better', 'No change', 'Getting worse'],
    );
  });

  test('a time already past is sent the next morning, not dropped', () async {
    final result = await schedule(
      WoundCategories.minorCut,
      7,
      from: DateTime.now().subtract(const Duration(days: 20)),
      overdueNextMorning: true,
    );
    expect(scheduled().length, 1);
    expect(result.checkInAt!.hour, 9);
    expect(result.checkInAt!.isAfter(DateTime.now()), isTrue);
    expect(
      result.checkInAt!.difference(DateTime.now()).inHours,
      lessThanOrEqualTo(24),
    );
  });

  test('without that, a time already past schedules nothing', () async {
    final result = await schedule(
      WoundCategories.minorCut,
      7,
      from: DateTime.now().subtract(const Duration(days: 20)),
    );
    expect(scheduled(), isEmpty);
    expect(result.ids, isEmpty);
    expect(result.checkInAt, isNull);
  });

  test(
    'cancelling an entry cancels every id its reminders were scheduled with',
    () async {
      final result = await schedule(WoundCategories.laceration, 10);
      calls.clear();
      await NotificationService().cancelHealingCheckIn(
        'entry-${WoundCategories.laceration}',
      );
      final cancelled = {
        for (final c in calls)
          if (c.method == 'cancel')
            (c.arguments is Map ? (c.arguments as Map)['id'] : c.arguments)
                as int,
      };
      for (final id in result.ids) {
        expect(cancelled, contains(id));
      }
    },
  );

  group('every journal category has a healing time', () {
    test('the Add new entry categories', () {
      expect(healingDaysFor('Scratch'), 5);
      expect(healingDaysFor('Burns'), healingDurationDays['Burn']);
      expect(healingDaysFor('Skin Issues'), healingDurationDays['Rash']);
      expect(healingDaysFor('Animal Scratch'), healingDurationDays['Scratch']);
      expect(
        healingDaysFor('Injury (Wounds/laceration/Abrasion)', severity: 'Deep'),
        healingDurationDays['Laceration'],
      );
      expect(
        healingDaysFor(
          'Injury (Wounds/laceration/Abrasion)',
          severity: 'Minor',
        ),
        healingDurationDays['Minor Cut'],
      );
    });

    test('the names the AI scan and the Health Kit save still work', () {
      for (final name in healingDurationDays.keys) {
        expect(healingDaysFor(name), healingDurationDays[name], reason: name);
      }
    });

    test('a type with no standard time has none', () {
      expect(healingDaysFor('Other Skin Issue'), isNull);
      expect(healingDaysFor('Unable to Classify'), isNull);
      expect(healingDaysFor(null), isNull);
    });

    test(
      'an Injury gets the open-wound reminder through its mapped category',
      () {
        expect(
          woundCareCategories.contains(
            healingCategoryFor(
              'Injury (Wounds/laceration/Abrasion)',
              severity: 'Minor',
            ),
          ),
          isTrue,
        );
        expect(
          woundCareCategories.contains(healingCategoryFor('Skin Issues')),
          isFalse,
        );
      },
    );
  });

  group('every way of saving an entry sets its reminders', () {
    String source(String path) => File(path).readAsStringSync();

    test('the journal and the AI scan schedule on save (the offline Health Kit '
        'saves nothing)', () {
      for (final path in [
        'lib/features/journal/screens/new_entry_screen.dart',
        'lib/features/camera/screens/assessment_result_screen.dart',
      ]) {
        final text = source(path);
        expect(text, contains('scheduleForEntry('), reason: path);
        expect(
          text,
          contains('ensureHealingReminderPermission('),
          reason: path,
        );
        expect(text, isNot(contains('scheduleHealingCheckIn')), reason: path);
      }
    });

    test('Remind me starts on in the journal; the Health Kit has none', () {
      expect(
        source('lib/features/journal/screens/new_entry_screen.dart'),
        contains('bool _remindMe = true;'),
      );
      expect(
        source('lib/features/dashboard/first_aid_kit_screen.dart'),
        isNot(contains('_remindMe')),
      );
    });

    test('the AI scan saves "remindMe: true"', () {
      expect(
        source('lib/features/camera/screens/assessment_result_screen.dart'),
        contains("'remindMe': true"),
      );
    });

    test('editing reschedules and deleting cancels', () {
      expect(
        source('lib/features/journal/screens/edit_entry_screen.dart'),
        contains('rescheduleForEntry('),
      );
      expect(
        source('lib/features/journal/screens/journal_list_screen.dart'),
        contains('cancelHealingCheckIn('),
      );
    });

    test('the notification ids are worked out, not stored on the entry', () {
      expect(
        source('lib/services/firebase/notification_service.dart'),
        isNot(contains("'notificationIds'")),
      );
    });

    test('a notification shows right away when the reminders are set', () {
      for (final path in [
        'lib/features/journal/screens/new_entry_screen.dart',
        'lib/features/camera/screens/assessment_result_screen.dart',
      ]) {
        expect(source(path), contains('announceReminderSet('), reason: path);
      }
    });

    test('Settings has no test-notification link any more', () {
      final settings = source(
        'lib/features/settings/screens/settings_screen.dart',
      );
      expect(settings, isNot(contains('Send test notification')));
      expect(
        source('lib/services/firebase/notification_service.dart'),
        isNot(contains('debugSendTestNotifications')),
      );
    });
  });
}
