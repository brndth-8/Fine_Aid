import 'dart:io';
import 'package:fine_aid/core/widgets/otc_suggestions_block.dart';
import 'package:fine_aid/features/chatbot/screens/chatbot_screen.dart';
import 'package:fine_aid/features/settings/screens/licenses_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/chat_strings.dart';
import 'package:fine_aid/i18n/licenses_strings.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:fine_aid/i18n/tour_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
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

  group('B. First Aid Assistance follows the app language', () {
    testWidgets('English, then Filipino when the language changes', (
      tester,
    ) async {
      phone(tester);
      final en = ChatStrings.en;
      final tl = ChatStrings.tl;

      await tester.pumpWidget(app(AppLanguage.en, const ChatbotScreen()));
      await tester.pump();
      expect(find.text(en.title), findsOneWidget);
      expect(find.text(en.banner), findsOneWidget);
      expect(find.text(en.greetingGeneral), findsOneWidget);
      expect(find.text(en.inputHint), findsOneWidget);
      // no language button in the bar
      expect(find.text('Filipino'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);

      // the language changes in Settings: no restart, the screen rebuilds
      await tester.pumpWidget(app(AppLanguage.tl, const ChatbotScreen()));
      await tester.pump();
      expect(find.text(tl.title), findsOneWidget);
      expect(find.text(tl.banner), findsOneWidget);
      expect(find.text(tl.greetingGeneral), findsOneWidget);
      expect(find.text(tl.inputHint), findsOneWidget);
      expect(find.text(en.banner), findsNothing);
    });

    testWidgets('the greeting about an entry follows the language too', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(AppLanguage.tl, const ChatbotScreen(initialContext: 'Injury')),
      );
      await tester.pump();
      expect(find.text(ChatStrings.tl.greetingFor('Injury')), findsOneWidget);
    });

    testWidgets('the suggestions block is translated', (tester) async {
      phone(tester);
      const suggestions = [
        OtcSuggestion(
          name: 'Paracetamol',
          ageLimit: '',
          allergyPrecaution: '',
          howToUse: '',
          category: OtcSuggestionCategory.product,
        ),
        OtcSuggestion(
          name: 'Cold pack',
          ageLimit: '',
          allergyPrecaution: '',
          howToUse: '',
          category: OtcSuggestionCategory.supply,
        ),
      ];
      for (final language in AppLanguage.values) {
        final s = language == AppLanguage.tl ? ChatStrings.tl : ChatStrings.en;
        await tester.pumpWidget(
          app(
            language,
            const Scaffold(body: OtcSuggestionsBlock(suggestions: suggestions)),
          ),
        );
        expect(find.text(s.suggestedProducts), findsOneWidget);
        expect(find.text(s.suggestedSupplies), findsOneWidget);
        expect(find.text(s.seeDoctorNote), findsOneWidget);
      }
    });

    test('no hard-coded English is left in the chat bar', () {
      final chat = source('lib/features/chatbot/screens/chatbot_screen.dart');
      for (final gone in [
        "'Describe your concern'",
        "'First Aid Assistance'",
        "'Cancel recording'",
        "'Stop and send'",
        '_showTagalog',
      ]) {
        expect(chat, isNot(contains(gone)), reason: gone);
      }
    });
  });

  group('A. AI scan', () {
    test('no translate button on the scan result', () {
      final result = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(result, isNot(contains('Translate to Tagalog')));
      expect(result, isNot(contains('_toggleTagalog')));
      expect(result, isNot(contains('_showTagalog')));
    });
  });

  group('C. Health Journal', () {
    final menu = source('lib/features/journal/screens/journal_entry_menu.dart');
    final detail = source(
      'lib/features/journal/screens/entry_detail_screen.dart',
    );

    test('the three dots are white on the maroon bar; menu icons are grey', () {
      expect(detail, contains('iconColor: Colors.white'));
      expect(
        menu,
        contains('Icons.edit_outlined, size: 20, color: Colors.grey'),
      );
      expect(
        menu,
        contains('Icons.delete_outline, size: 20, color: Colors.grey'),
      );
    });

    test(
      'the export carries the Health Profile\'s conditions and medications',
      () {
        final export = source('lib/services/export_service.dart');
        expect(export, contains("'Health Conditions'"));
        expect(export, contains("'Current Medications'"));
        expect(export, contains("'None listed'"));
        expect(detail, contains('profileConditionLabels('));
        expect(detail, contains('profileMedications(profile)'));
        // both Export buttons use the same routine
        expect(
          '_exportEntry('.allMatches(detail).length,
          greaterThanOrEqualTo(3),
        );
      },
    );
  });

  group('D. Help pages have no duplicate label above the text', () {
    test('the page title is only in the top bar', () {
      final help = source(
        'lib/features/settings/screens/help_topic_screen.dart',
      );
      expect(help, isNot(contains('section.title,\n')));
      expect(help, contains('title: Text(section.title)'));
    });
  });

  group('E. Settings', () {
    test('no Appearance option and no theme-switching code', () {
      expect(File('lib/core/theme_mode_controller.dart').existsSync(), isFalse);
      final personalization = source(
        'lib/features/settings/screens/personalization_screen.dart',
      );
      expect(personalization, isNot(contains('ThemeMode')));
      expect(personalization, isNot(contains('appearance')));
      final main = source('lib/main.dart');
      expect(main, isNot(contains('ThemeModeController')));
      expect(main, contains('themeMode: ThemeMode.light'));
      final settings = source('lib/i18n/settings_strings.dart');
      expect(settings, isNot(contains('darkMode')));
    });

    test('Help Tour: the Settings step has the exact new text', () {
      expect(
        TourStrings.en.steps.last.description,
        'Personalized by changing text size, View App Information, Choose '
        'preferred language and share your feedback',
      );
      expect(
        TourStrings.tl.steps.last.description,
        isNot(TourStrings.en.steps.last.description),
      );
      expect(TourStrings.tl.steps.last.description, contains('feedback'));
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: View Licenses shows the disclosure', (
        tester,
      ) async {
        phone(tester, h: 4000);
        final s = language == AppLanguage.tl
            ? LicensesStrings.tl
            : LicensesStrings.en;
        await tester.pumpWidget(app(language, const LicensesScreen()));
        expect(find.text(s.viewLicenses), findsOneWidget); // top bar
        expect(find.text(s.title), findsOneWidget);
        expect(find.text(s.intro), findsOneWidget);
        expect(find.text(s.whyTitle), findsOneWidget);
        expect(find.text(s.appVersion), findsOneWidget);
        expect(find.text(s.stackTitle), findsOneWidget);
        expect(find.text(s.liabilityTitle), findsOneWidget);
        expect(find.text(s.liabilityBody), findsOneWidget);
        for (final tech in s.technologies) {
          expect(find.text(tech.name), findsOneWidget);
        }
        expect(s.whyBullets.length, 3);
        expect(s.technologies.length, 4);
        expect(tester.takeException(), isNull);
      });
    }

    test('the English wording is the PDF\'s', () {
      const s = LicensesStrings.en;
      expect(s.title, 'Application Licenses & Technology Disclosure');
      expect(s.appVersion, 'App Version: v1.0.1');
      expect(
        [for (final t in s.technologies) t.name],
        [
          'Gemini Flash (Google AI)',
          'Firebase (Google Cloud)',
          'Semaphore SMS API',
          'Flutter (Google)',
        ],
      );
      expect(
        [for (final b in s.whyBullets) b.lead],
        ['Data Privacy & Security:', 'AI Accountability:', 'Informed Consent:'],
      );
      expect(s.technologies[1].keyServices.map((k) => k.$1), [
        'Firebase Authentication:',
        'Cloud Firestore / Database:',
      ]);
      expect(LicensesStrings.tl.title, isNot(s.title));
    });

    testWidgets('About Application opens a box with View Licenses', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.en, const SettingsScreen()));
      await tester.pump();
      await tester.tap(find.text(SettingsStrings.en.aboutApplication));
      await tester.pumpAndSettle();
      expect(find.text('View Licenses'), findsOneWidget);
      await tester.tap(find.text('View Licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
    });
  });

  group('F. Edit Profile: no Verify button', () {
    test('there is no Verify control left', () {
      final edit = source(
        'lib/features/settings/screens/edit_profile_screen.dart',
      );
      expect(edit, isNot(contains('ScreenText.of(context).verify')));
      expect(edit, isNot(contains('_handleVerifyCurrentPassword')));
      expect(edit, contains('incorrectCurrentPassword'));
    });
  });

  group('G. Legal text is the PDF\'s', () {
    test('Terms and Camera Permission come from the generated content', () {
      final terms = source('lib/i18n/terms_strings.dart');
      expect(terms, contains('kTermsSections'));
      final permission = source('lib/i18n/permission_strings.dart');
      expect(permission, contains('kPermissionSections'));
    });

    test('Health Profile Filipino uses the PDF\'s wording', () {
      final tl = source('lib/i18n/checklist_strings.dart');
      for (final phrase in [
        'Mga Karaniwan na Allergies',
        'Mga Allergy na nagmumula sa insekto',
        'Mangyaring tukuyin ang iyong (mga) kondisyon sa kalusugan',
        'Iba pang karamdaman sa pagdurugo o pagbuo ng dugo',
      ]) {
        expect(tl, contains(phrase), reason: phrase);
      }
    });
  });
}
