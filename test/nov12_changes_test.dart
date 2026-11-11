import 'dart:io';

import 'package:fine_aid/core/age_utils.dart';
import 'package:fine_aid/core/constants/analysis_lock.dart';
import 'package:fine_aid/core/text_scale_controller.dart';
import 'package:fine_aid/data/health_context.dart';
import 'package:fine_aid/features/auth/screens/registration_screen.dart';
import 'package:fine_aid/features/settings/screens/personalization_screen.dart';
import 'package:fine_aid/i18n/registration_strings.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/health_kit_content_tl.dart';
import 'package:fine_aid/i18n/health_kit_locale.dart';
import 'package:fine_aid/i18n/health_kit_ui_strings.dart';
import 'package:fine_aid/i18n/offline_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'date_boxes_helpers.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  void phone(WidgetTester tester, {double w = 900, double h = 3000}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(AppLanguage l, Widget home) => AppLanguageScope(
    language: l,
    child: MaterialApp(home: home),
  );

  // The kit shows a spinner while a question flow runs, which never "settles":
  // step a few frames instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void offline() {
    ConnectivityService().lastKnownOnline = false;
    addTearDown(() => ConnectivityService().lastKnownOnline = null);
  }

  group('1. The emergency dialog X goes back to the camera', () {
    final result = source(
      'lib/features/camera/screens/assessment_result_screen.dart',
    );
    test(
      'X closes the dialog, then a fresh camera screen replaces the result',
      () {
        expect(result, contains('Navigator.pop(dialogContext, false)'));
        expect(result, contains('} else if (openNearby == false) {'));
        expect(result, contains('const AiCameraScreen()'));
        // Nearby Hospitals still opens the sheet
        expect(result, contains('showNearbyHealthcareSheet(context)'));
      },
    );
  });

  group('2. One analysis at a time', () {
    test('the lock hands out one holder and can be released', () {
      expect(AnalysisLock.isBusy, isFalse);
      expect(AnalysisLock.tryAcquire(), isTrue);
      expect(AnalysisLock.isBusy, isTrue);
      expect(AnalysisLock.tryAcquire(), isFalse); // a second request is refused
      AnalysisLock.release();
      expect(AnalysisLock.isBusy, isFalse);
      expect(AnalysisLock.tryAcquire(), isTrue); // free again
      AnalysisLock.release();
      AnalysisLock.release(); // releasing twice is harmless
      expect(AnalysisLock.isBusy, isFalse);
    });

    test(
      'both calls that send a photo take it and release it in a finally',
      () {
        final gemini = source('lib/services/api/gemini_service.dart');
        expect(
          'AnalysisLock.tryAcquire()'.allMatches(gemini).length,
          2,
          reason: 'analyzeWoundV2 and detectWounds',
        );
        expect('AnalysisLock.release();'.allMatches(gemini).length, 2);
        expect(
          '} finally {'.allMatches(gemini).length,
          greaterThanOrEqualTo(2),
        );
      },
    );
  });

  group('3 + 4. Health Kit follows the app language (also offline)', () {
    testWidgets('Filipino + offline: banner and every category in Filipino', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      offline();
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.tl, const FirstAidKitScreen()));
      await tester.pumpAndSettle();
      // the offline notice first
      await tester.tap(find.text(OfflineStrings.tl.understood));
      await tester.pumpAndSettle();

      expect(
        find.text(HealthKitStrings.of('bannerTitle', HealthKitLocale.tl)),
        findsOneWidget,
      );
      expect(
        find.text(HealthKitStrings.of('bannerSubtitle', HealthKitLocale.tl)),
        findsOneWidget,
      );
      expect(
        find.text(HealthKitStrings.of('bannerTitle', HealthKitLocale.en)),
        findsNothing,
      );
      for (final c in healthKitContentTl.values) {
        expect(find.text(c.title), findsOneWidget, reason: c.title);
      }
    });

    testWidgets('no language toggle in the app bar', (tester) async {
      offline();
      phone(tester);
      for (final l in AppLanguage.values) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(l, const FirstAidKitScreen()));
        await tester.pumpAndSettle();
        if (l == AppLanguage.tl) {
          await tester.tap(find.text(OfflineStrings.tl.understood));
        } else {
          await tester.tap(find.text(OfflineStrings.en.understood));
        }
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.translate), findsNothing);
        expect(find.text('Filipino'), findsNothing);
        expect(find.text('English'), findsNothing);
      }
    });

    testWidgets('English app language: English banner', (tester) async {
      offline();
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.en, const FirstAidKitScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OfflineStrings.en.understood));
      await tester.pumpAndSettle();
      expect(
        find.text(HealthKitStrings.of('bannerTitle', HealthKitLocale.en)),
        findsOneWidget,
      );
    });

    // Every category: every question comes from the bundled Filipino content,
    // with the Filipino Yes/No buttons.
    for (final entry in healthKitContentTl.entries) {
      testWidgets('Filipino questions: ${entry.key}', (tester) async {
        offline();
        phone(tester);
        await tester.pumpWidget(app(AppLanguage.tl, const FirstAidKitScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(OfflineStrings.tl.understood));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text(entry.value.title));
        await tester.tap(find.text(entry.value.title));
        await settle(tester);

        final questions = entry.value.questions;
        for (var i = 0; i < questions.length; i++) {
          final title = HealthKitStrings.questionDialogTitle(
            i + 1,
            questions.length,
            HealthKitLocale.tl,
          );
          expect(find.text(title), findsOneWidget, reason: title);
          expect(find.text(questions[i].text), findsOneWidget);
          expect(find.text('Hindi'), findsOneWidget);
          expect(find.text('Oo'), findsOneWidget);
          expect(find.text('Yes'), findsNothing);
          await tester.tap(find.text('Hindi'));
          await settle(tester);
        }
        // the result, in Filipino
        expect(
          find.text(
            HealthKitStrings.of('basicFirstAidSteps', HealthKitLocale.tl),
          ),
          findsOneWidget,
        );
      });
    }

    test('the toggle and its stored choice are gone', () {
      final kit = source('lib/features/dashboard/first_aid_kit_screen.dart');
      expect(kit, isNot(contains('_buildLanguageToggle')));
      expect(kit, isNot(contains('_setLocale')));
      expect(kit, isNot(contains('loadHealthKitLocale')));
      expect(kit, contains('AppLanguageScope.isTagalog(context)'));
      expect(
        source('lib/i18n/health_kit_locale.dart'),
        isNot(contains('SharedPreferences')),
      );
      expect(
        source('lib/i18n/health_kit_ui_strings.dart'),
        isNot(contains('languageToggleLabel')),
      );
    });
  });

  group('3. Health Journal empty state is translated', () {
    for (final l in AppLanguage.values) {
      testWidgets('${l.name}: the empty state follows the language', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        phone(tester);
        await tester.pumpWidget(app(l, const JournalListScreen()));
        await tester.pumpAndSettle();
        final t = l == AppLanguage.tl ? ScreenText.tl : ScreenText.en;
        expect(find.text(t.journalEmpty), findsOneWidget);
        if (l == AppLanguage.tl) {
          expect(find.textContaining('No journal entries'), findsNothing);
        }
      });
    }

    test('the Filipino text names the real button', () {
      expect(ScreenText.tl.journalEmpty, contains(ScreenText.tl.addEntry));
      expect(ScreenText.en.journalEmpty, contains(ScreenText.en.addEntry));
    });
  });

  group('6. Done asks first', () {
    test(
      'Done opens the confirmation and saves through the same journal save',
      () {
        final r = source(
          'lib/features/camera/screens/assessment_result_screen.dart',
        );
        expect(r, contains('onPressed: _isSaving ? null : _handleDone'));
        expect(r, contains('Future<void> _handleDone() async {'));
        expect(r, contains('t.doneConfirmTitle'));
        expect(r, contains("Navigator.pop(dialogContext, 'save')"));
        expect(r, contains('await _saveToJournal();'));
      },
    );

    test('English and Filipino text', () {
      expect(
        ScreenText.en.doneConfirmTitle,
        'Are you done with this assessment?',
      );
      expect(ScreenText.en.doneSaveToJournal, 'Save to Health Journal');
      expect(
        ScreenText.tl.doneConfirmTitle,
        isNot(ScreenText.en.doneConfirmTitle),
      );
      expect(
        ScreenText.tl.doneSaveToJournal,
        isNot(ScreenText.en.doneSaveToJournal),
      );
      expect(ScreenText.tl.doneDontSave, isNot(ScreenText.en.doneDontSave));
    });
  });

  group('5. The chatbot knows what the person saved', () {
    test('profile and recent journal entries become one block', () {
      final text = chatHealthContext(
        profile: {'otherCondition': 'Iron deficiency'},
        medications: ['Ferrous sulfate'],
        recentEntries: [
          '2026-11-08 - Burns - Kitchen burn',
          '2026-11-05 - Scratch - Cat scratch',
        ],
      )!;
      expect(text, contains('Iron deficiency'));
      expect(text, contains('Ferrous sulfate'));
      expect(text, contains('Recent journal entries (newest first):'));
      expect(text, contains('- 2026-11-08 - Burns - Kitchen burn'));
    });

    test('only the latest few entries are included', () {
      final text = chatHealthContext(
        profile: null,
        medications: const [],
        recentEntries: [for (var i = 1; i <= 8; i++) 'entry $i'],
      )!;
      expect('- entry '.allMatches(text).length, kChatRecentEntries);
      expect(text, isNot(contains('entry ${kChatRecentEntries + 1}')));
    });

    test('nothing stored: no block, so the chat behaves as before', () {
      expect(chatHealthContext(profile: null, medications: const []), isNull);
      expect(
        chatHealthContext(
          profile: {'noneOfTheAbove': true},
          medications: const [],
          recentEntries: ['', '  '],
        ),
        isNull,
      );
    });

    test('a journal entry becomes a short line from its own fields only', () {
      expect(journalEntryLine({'title': 'Sore knee'}), 'Sore knee');
      expect(
        journalEntryLine({'classification': 'Burns', 'title': 'x' * 80}),
        'Burns - ${'x' * 60}...',
      );
    });

    test('the prompt carries the block and asks one polite question', () {
      // (the prompt is written as adjoining string pieces: join them)
      final gemini = source(
        'lib/services/api/gemini_service.dart',
      ).replaceAll(RegExp(r"'\s*\n\s*'"), '');
      expect(gemini, contains('String? healthContext,'));
      expect(gemini, contains('USER HEALTH PROFILE:'));
      expect(gemini, contains('I noticed an iron'));
      expect(gemini, contains('use ONLY what is written there'));
      expect(gemini, contains('never invent'));
      expect(gemini, contains('does NOT widen the SCOPE CHECK'));
      expect(gemini, contains('The medical disclaimer'));
    });

    test('both chat screens send it', () {
      final chat = source('lib/features/chatbot/screens/chatbot_screen.dart');
      expect(chat, contains('healthContext: _healthContext'));
      expect(chat, contains('loadChatHealthContext()'));
      expect(
        source('lib/features/camera/screens/assessment_result_screen.dart'),
        contains('healthContext: chatHealthContext('),
      );
    });
  });

  group('7. Large text size warning', () {
    test('the threshold is a named constant inside the slider range', () {
      expect(TextScaleController.largeThreshold, 1.2);
      expect(TextScaleController.largeThreshold, greaterThan(1.0));
      expect(
        TextScaleController.largeThreshold,
        lessThanOrEqualTo(TextScaleController.max),
      );
      expect(TextScaleController.isLarge(1.0), isFalse);
      expect(TextScaleController.isLarge(1.1), isFalse);
      expect(TextScaleController.isLarge(1.2), isTrue);
      expect(TextScaleController.isLarge(1.3), isTrue);
      expect(TextScaleController.isLarge(1.6), isTrue);
    });

    Future<void> open(WidgetTester tester, AppLanguage l, double start) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await TextScaleController.instance.setScale(start);
      addTearDown(() => TextScaleController.instance.setScale(1.0));
      await tester.pumpWidget(app(l, const PersonalizationScreen()));
      await tester.pumpAndSettle();
    }

    final warn = SettingsStrings.en.textSizeWarnBody;

    testWidgets('dragging past the threshold asks; Go back restores the size', (
      tester,
    ) async {
      await open(tester, AppLanguage.en, 1.0);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text(warn), findsOneWidget);
      // the size is already applied while the question is open (nothing blocked)
      expect(TextScaleController.instance.scale, greaterThanOrEqualTo(1.2));
      await tester.tap(find.text(SettingsStrings.en.textSizeRevert));
      await tester.pumpAndSettle();
      expect(find.text(warn), findsNothing);
      expect(TextScaleController.instance.scale, 1.0);
    });

    testWidgets('Keep this size leaves it as chosen, and asks only once', (
      tester,
    ) async {
      await open(tester, AppLanguage.en, 1.0);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SettingsStrings.en.textSizeKeep));
      await tester.pumpAndSettle();
      expect(TextScaleController.instance.scale, TextScaleController.max);
      // another large size (a tap near the right end): no second warning
      final slider = tester.getRect(find.byType(Slider));
      await tester.tapAt(slider.centerRight - const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(find.text(warn), findsNothing);
      expect(
        TextScaleController.isLarge(TextScaleController.instance.scale),
        isTrue,
      );
    });

    testWidgets('a size below the threshold never asks', (tester) async {
      await open(tester, AppLanguage.en, 1.0);
      await tester.drag(find.byType(Slider), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text(warn), findsNothing);
    });

    testWidgets('the warning is in Filipino too', (tester) async {
      await open(tester, AppLanguage.tl, 1.0);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text(SettingsStrings.tl.textSizeWarnBody), findsOneWidget);
      expect(
        SettingsStrings.tl.textSizeWarnBody,
        isNot(SettingsStrings.en.textSizeWarnBody),
      );
    });

    test('the exact English wording', () {
      expect(
        SettingsStrings.en.textSizeWarnBody,
        'The text size is set too large for optimal viewing. Some UI '
        'elements may be clipped or overflow.',
      );
    });
  });

  group('8. Under 16', () {
    test('age is worked out from the birthdate, month and day included', () {
      final today = DateTime(2026, 11, 11);
      expect(kIndependentAge, 16);
      // turns 16 today: not under 16 any more
      expect(calculateAge(DateTime(2010, 11, 11), today: today), 16);
      // turns 16 tomorrow: still 15
      expect(calculateAge(DateTime(2010, 11, 12), today: today), 15);
      // birthday later this year / earlier this year
      expect(calculateAge(DateTime(2010, 12, 31), today: today), 15);
      expect(calculateAge(DateTime(2010, 1, 1), today: today), 16);
    });

    Future<void> openRegistration(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(AppLanguage.en, const RegistrationScreen()));
      await tester.pump();
    }

    Future<void> enterBirthdate(WidgetTester tester, String digits) async {
      final dob = find.byType(TextFormField).at(2);
      await tester.ensureVisible(dob);
      await tester.tap(dob);
      await tester.pumpAndSettle();
      await enterDate(tester, 'start', digits);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    String digitsFor(int yearsOld, {int dayOffset = 0}) {
      final n = DateTime.now();
      final d = DateTime(n.year - yearsOld, n.month, n.day + dayOffset);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.month)}${two(d.day)}${d.year}';
    }

    testWidgets(
      'a birthdate under 16 shows the notice; acknowledging carries on',
      (tester) async {
        await openRegistration(tester);
        await enterBirthdate(tester, digitsFor(12));
        expect(find.text(RegistrationStrings.en.under16Body), findsOneWidget);
        expect(
          RegistrationStrings.en.under16Body,
          'You must be 16 or older to use this app independently. Please ask '
          'a parent or guardian to help set things up for you.',
        );
        await tester.tap(find.text(RegistrationStrings.en.under16Button));
        await tester.pumpAndSettle();
        expect(find.text(RegistrationStrings.en.under16Body), findsNothing);
        // the age was still filled in (nothing is blocked)
        expect(find.text('12'), findsWidgets);
      },
    );

    testWidgets('exactly 16 today: no notice', (tester) async {
      await openRegistration(tester);
      await enterBirthdate(tester, digitsFor(16));
      expect(find.text(RegistrationStrings.en.under16Body), findsNothing);
    });

    testWidgets('turning 16 tomorrow: still the notice', (tester) async {
      await openRegistration(tester);
      await enterBirthdate(tester, digitsFor(16, dayOffset: 1));
      expect(find.text(RegistrationStrings.en.under16Body), findsOneWidget);
    });

    testWidgets('an adult: no notice', (tester) async {
      await openRegistration(tester);
      await enterBirthdate(tester, '01152000');
      expect(find.text(RegistrationStrings.en.under16Body), findsNothing);
    });

    test('Filipino text', () {
      expect(
        RegistrationStrings.tl.under16Body,
        isNot(RegistrationStrings.en.under16Body),
      );
      expect(
        RegistrationStrings.tl.under16Button,
        isNot(RegistrationStrings.en.under16Button),
      );
    });
  });

  group('9. Registration limits', () {
    test('32 characters for first name, last name and username', () {
      final reg = source('lib/features/auth/screens/registration_screen.dart');
      expect(reg, contains('kUsernameMaxLength = 32'));
      expect(reg, contains('kNameMaxLength = 32'));
      expect(
        'LengthLimitingTextInputFormatter(kNameMaxLength)'
            .allMatches(reg)
            .length,
        2,
      );
      expect(
        'LengthLimitingTextInputFormatter(kUsernameMaxLength)'
            .allMatches(reg)
            .length,
        1,
      );
    });

    testWidgets('typing stops at 32 in the first and last name', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(AppLanguage.en, const RegistrationScreen()));
      await tester.pump();
      final first = find.byType(TextFormField).at(0);
      final last = find.byType(TextFormField).at(1);
      await tester.enterText(first, 'A' * 40);
      await tester.enterText(last, 'B' * 40);
      await tester.pump();
      String typed(Finder f) => tester
          .widget<TextField>(
            find.descendant(of: f, matching: find.byType(TextField)),
          )
          .controller!
          .text;
      expect(typed(first).length, 32);
      expect(typed(last).length, 32);
    });

    test('the "too long" message exists in both languages', () {
      expect(
        RegistrationStrings.tl.nameTooLong,
        isNot(RegistrationStrings.en.nameTooLong),
      );
    });
  });

  group('10. Overflow fixes', () {
    test('the Nearby Healthcare category row fills the row', () {
      final sheet = source('lib/core/widgets/nearby_healthcare_sheet.dart');
      expect(sheet, contains('isExpanded: true'));
      expect(sheet, contains('overflow: TextOverflow.ellipsis'));
      expect(sheet, contains('CustomScrollView('));
    });
  });
}
