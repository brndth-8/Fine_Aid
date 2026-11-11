import 'dart:io';

import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/features/settings/screens/feedback_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:fine_aid/i18n/offline_strings.dart';
import 'package:fine_aid/i18n/severe_strings.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

/// Pretends the phone has (or has no) internet for connectivity_plus.
void mockConnectivity({required bool online}) {
  ConnectivityService().lastKnownOnline = online;
  addTearDown(() => ConnectivityService().lastKnownOnline = null);
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => [online ? 'wifi' : 'none'],
      );
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (call) async => null,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  void phone(WidgetTester tester, {double w = 800, double h = 3200}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(AppLanguage language, Widget home) => AppLanguageScope(
    language: language,
    child: MaterialApp(home: home),
  );

  group('2. Textbook find bar', () {
    final viewer = source(
      'lib/features/dashboard/screens/textbook_viewer_screen.dart',
    );
    test('previous / next chevrons, then X that clears and closes', () {
      final up = viewer.indexOf('Icons.keyboard_arrow_down');
      final down = viewer.indexOf('Icons.keyboard_arrow_up');
      final close = viewer.indexOf("tooltip: 'Clear and close search'");
      expect(up, greaterThan(0));
      expect(down, greaterThan(up));
      expect(close, greaterThan(down));
      expect(viewer, contains('_closeSearch'));
    });
  });

  group('3. Feedback limit', () {
    test('no minimum, 100 maximum', () {
      final feedback = source(
        'lib/features/settings/screens/feedback_screen.dart',
      );
      expect(feedback, isNot(contains('userFeedbackMinLength')));
      expect(feedback, isNot(contains('At least')));
      expect(userFeedbackMaxLength, 100);
    });
  });

  group('4. Settings footer above Log out', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: note and website are shown', (
        tester,
      ) async {
        phone(tester);
        final s = language == AppLanguage.tl
            ? SettingsStrings.tl
            : SettingsStrings.en;
        await tester.pumpWidget(app(language, const SettingsScreen()));
        await tester.pump();
        expect(find.text(s.footerNote), findsOneWidget);
        expect(find.text('www.FineAid.site'), findsOneWidget);
        final note = tester.getTopLeft(find.text(s.footerNote)).dy;
        // (no one is signed in here, so the button reads Sign in)
        final logOut = tester.getTopLeft(find.text(s.signIn)).dy;
        expect(note, lessThan(logOut));
      });
    }

    test('the exact English wording; Filipino differs', () {
      expect(
        SettingsStrings.en.footerNote,
        'For further concern, reach out to us for further information; '
        'reach out on the official FineAid website.',
      );
      expect(
        SettingsStrings.tl.footerNote,
        isNot(SettingsStrings.en.footerNote),
      );
    });
  });

  group('5. Injury > Deep description', () {
    test('English and Filipino wording', () {
      expect(
        JournalEntryStrings.en.deepDescription,
        'The wound is deep, and fat or muscle may be partly visible. The '
        'edges of the wound are gaping apart. Bleeding continues even after '
        '10 minutes of firm pressure, or the wound was caused by a dirty or '
        'sharp object that pierced the skin.',
      );
      expect(
        JournalEntryStrings.tl.deepDescription,
        'Malalim ang sugat at maaaring bahagyang makita ang taba o kalamnan. '
        'Nakabuka ang mga gilid ng sugat. Patuloy ang pagdurugo kahit '
        'nadiinan na ito nang 10 minuto, o dulot ito ng marumi o matulis na '
        'bagay na bumaon sa balat.',
      );
      expect(JournalEntryStrings.en.deep, 'Deep');
      expect(JournalEntryStrings.tl.deep, 'Malalim');
    });
  });

  group('6. Professional care recommended pop-up', () {
    Future<void> open(WidgetTester tester, AppLanguage l) async {
      mockConnectivity(online: true);
      phone(tester, h: 5200);
      await tester.pumpWidget(app(l, const NewEntryScreen()));
      await tester.pumpAndSettle();
      // Guest Mode pop-up (no signed-in user in tests)
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickInjury(WidgetTester tester, String subType) async {
      final s = JournalEntryStrings.en;
      await tester.tap(find.text('Injury').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(subType == 'Deep' ? s.deep : s.minor),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Injury > Deep shows it; Continue keeps the selection', (
      tester,
    ) async {
      await open(tester, AppLanguage.en);
      await pickInjury(tester, 'Deep');
      final s = JournalEntryStrings.en;
      expect(find.text(s.careTitle), findsOneWidget);
      expect(find.text(s.careBody), findsOneWidget);
      expect(find.text(s.careNote), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
      await tester.tap(find.text(s.careContinue));
      await tester.pumpAndSettle();
      expect(find.text(s.careTitle), findsNothing);
      expect(find.textContaining('Selected: Injury'), findsOneWidget);
    });

    testWidgets('Injury > Minor does not show it', (tester) async {
      await open(tester, AppLanguage.en);
      await pickInjury(tester, 'Minor');
      expect(find.text(JournalEntryStrings.en.careTitle), findsNothing);
    });

    test('Filipino text exists', () {
      expect(
        JournalEntryStrings.tl.careTitle,
        isNot(JournalEntryStrings.en.careTitle),
      );
      expect(
        JournalEntryStrings.tl.careContinue,
        isNot(JournalEntryStrings.en.careContinue),
      );
    });
  });

  group('7. Month names stay in English', () {
    test('the calendar pieces use the English list', () {
      for (final path in [
        'lib/core/widgets/app_date_picker.dart',
        'lib/features/journal/screens/day_entries_screen.dart',
        'lib/features/dashboard/screens/dashboard_screen.dart',
      ]) {
        expect(source(path), contains('CalendarStrings.en'), reason: path);
      }
      expect(
        source('lib/features/journal/screens/day_entries_screen.dart'),
        isNot(
          contains(
            'CalendarStrings.of(\n                                context,\n                              ).monthDay',
          ),
        ),
      );
      expect(CalendarStrings.en.monthDay(DateTime(2026, 10, 5)), 'October 5');
    });
  });

  group('8. Voice input is gone', () {
    test('no voice files, packages, permissions or mic buttons', () {
      for (final path in [
        'lib/services/voice_input_service.dart',
        'lib/core/voice_unavailable.dart',
        'lib/core/widgets/voice_message_bubble.dart',
        'lib/i18n/voice_strings.dart',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }
      final pubspec = source('pubspec.yaml');
      for (final pkg in ['speech_to_text', 'record:', 'audioplayers']) {
        expect(pubspec, isNot(contains(pkg)), reason: pkg);
      }
      final manifest = source('android/app/src/main/AndroidManifest.xml');
      expect(manifest, isNot(contains('RECORD_AUDIO')));
      expect(manifest, isNot(contains('RecognitionService')));
      final plist = source('ios/Runner/Info.plist');
      expect(plist, isNot(contains('NSMicrophoneUsageDescription')));
      expect(plist, isNot(contains('NSSpeechRecognitionUsageDescription')));
      for (final path in [
        'lib/features/chatbot/screens/chatbot_screen.dart',
        'lib/features/camera/screens/assessment_result_screen.dart',
      ]) {
        final text = source(path);
        expect(text, isNot(contains('Icons.mic')), reason: path);
        expect(text, isNot(contains('Voice')), reason: path);
      }
    });
  });

  group('9. Emergency pop-up', () {
    test('its text exists in both languages', () {
      expect(
        SevereStrings.en.emergencyTitle,
        'Seek Emergency Care Immediately',
      );
      expect(SevereStrings.en.callEmergency, 'Call Emergency Services (911)');
      expect(SevereStrings.en.medicalNeeded, 'Medical Health is needed');
      expect(SevereStrings.en.nearbyHospitalsButton, 'Nearby Hospitals');
      expect(
        SevereStrings.tl.emergencyTitle,
        isNot(SevereStrings.en.emergencyTitle),
      );
    });

    test('siren asset is declared and used; X, call and nearby actions', () {
      expect(File('assets/images/emergency_siren.png').existsSync(), isTrue);
      expect(
        source('pubspec.yaml'),
        contains('assets/images/emergency_siren.png'),
      );
      final result = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(result, contains('emergency_siren.png'));
      expect(result, contains('onPressed: _callEmergencyServices'));
      expect(result, contains('Navigator.pop(dialogContext, true)'));
      expect(result, contains('Navigator.pop(dialogContext, false)'));
    });
  });

  group('10/11. Offline Mode', () {
    testWidgets('Journal offline: pop-up first (no Guest pop-up), then the '
        'text-only form', (tester) async {
      mockConnectivity(online: false);
      phone(tester);
      final s = OfflineStrings.en;
      await tester.pumpWidget(app(AppLanguage.en, const NewEntryScreen()));
      await tester.pumpAndSettle();

      expect(find.text(s.popupTitle), findsOneWidget);
      expect(find.text(s.popupBody), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      // No Guest Mode pop-up stacked on it.
      expect(find.textContaining('Guest Mode'), findsNothing);

      await tester.tap(find.text(s.proceed));
      await tester.pumpAndSettle();
      expect(find.text(s.popupTitle), findsNothing);
      expect(find.textContaining('Guest Mode'), findsNothing);

      // Only title, date, text, Save and Cancel.
      final j = JournalEntryStrings.en;
      expect(find.text(j.titleLabel), findsOneWidget);
      expect(find.text(j.dateLabel), findsOneWidget);
      expect(find.text(j.feelingLabel), findsOneWidget);
      expect(find.text(j.save), findsOneWidget);
      expect(find.text(j.cancel), findsOneWidget);
      expect(find.text('Add Image'), findsNothing);
      expect(find.text(j.categoryHeading), findsNothing);
      expect(find.text('Remind me'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('Journal online: no offline pop-up, the full form', (
      tester,
    ) async {
      mockConnectivity(online: true);
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.en, const NewEntryScreen()));
      await tester.pumpAndSettle();
      expect(find.text(OfflineStrings.en.popupTitle), findsNothing);
      expect(find.textContaining('Guest Mode'), findsOneWidget);
    });

    testWidgets('Feedback offline: box greyed out, Send off, message shown', (
      tester,
    ) async {
      mockConnectivity(online: false);
      phone(tester, h: 1600);
      await tester.pumpWidget(app(AppLanguage.en, const FeedbackScreen()));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      final send = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(send.onPressed, isNull);
      expect(find.text(OfflineStrings.en.unavailable), findsOneWidget);
    });

    testWidgets('Feedback online: box and Send work as before', (tester) async {
      mockConnectivity(online: true);
      phone(tester, h: 1600);
      await tester.pumpWidget(app(AppLanguage.en, const FeedbackScreen()));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      final send = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(send.onPressed, isNotNull);
    });

    test('offline text exists in both languages', () {
      expect(
        OfflineStrings.tl.unavailable,
        isNot(OfflineStrings.en.unavailable),
      );
      expect(OfflineStrings.tl.popupTitle, isNot(OfflineStrings.en.popupTitle));
      expect(OfflineStrings.tl.popupBody, isNot(OfflineStrings.en.popupBody));
      expect(OfflineStrings.tl.proceed, isNot(OfflineStrings.en.proceed));
    });
  });
}
