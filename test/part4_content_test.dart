import 'package:fine_aid/core/widgets/classification_info_button.dart';
import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/chatbot/screens/chatbot_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/chat_upload_strings.dart';
import 'package:fine_aid/i18n/checklist_strings.dart';
import 'package:fine_aid/i18n/classification_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart' show WoundCategories;
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('4E classification explanations', () {
    test('every AI / First Aid / journal classification has one, in both '
        'languages', () {
      final names = [
        ...WoundCategories.all,
        // Health Journal manual-entry classifications
        'Injury (Wounds/laceration/Abrasion)',
        'Burns',
        'Skin Issues',
        'Scratch',
        'Animal Bite/Scratch',
      ];
      for (final name in names) {
        final en = classificationInfoFor(name, tagalog: false);
        final tl = classificationInfoFor(name, tagalog: true);
        expect(en, isNotNull, reason: 'English: $name');
        expect(tl, isNotNull, reason: 'Tagalog: $name');
        expect(en!.what, isNotEmpty, reason: name);
        expect(tl!.what, isNot(en.what), reason: 'Tagalog differs: $name');
        // sections that exist in English also exist in Tagalog
        expect(tl.minorSigns.isEmpty, en.minorSigns.isEmpty, reason: name);
        expect(tl.seriousSigns.isEmpty, en.seriousSigns.isEmpty, reason: name);
      }
    });

    test('lookup ignores case and spacing; unknown names have none', () {
      expect(classificationInfoFor('  LACERATION ', tagalog: false), isNotNull);
      expect(classificationInfoFor('Not a real type', tagalog: false), isNull);
      expect(classificationInfoFor(null, tagalog: false), isNull);
      expect(classificationInfoFor('', tagalog: false), isNull);
    });

    test('the deep-vs-minor guidance covers the signs you listed', () {
      final laceration = classificationInfoFor('Laceration', tagalog: false)!;
      final serious = laceration.seriousSigns.toLowerCase();
      expect(serious, contains('fat'));
      expect(serious, contains('muscle'));
      expect(serious, contains('bone'));
      expect(serious, contains('10 minutes'));
      expect(serious, contains('gape'));
      expect(laceration.minorSigns.toLowerCase(), contains('shallow'));
    });

    testWidgets('the (i) button opens the explanation sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassificationInfoButton(classification: 'Laceration'),
          ),
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('What it is'), findsOneWidget);
      expect(find.text('Usually minor if'), findsOneWidget);
      expect(find.text('See a healthcare professional if'), findsOneWidget);
      expect(find.textContaining('fat (yellow)'), findsOneWidget);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('the explanation shows in Tagalog', (tester) async {
      await tester.pumpWidget(
        const AppLanguageScope(
          language: AppLanguage.tl,
          child: MaterialApp(
            home: Scaffold(
              body: ClassificationInfoButton(classification: 'Burn'),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text(ClassificationInfoLabels.tl.whatIsIt), findsOneWidget);
      expect(find.text('What it is'), findsNothing);
    });

    testWidgets('no button for a classification without an explanation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassificationInfoButton(classification: 'Mystery'),
          ),
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  });

  group('screens that need Firebase', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      AppLanguage language = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 3600);
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

    testWidgets('4A checklist: a short description under every item '
        '(English)', (tester) async {
      _ignoreListTileInkWarning();
      await pump(tester, const HealthChecklistScreen());
      for (final text in [
        ChecklistStrings.en.diabetesInfo,
        ChecklistStrings.en.hemophiliaInfo,
        ChecklistStrings.en.severeAllergiesInfo,
        ChecklistStrings.en.noneInfo,
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      // the example wording you gave for allergies
      expect(
        find.textContaining(
          'food, medicine, or insect bites, which may cause itching, rash, '
          'or swelling',
        ),
        findsOneWidget,
      );
    });

    testWidgets('4A checklist: descriptions in Tagalog', (tester) async {
      _ignoreListTileInkWarning();
      await pump(
        tester,
        const HealthChecklistScreen(),
        language: AppLanguage.tl,
      );
      for (final text in [
        ChecklistStrings.tl.diabetesInfo,
        ChecklistStrings.tl.hemophiliaInfo,
        ChecklistStrings.tl.severeAllergiesInfo,
        ChecklistStrings.tl.noneInfo,
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text(ChecklistStrings.en.diabetesInfo), findsNothing);
    });

    test('4A: every description is translated', () {
      expect(
        ChecklistStrings.tl.diabetesInfo,
        isNot(ChecklistStrings.en.diabetesInfo),
      );
      expect(
        ChecklistStrings.tl.hemophiliaInfo,
        isNot(ChecklistStrings.en.hemophiliaInfo),
      );
      expect(
        ChecklistStrings.tl.severeAllergiesInfo,
        isNot(ChecklistStrings.en.severeAllergiesInfo),
      );
      expect(ChecklistStrings.tl.noneInfo, isNot(ChecklistStrings.en.noneInfo));
    });

    testWidgets('4B chat: the add-photo button is there, and a guest is asked '
        'to log in', (tester) async {
      _ignoreListTileInkWarning();
      await pump(tester, const ChatbotScreen());
      expect(find.byTooltip(ChatUploadStrings.en.addFile), findsOneWidget);

      await tester.tap(find.byTooltip(ChatUploadStrings.en.addFile));
      await tester.pump();
      expect(find.text(ChatUploadStrings.en.loginRequired), findsOneWidget);
      // no picker sheet for a guest
      expect(find.text(ChatUploadStrings.en.takePhoto), findsNothing);
    });

    testWidgets('4B chat: the add-photo button in Tagalog', (tester) async {
      _ignoreListTileInkWarning();
      await pump(tester, const ChatbotScreen(), language: AppLanguage.tl);
      expect(find.byTooltip(ChatUploadStrings.tl.addFile), findsOneWidget);
    });

    test('4B: upload text is translated', () {
      expect(
        ChatUploadStrings.tl.savedMessage,
        isNot(ChatUploadStrings.en.savedMessage),
      );
      expect(
        ChatUploadStrings.tl.uploadFailed,
        isNot(ChatUploadStrings.en.uploadFailed),
      );
    });
  });
}
