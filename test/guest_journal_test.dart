import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/features/journal/screens/day_entries_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/guest_journal_strings.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:fine_aid/i18n/offline_strings.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:fine_aid/services/guest_journal_store.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guest Mode journal entries: kept on the phone, shown in the journal and the
/// calendar, and moved into the account at sign-up / sign-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final store = GuestJournalStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
  });

  void phone(WidgetTester tester, {double h = 3200}) {
    tester.view.physicalSize = Size(800, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home, {AppLanguage l = AppLanguage.en}) => AppLanguageScope(
    language: l,
    child: MaterialApp(home: home),
  );

  group('the store', () {
    test('add, read back (newest first), edit and delete', () async {
      final a = await store.add(
        title: 'First',
        description: 'one',
        classification: 'Burns',
        painScore: 2,
        painScaleMax: 5,
        createdAt: DateTime(2026, 11, 1, 9),
      );
      await store.add(
        title: 'Second',
        description: 'two',
        createdAt: DateTime(2026, 11, 5, 9),
      );
      expect(store.entries.value.map((e) => e.data['title']), [
        'Second',
        'First',
      ]);
      final first = store.entries.value.last;
      expect(first.id, a);
      expect(first.data['createdAt'], isA<Timestamp>());
      expect(first.data['classification'], 'Burns');
      expect(first.data['isLocal'], isTrue);
      expect(first.data['imageUrls'], isEmpty);

      await store.update(a, title: 'First (edited)', description: 'changed');
      expect(store.entries.value.last.data['title'], 'First (edited)');
      expect(store.entries.value.last.data['description'], 'changed');

      await store.remove(a);
      expect(store.entries.value.map((e) => e.data['title']), ['Second']);
    });

    test('it survives a restart (read again from storage)', () async {
      await store.add(
        title: 'Kept',
        description: '',
        createdAt: DateTime(2026, 11, 2),
      );
      // Forget what is in memory, then load from storage.
      store.entries.value = const [];
      await store.load();
      expect(store.entries.value.single.data['title'], 'Kept');
    });
  });

  group('moving entries into the account at sign-up / sign-in', () {
    test('every entry is written under its own id, then cleared', () async {
      final a = await store.add(
        title: 'A',
        description: 'x',
        classification: 'Scratch',
        painScore: 1,
        painScaleMax: 5,
        createdAt: DateTime(2026, 11, 1),
      );
      final b = await store.add(
        title: 'B',
        description: '',
        createdAt: DateTime(2026, 11, 2),
      );
      final written = <String, Map<String, dynamic>>{};
      final moved = await store.migrateTo(
        'uid1',
        writeDoc: (id, doc) async => written[id] = doc,
      );
      expect(moved, 2);
      expect(written.keys, containsAll([a, b]));
      expect(written[a]!['title'], 'A');
      expect(written[a]!['classification'], 'Scratch');
      expect(written[a]!['painScore'], 1);
      expect(written[a]!['createdAt'], isA<Timestamp>());
      expect(written[a]!['imageUrls'], isEmpty);
      expect(written[a]!['remindMe'], isFalse);
      expect(store.entries.value, isEmpty);
    });

    test('a failed write is kept and retried, never duplicated', () async {
      final a = await store.add(
        title: 'A',
        description: '',
        createdAt: DateTime(2026, 11, 1),
      );
      final b = await store.add(
        title: 'B',
        description: '',
        createdAt: DateTime(2026, 11, 2),
      );
      final written = <String>[];
      var first = true;
      final moved = await store.migrateTo(
        'uid1',
        writeDoc: (id, doc) async {
          if (id == a && first) {
            first = false;
            throw Exception('offline');
          }
          written.add(id);
        },
      );
      expect(moved, 1);
      expect(written, [b]);
      expect(store.entries.value.single.id, a);

      // Next time (same ids, so a retry can't double up).
      final again = await store.migrateTo(
        'uid1',
        writeDoc: (id, doc) async => written.add(id),
      );
      expect(again, 1);
      expect(written, [b, a]);
      expect(store.entries.value, isEmpty);
    });

    test('nothing stored, nothing moved', () async {
      expect(await store.migrateTo('uid1', writeDoc: (_, _) async {}), 0);
    });
  });

  group('saving as a guest', () {
    testWidgets('offline: text-only form saves on the phone', (tester) async {
      ConnectivityService().lastKnownOnline = false;
      addTearDown(() => ConnectivityService().lastKnownOnline = null);
      phone(tester);
      await tester.pumpWidget(app(const NewEntryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OfflineStrings.en.proceed));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Sore knee');
      await tester.enterText(fields.at(1), 'It hurts when I walk');
      await tester.tap(find.text(JournalEntryStrings.en.save));
      await tester.pumpAndSettle();

      final saved = store.entries.value.single.data;
      expect(saved['title'], 'Sore knee');
      expect(saved['description'], 'It hurts when I walk');
      expect(saved['classification'], isNull);
      // No "create an account" wall, and the screen closed.
      expect(find.byType(NewEntryScreen), findsNothing);
    });

    testWidgets('online: the full form saves with category and pain', (
      tester,
    ) async {
      phone(tester, h: 5200);
      await tester.pumpWidget(app(const NewEntryScreen()));
      await tester.pumpAndSettle();
      // The Guest Mode pop-up now says entries are kept on this device.
      expect(find.text(GuestJournalStrings.en.warning), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Kitchen burn');
      await tester.tap(find.text('Burns').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.ensureVisible(find.text(JournalEntryStrings.en.save));
      await tester.tap(find.text(JournalEntryStrings.en.save));
      await tester.pumpAndSettle();

      final saved = store.entries.value.single.data;
      expect(saved['title'], 'Kitchen burn');
      expect(saved['classification'], 'Burns');
      expect(saved['painScore'], 3);
    });

    testWidgets('a guest still has to give a title', (tester) async {
      phone(tester, h: 5200);
      await tester.pumpWidget(app(const NewEntryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(JournalEntryStrings.en.save));
      await tester.tap(find.text(JournalEntryStrings.en.save));
      await tester.pump();
      expect(find.text(JournalEntryStrings.en.titleRequired), findsOneWidget);
      expect(store.entries.value, isEmpty);
    });
  });

  group('a guest sees and manages the entries', () {
    Future<void> seed() async {
      await store.add(
        title: 'Old scrape',
        description: 'knee',
        createdAt: DateTime(2026, 11, 1, 9),
      );
      await store.add(
        title: 'Newer cut',
        description: 'finger',
        createdAt: DateTime(2026, 11, 6, 9),
      );
    }

    testWidgets('the journal list shows them, tagged "On this device"', (
      tester,
    ) async {
      await seed();
      phone(tester);
      await tester.pumpWidget(app(const JournalListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Old scrape'), findsOneWidget);
      expect(find.text('Newer cut'), findsOneWidget);
      expect(find.text(GuestJournalStrings.en.onThisDevice), findsNWidgets(2));
      // newest first
      expect(
        tester.getTopLeft(find.text('Newer cut')).dy,
        lessThan(tester.getTopLeft(find.text('Old scrape')).dy),
      );
    });

    testWidgets('the journal list says so when there are none', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const JournalListScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No journal entries yet'), findsOneWidget);
    });

    testWidgets('the calendar lists the day\'s entries', (tester) async {
      await seed();
      phone(tester);
      await tester.pumpWidget(
        app(DayEntriesScreen(initialDate: DateTime(2026, 11, 6))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Newer cut'), findsOneWidget);
      expect(find.text('Old scrape'), findsNothing);
    });

    testWidgets('deleting from the three-dot menu removes it', (tester) async {
      await seed();
      phone(tester);
      await tester.pumpWidget(app(const JournalListScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.entries.value.map((e) => e.data['title']), ['Old scrape']);
      expect(find.text('Newer cut'), findsNothing);
    });

    testWidgets('editing from the three-dot menu changes it, with no photos', (
      tester,
    ) async {
      await seed();
      phone(tester);
      await tester.pumpWidget(app(const JournalListScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        'Newer cut (healing)',
      );
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
      expect(store.entries.value.first.data['title'], 'Newer cut (healing)');
    });
  });

  group('wording', () {
    test('Filipino text exists', () {
      expect(
        GuestJournalStrings.tl.warning,
        isNot(GuestJournalStrings.en.warning),
      );
      expect(
        GuestJournalStrings.tl.savedOnDevice,
        isNot(GuestJournalStrings.en.savedOnDevice),
      );
      expect(
        GuestJournalStrings.tl.onThisDevice,
        isNot(GuestJournalStrings.en.onThisDevice),
      );
      expect(GuestJournalStrings.en.moved(1), contains('1 journal entry'));
      expect(GuestJournalStrings.en.moved(3), contains('3 journal entries'));
    });
  });
}
