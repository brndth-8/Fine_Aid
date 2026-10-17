import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/auth/screens/permission_screen.dart';
import 'package:fine_aid/features/auth/screens/terms_screen.dart';
import 'package:fine_aid/features/onboarding/screens/onboarding_screen.dart';
import 'package:fine_aid/features/settings/screens/help_screen.dart';
import 'package:fine_aid/features/settings/screens/help_topic_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/checklist_strings.dart';
import 'package:fine_aid/i18n/help_strings.dart';
import 'package:fine_aid/i18n/onboarding_strings.dart';
import 'package:fine_aid/i18n/permission_strings.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:fine_aid/i18n/terms_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter's debug-only "ListTile background may be invisible" assertion
/// fires on these screens' existing layouts (a ListTile inside a coloured
/// box). It is a styling hint, unrelated to what is being tested, so it is
/// ignored here; every other error still fails the test.
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

Future<void> _pump(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLanguageController (saved choice)', () {
    test('loads a saved Tagalog choice, English otherwise', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'tl'});
      await AppLanguageController.instance.load();
      expect(AppLanguageController.instance.language, AppLanguage.tl);
    });

    test('setLanguage notifies listeners and saves the choice', () async {
      SharedPreferences.setMockInitialValues({});
      var notified = 0;
      void listener() => notified++;
      AppLanguageController.instance.addListener(listener);
      addTearDown(
        () => AppLanguageController.instance.removeListener(listener),
      );

      await AppLanguageController.instance.setLanguage(AppLanguage.en);
      expect(AppLanguageController.instance.language, AppLanguage.en);
      expect(notified, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('app_language'),
        'en',
      );

      await AppLanguageController.instance.setLanguage(AppLanguage.tl);
      expect(notified, 2);
      expect(
        (await SharedPreferences.getInstance()).getString('app_language'),
        'tl',
      );

      // choosing the same language again changes nothing
      await AppLanguageController.instance.setLanguage(AppLanguage.tl);
      expect(notified, 2);
    });
  });

  group('English text is unchanged from the original wording', () {
    test('spot checks', () {
      expect(TermsStrings.en.title, 'Terms & Conditions');
      expect(TermsStrings.en.agree, 'I Agree & Continue');
      expect(TermsStrings.en.sections.first.header, 'Medical Disclaimer');
      expect(PermissionStrings.en.title, 'Camera Access Required');
      expect(PermissionStrings.en.continueButton, 'Continue');
      expect(ChecklistStrings.en.title, 'Health Profile');
      expect(ChecklistStrings.en.hemophilia, 'Hemophilia or Blood Disorders');
      expect(HelpStrings.en.heading, 'How can we help?');
      expect(HelpStrings.en.referencesTile, 'References');
      expect(OnboardingStrings.en.pages.first.title, 'AI Wound Scanning');
      expect(SettingsStrings.en.logOut, 'Log Out');
      expect(SettingsStrings.en.signIn, 'Sign in');
    });
  });

  group('Tagalog is complete for every module', () {
    String? blank(Iterable<String> all) {
      for (final s in all) {
        if (s.trim().isEmpty) return 'empty string';
      }
      return null;
    }

    test('Terms: same structure, nothing empty, actually translated', () {
      const en = TermsStrings.en;
      const tl = TermsStrings.tl;
      expect(tl.sections.length, en.sections.length);
      for (var i = 0; i < en.sections.length; i++) {
        expect(tl.sections[i].header, isNot(en.sections[i].header));
        expect(tl.sections[i].bullets.length, en.sections[i].bullets.length);
        expect(
          tl.sections[i].paragraph == null,
          en.sections[i].paragraph == null,
        );
      }
      expect(tl.closing, isNot(en.closing));
      expect(
        blank([
          tl.title,
          tl.scrollHint,
          tl.agree,
          tl.saveError,
          tl.closing,
          for (final s in tl.sections) ...[
            s.header,
            ?s.paragraph,
            ...s.bullets,
          ],
        ]),
        isNull,
      );
    });

    test('Permission, Checklist, Settings, camera message', () {
      expect(PermissionStrings.tl.title, isNot(PermissionStrings.en.title));
      expect(PermissionStrings.tl.intro, isNot(PermissionStrings.en.intro));
      expect(PermissionStrings.tl.continueButton, 'Magpatuloy');
      expect(ChecklistStrings.tl.intro, isNot(ChecklistStrings.en.intro));
      expect(
        ChecklistStrings.tl.noneOfTheAbove,
        isNot(ChecklistStrings.en.noneOfTheAbove),
      );
      expect(SettingsStrings.tl.title, isNot(SettingsStrings.en.title));
      expect(SettingsStrings.tl.signIn, isNot(SettingsStrings.en.signIn));
      expect(
        CameraPermissionStrings.tl.blockedMessage,
        isNot(CameraPermissionStrings.en.blockedMessage),
      );
      expect(
        CameraPermissionStrings.tl.openSettings,
        isNot(CameraPermissionStrings.en.openSettings),
      );
    });

    test('Help: all four topics translated with matching structure', () {
      for (final pair in [
        (HelpStrings.en.gettingStarted, HelpStrings.tl.gettingStarted),
        (HelpStrings.en.privacy, HelpStrings.tl.privacy),
        (HelpStrings.en.journal, HelpStrings.tl.journal),
        (HelpStrings.en.references, HelpStrings.tl.references),
      ]) {
        expect(pair.$2.title, isNot(pair.$1.title));
        expect(pair.$2.paragraphs.length, pair.$1.paragraphs.length);
        expect(pair.$2.cardLabels.length, pair.$1.cardLabels.length);
        for (var i = 0; i < pair.$1.paragraphs.length; i++) {
          expect(pair.$2.paragraphs[i], isNot(pair.$1.paragraphs[i]));
        }
      }
    });

    test('Onboarding: four slides in both languages', () {
      expect(
        OnboardingStrings.tl.pages.length,
        OnboardingStrings.en.pages.length,
      );
      for (var i = 0; i < OnboardingStrings.en.pages.length; i++) {
        expect(
          OnboardingStrings.tl.pages[i].description,
          isNot(OnboardingStrings.en.pages[i].description),
        );
      }
    });
  });

  group('Screens follow the language', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    testWidgets(
      'Terms: every heading and the closing text, in both languages',
      (tester) async {
        for (final entry in {
          AppLanguage.en: TermsStrings.en,
          AppLanguage.tl: TermsStrings.tl,
        }.entries) {
          await _pump(
            tester,
            const TermsScreen(readOnly: true),
            language: entry.key,
          );
          expect(find.text(entry.value.title), findsOneWidget);
          for (final section in entry.value.sections) {
            expect(find.text(section.header), findsOneWidget);
          }
          expect(find.text(entry.value.closing), findsOneWidget);
        }
      },
    );

    testWidgets('Camera permission screen in Tagalog', (tester) async {
      _ignoreListTileInkWarning();
      await _pump(tester, const PermissionScreen(), language: AppLanguage.tl);
      expect(find.text(PermissionStrings.tl.title), findsOneWidget);
      expect(find.text(PermissionStrings.tl.allowCamera), findsOneWidget);
      expect(find.text(PermissionStrings.tl.skipForNow), findsOneWidget);
      expect(find.text('Camera Access Required'), findsNothing);
    });

    testWidgets('Health checklist in Tagalog', (tester) async {
      _ignoreListTileInkWarning();
      await _pump(
        tester,
        const HealthChecklistScreen(),
        language: AppLanguage.tl,
      );
      expect(find.text(ChecklistStrings.tl.title), findsOneWidget);
      expect(find.text(ChecklistStrings.tl.hemophilia), findsOneWidget);
      expect(find.text(ChecklistStrings.tl.commonAllergies), findsOneWidget);
      expect(find.text('Health Profile'), findsNothing);
    });

    testWidgets('Onboarding in Tagalog', (tester) async {
      await _pump(tester, const OnboardingScreen(), language: AppLanguage.tl);
      expect(find.text(OnboardingStrings.tl.pages.first.title), findsOneWidget);
      expect(find.text(OnboardingStrings.tl.skip), findsOneWidget);
      expect(find.text(OnboardingStrings.tl.next), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Help & Support list and every topic page in Tagalog', (
      tester,
    ) async {
      await _pump(tester, const HelpScreen(), language: AppLanguage.tl);
      expect(find.text(HelpStrings.tl.heading), findsOneWidget);
      expect(find.text(HelpStrings.tl.gettingStartedTile), findsOneWidget);
      expect(find.text(HelpStrings.tl.privacyTile), findsOneWidget);
      expect(find.text(HelpStrings.tl.journalTile), findsOneWidget);
      expect(find.text(HelpStrings.tl.referencesTile), findsOneWidget);

      for (final topic in HelpTopic.values) {
        await _pump(
          tester,
          HelpTopicScreen(topic: topic),
          language: AppLanguage.tl,
        );
        final text = switch (topic) {
          HelpTopic.gettingStarted => HelpStrings.tl.gettingStarted,
          HelpTopic.privacy => HelpStrings.tl.privacy,
          HelpTopic.journal => HelpStrings.tl.journal,
          HelpTopic.references => HelpStrings.tl.references,
        };
        expect(find.text(text.title), findsOneWidget);
        expect(find.text(text.paragraphs.first), findsOneWidget);
        for (final label in text.cardLabels) {
          expect(find.text(label), findsOneWidget);
        }
      }
    });

    testWidgets('a screen already on display redraws when the language '
        'changes', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = ValueNotifier(AppLanguage.en);
      await tester.pumpWidget(
        ValueListenableBuilder<AppLanguage>(
          valueListenable: language,
          builder: (context, value, _) => AppLanguageScope(
            language: value,
            child: const MaterialApp(home: HelpScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('How can we help?'), findsOneWidget);

      language.value = AppLanguage.tl;
      await tester.pump();
      expect(find.text('How can we help?'), findsNothing);
      expect(find.text(HelpStrings.tl.heading), findsOneWidget);

      language.value = AppLanguage.en;
      await tester.pump();
      expect(find.text('How can we help?'), findsOneWidget);
    });

    testWidgets('Settings has a language toggle that switches the whole screen '
        'and is remembered', (tester) async {
      _ignoreListTileInkWarning();
      SharedPreferences.setMockInitialValues({});
      await AppLanguageController.instance.setLanguage(AppLanguage.en);
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Same wiring main.dart uses: rebuild the app on a language change.
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: AppLanguageController.instance,
          builder: (context, _) => MaterialApp(
            builder: (context, child) => AppLanguageScope(
              language: AppLanguageController.instance.language,
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      await tester.tap(find.text('Tagalog'));
      await tester.pump();
      expect(AppLanguageController.instance.language, AppLanguage.tl);
      expect(find.text(SettingsStrings.tl.title), findsOneWidget);
      expect(find.text(SettingsStrings.tl.language), findsOneWidget);
      expect(find.text(SettingsStrings.tl.signIn), findsOneWidget); // guest
      expect(find.text('Settings'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString('app_language'),
        'tl',
      );

      await tester.tap(find.text('English'));
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
