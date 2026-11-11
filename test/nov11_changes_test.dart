import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/data/first_aid_step_images.dart';
import 'package:fine_aid/features/journal/screens/entry_detail_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/offline_strings.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  void phone(WidgetTester tester, {double h = 2400}) {
    tester.view.physicalSize = Size(800, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(AppLanguage l, Widget home) => AppLanguageScope(
    language: l,
    child: MaterialApp(home: home),
  );

  void offline(bool value) {
    ConnectivityService().lastKnownOnline = !value;
    addTearDown(() => ConnectivityService().lastKnownOnline = null);
  }

  group('A1. Login background', () {
    test('the maroon waves from the design are used and declared', () {
      expect(
        File('assets/images/login_background_maroon.png').existsSync(),
        isTrue,
      );
      expect(source('pubspec.yaml'), contains('login_background_maroon.png'));
      expect(
        source('lib/features/auth/screens/login_screen.dart'),
        contains('login_background_maroon.png'),
      );
    });
  });

  group('A2. Offline add-entry form', () {
    for (final l in AppLanguage.values) {
      testWidgets('${l.name}: pink notice, text-only form', (tester) async {
        offline(true);
        phone(tester);
        final s = l == AppLanguage.tl ? OfflineStrings.tl : OfflineStrings.en;
        await tester.pumpWidget(app(l, const NewEntryScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.proceed));
        await tester.pumpAndSettle();
        expect(find.text(s.journalNotice), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
      });
    }

    testWidgets('the notes box is tall (fills the screen)', (tester) async {
      offline(true);
      phone(tester, h: 2000);
      await tester.pumpWidget(app(AppLanguage.en, const NewEntryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OfflineStrings.en.proceed));
      await tester.pumpAndSettle();
      final notes = tester.getSize(find.byType(TextField).last);
      expect(notes.height, greaterThan(600));
    });

    testWidgets('online form has no offline notice', (tester) async {
      offline(false);
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.en, const NewEntryScreen()));
      await tester.pumpAndSettle();
      expect(find.text(OfflineStrings.en.journalNotice), findsNothing);
    });

    test('the notice wording', () {
      expect(
        OfflineStrings.en.journalNotice,
        "This health journal is for users who don't have an internet "
        'connection. Your journal entries will be saved only in the app.',
      );
      expect(
        OfflineStrings.tl.journalNotice,
        isNot(OfflineStrings.en.journalNotice),
      );
    });
  });

  group('A3. Offline entry view', () {
    Map<String, dynamic> entry() => {
      'title': 'Nadapa ako kanina',
      'description': 'Tinulak ako ni badeth huhu',
      'classification': null,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 10, 9)),
    };

    testWidgets('offline: notes, yellow notice and the Offline Mode mark', (
      tester,
    ) async {
      offline(true);
      phone(tester);
      await tester.pumpWidget(
        app(AppLanguage.en, EntryDetailScreen(entryId: 'e1', data: entry())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nadapa ako kanina'), findsOneWidget);
      expect(find.text('Tuesday, November 10'), findsOneWidget);
      expect(find.text('Tinulak ako ni badeth huhu'), findsOneWidget);
      expect(find.text(OfflineStrings.en.healingNotice), findsOneWidget);
      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      // no evaluation / photo box for a text-only entry
      expect(find.text('No image'), findsNothing);
    });

    testWidgets('Filipino notice', (tester) async {
      offline(true);
      phone(tester);
      await tester.pumpWidget(
        app(AppLanguage.tl, EntryDetailScreen(entryId: 'e1', data: entry())),
      );
      await tester.pumpAndSettle();
      expect(find.text(OfflineStrings.tl.healingNotice), findsOneWidget);
    });

    testWidgets('online: still a text-only view, without the Offline Mode '
        'mark', (tester) async {
      offline(false);
      phone(tester);
      await tester.pumpWidget(
        app(AppLanguage.en, EntryDetailScreen(entryId: 'e1', data: entry())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline Mode'), findsNothing);
      expect(find.text('Tinulak ako ni badeth huhu'), findsOneWidget);
    });
  });

  group('A4. First Aid step images', () {
    test('every kind has its picture file', () {
      for (final key in firstAidStepImageKeys) {
        expect(
          File(firstAidStepImagePath(key)).existsSync(),
          isTrue,
          reason: key,
        );
      }
    });

    test('the new pictures are small (they are shown at about 76 px)', () {
      for (final key in firstAidStepImageKeys.where((k) => k.endsWith('_1'))) {
        final size = File(firstAidStepImagePath(key)).lengthSync();
        // the five older ones are bigger; the new ones must stay light
        if (size > 400 * 1024) {
          fail('$key is ${size ~/ 1024} KB');
        }
      }
    });

    test('the rash steps from the guide get the new pictures', () {
      expect(
        firstAidStepImageKey(
          'During: After washing, let the skin air-dry. Do not rub it with '
          'a towel, and keep the area uncovered. — Rubbing can make the rash '
          'worse.',
        ),
        'air_dry_do_not_rub_1',
      );
      expect(
        firstAidStepImageKey(
          'After: Keep track of when the rash started and anything new you '
          'were exposed to.',
        ),
        'keep_track_of_changes_1',
      );
      expect(
        firstAidStepImageKey(
          'After: Consult a doctor for formal evaluation if the rash does '
          'not get better in a few days or keeps coming back.',
        ),
        'consult_a_doctor_if_not_better_1',
      );
      expect(
        firstAidStepImageKey(
          'Before: Get clean running water, clean gauze (or a clean cloth '
          'if you do not have gauze), and a clean non-stick dressing ready.',
        ),
        'gather_gauze_or_cloth_1',
      );
    });

    test('steps that already had a picture keep it', () {
      expect(
        firstAidStepImageKey('Wash your hands with soap and water.'),
        'wash_hands',
      );
      expect(
        firstAidStepImageKey('Avoid scratching the affected area.'),
        'avoid_touching',
      );
      expect(
        firstAidStepImageKey('Consult a doctor for formal evaluation.'),
        'consult_a_doctor_for_formal_evaluation_1',
      );
      expect(
        firstAidStepImageKey('Apply pressure with clean gauze.'),
        'apply_pressure',
      );
      expect(
        firstAidStepImageKey('Monitor the area for changes.'),
        'monitor_the_area',
      );
    });

    test('steps no older kind matches can use the added ones', () {
      expect(
        firstAidStepImageKey('Keep the area dry until it heals.'),
        'keep_area_dry_1',
      );
      expect(
        firstAidStepImageKey('Hold a cool, damp cloth on the skin.'),
        'cool_damp_cloth_1',
      );
      expect(
        firstAidStepImageKey('Seek care if large blisters appear.'),
        'blisters_seek_care_1',
      );
      expect(
        firstAidStepImageKey(
          'A fever or swelling that keeps spreading is a warning sign.',
        ),
        'warning_signs_to_watch_1',
      );
    });
  });
}
