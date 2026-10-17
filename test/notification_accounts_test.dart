import 'package:fine_aid/core/widgets/remind_me_checkbox.dart';
import 'package:fine_aid/features/dashboard/screens/notifications_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/notification_strings.dart';
import 'package:fine_aid/services/firebase/notification_service.dart';
import 'package:fine_aid/services/notification_inbox_store.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

AppNotification _note(String id, {String? entryId, DateTime? scheduledFor}) =>
    AppNotification(
      id: id,
      type: AppNotificationType.healingMilestone,
      title: 't',
      body: 'b',
      createdAt: DateTime.now(),
      entryId: entryId,
      scheduledFor: scheduledFor,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('notification payload (carries the account and the entry)', () {
    test('round trip', () {
      final payload = buildHealingPayload('uidA', 'entry1');
      expect(payload, 'healing_checkin:uidA:entry1');
      final parsed = parseHealingPayload(payload)!;
      expect(parsed.uid, 'uidA');
      expect(parsed.entryId, 'entry1');
    });

    test('older payloads (entry only) and junk are ignored', () {
      expect(parseHealingPayload('healing_checkin:entry1'), isNull);
      expect(parseHealingPayload('healing_checkin:'), isNull);
      expect(parseHealingPayload('healing_checkin::entry1'), isNull);
      expect(parseHealingPayload('healing_checkin:uid:'), isNull);
      expect(parseHealingPayload('something_else:a:b'), isNull);
      expect(parseHealingPayload(null), isNull);
    });
  });

  group('check-in wording is neutral', () {
    final all = [NotificationStrings.en, NotificationStrings.tl];

    test('no alarming or diagnostic words in titles, bodies or buttons', () {
      const banned = [
        'worse',
        'worsen',
        'infect',
        'urgent',
        'danger',
        'serious',
        'emergency',
        'lumalala',
        'impeksyon',
        'delikado',
      ];
      for (final s in all) {
        // The words of the notification itself (the buttons are the user's own
        // answers, so "It's Worse" is theirs to say, not ours).
        for (final text in [
          s.checkInTitle,
          s.checkInBody,
          s.actionBetter,
          s.actionNotYet,
        ]) {
          for (final word in banned) {
            expect(text.toLowerCase(), isNot(contains(word)), reason: text);
          }
        }
      }
    });

    test('English and Tagalog both exist and differ', () {
      expect(
        NotificationStrings.tl.checkInBody,
        isNot(NotificationStrings.en.checkInBody),
      );
      expect(
        NotificationStrings.tl.actionBetter,
        isNot(NotificationStrings.en.actionBetter),
      );
      expect(
        NotificationStrings.tl.actionNotYet,
        isNot(NotificationStrings.en.actionNotYet),
      );
      expect(
        NotificationStrings.tl.actionWorse,
        isNot(NotificationStrings.en.actionWorse),
      );
      expect(
        NotificationStrings.tl.seeProfessional,
        isNot(NotificationStrings.en.seeProfessional),
      );
    });

    test('"No" leads to a recommendation, not a diagnosis', () {
      final text = NotificationStrings.en.seeProfessional.toLowerCase();
      expect(text, contains('recommend'));
      expect(text, contains('professional'));
    });

    test('a notification uses the language saved in Settings', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'tl'});
      expect(
        (await NotificationStrings.load()).checkInBody,
        NotificationStrings.tl.checkInBody,
      );
      SharedPreferences.setMockInitialValues({'app_language': 'en'});
      expect(
        (await NotificationStrings.load()).checkInBody,
        NotificationStrings.en.checkInBody,
      );
      SharedPreferences.setMockInitialValues({});
      expect(
        (await NotificationStrings.load()).checkInBody,
        NotificationStrings.en.checkInBody,
      );
    });
  });

  group('the inbox belongs to one account at a time', () {
    final store = NotificationInboxStore.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await store.bindToUser(null);
    });

    test(
      'user B never sees user A\'s notifications on the same device',
      () async {
        await store.bindToUser('userA');
        await store.add(_note('a1'));
        expect(store.visibleItems.map((n) => n.id), ['a1']);

        await store.bindToUser('userB');
        expect(store.visibleItems, isEmpty);
        await store.add(_note('b1'));
        expect(store.visibleItems.map((n) => n.id), ['b1']);

        // A's notifications are still A's: back for A, gone for B.
        await store.bindToUser('userA');
        expect(store.visibleItems.map((n) => n.id), ['a1']);
        await store.bindToUser('userB');
        expect(store.visibleItems.map((n) => n.id), ['b1']);
      },
    );

    test('signing out empties the inbox', () async {
      await store.bindToUser('userA');
      await store.add(_note('a1'));
      await store.bindToUser(null);
      expect(store.visibleItems, isEmpty);
      expect(store.unreadCount, 0);
    });

    test('a guest gets no notifications at all', () async {
      await store.bindToUser(null);
      await store.add(_note('g1'));
      await store.upsertFromRemote(_note('g2'));
      expect(store.visibleItems, isEmpty);
      // ...and nothing was kept for the next person either.
      await store.bindToUser('userA');
      expect(store.visibleItems, isEmpty);
    });

    test('the old shared inbox is not shown to anyone', () async {
      SharedPreferences.setMockInitialValues({
        'notification_inbox_v1': [
          '{"id":"old","type":"reminder","title":"old","body":"b",'
              '"createdAt":"2026-01-01T09:00:00.000"}',
        ],
      });
      await store.bindToUser('userA');
      expect(store.visibleItems, isEmpty);
    });

    test('an entry answered from the notification clears its pending '
        'reminders', () async {
      await store.bindToUser('userA');
      final future = DateTime.now().add(const Duration(days: 2));
      await store.add(_note('pending', entryId: 'e1', scheduledFor: future));
      await store.add(_note('other', entryId: 'e2', scheduledFor: future));
      expect(store.items.map((n) => n.id), containsAll(['pending', 'other']));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kAnsweredEntriesPrefsKey, ['e1']);
      await store.applyAnswered();

      expect(store.items.map((n) => n.id), ['other']);
      expect(prefs.getStringList(kAnsweredEntriesPrefsKey), isNull);
    });
  });

  group('screens for a guest', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      AppLanguage language = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
    }

    testWidgets('Notifications asks a guest to log in or create an account', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const NotificationsScreen());
      expect(find.text(NotificationStrings.en.guestTitle), findsOneWidget);
      expect(find.text(NotificationStrings.en.guestBody), findsOneWidget);
      expect(find.text(NotificationStrings.en.guestSignIn), findsOneWidget);
      expect(find.text('No notifications yet'), findsNothing);
    });

    testWidgets('...in Tagalog too', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const NotificationsScreen(), language: AppLanguage.tl);
      expect(find.text(NotificationStrings.tl.guestTitle), findsOneWidget);
      expect(find.text(NotificationStrings.en.guestTitle), findsNothing);
    });

    testWidgets('the Remind me checkbox is hidden for a guest', (tester) async {
      await pump(
        tester,
        Scaffold(body: RemindMeCheckbox(value: false, onChanged: (_) {})),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text(NotificationStrings.en.remindMeTitle), findsNothing);
    });

    testWidgets('New Entry has no Remind Me option for a guest', (
      tester,
    ) async {
      _ignoreListTileInkWarning();
      await pump(tester, const NewEntryScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      // the rest of the entry form is there, just not the reminder option
      expect(find.text('Add Image'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Remind Me'), findsNothing);
    });
  });

  test('the Remind me wording exists in both languages', () {
    expect(
      NotificationStrings.tl.remindMeTitle,
      isNot(NotificationStrings.en.remindMeTitle),
    );
    expect(
      NotificationStrings.tl.noBenchmark,
      isNot(NotificationStrings.en.noBenchmark),
    );
  });
}
