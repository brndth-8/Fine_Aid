import 'package:fine_aid/core/widgets/category_info_dialog.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/classification_strings.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:fine_aid/i18n/pain_strings.dart';
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

const _injury = 'Injury (Wounds/laceration/Abrasion)';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> open(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    _ignoreListTileInkWarning();
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: const MaterialApp(home: NewEntryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The guest notice shown on entry.
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
  }

  final en = JournalEntryStrings.en;
  final dialog = find.byType(AlertDialog);

  Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);

  group('the redesigned Add new entry screen', () {
    testWidgets('has the header, image box, form, categories, pain scale and '
        'buttons', (tester) async {
      await open(tester);
      expect(find.text('Health Journal'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.text('Add Image'), findsOneWidget);
      expect(find.text(en.addImageSubtitle), findsOneWidget);
      expect(find.text(en.titleLabel), findsOneWidget);
      expect(find.text(en.titleHint), findsOneWidget);
      expect(find.text(en.dateLabel), findsOneWidget);
      expect(find.text(en.feelingLabel), findsOneWidget);
      expect(find.text(en.save), findsOneWidget);
      expect(find.text(en.cancel), findsOneWidget);
      // today's date, formatted like "Sunday, October 11"
      expect(find.text(en.formatDate(DateTime.now())), findsOneWidget);
    });

    testWidgets('shows the four existing categories, none renamed', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Injury'), findsOneWidget);
      expect(find.text(en.injurySubtitle), findsOneWidget);
      expect(find.text('Burns'), findsOneWidget);
      expect(find.text('Skin Issues'), findsOneWidget);
      expect(find.text('Scratch'), findsOneWidget);
    });

    testWidgets('has the 0-5 pain scale, and a message once one is chosen', (
      tester,
    ) async {
      await open(tester);
      expect(find.text(PainStrings.en.dialogTitle), findsOneWidget);
      for (var n = 0; n <= 5; n++) {
        expect(find.text('$n'), findsOneWidget);
      }
      expect(find.text('6'), findsNothing);
      expect(find.text(PainStrings.en.rating(3).message), findsNothing);

      await tester.tap(find.text('3'));
      await tester.pump();
      expect(find.text(PainStrings.en.rating(3).message), findsOneWidget);

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(
        find.text('We advise you to seek medical consultation.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel goes back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewEntryScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      _ignoreListTileInkWarning();
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(NewEntryScreen), findsNothing);
    });
  });

  group('category pop-ups', () {
    for (final key in ['Burns', 'Skin Issues', 'Scratch']) {
      testWidgets('$key: name, its own description and a Confirm button', (
        tester,
      ) async {
        await open(tester);
        await tester.tap(find.text(en.categoryNames[key]!));
        await tester.pumpAndSettle();

        final info = classificationInfoFor(key, tagalog: false)!;
        expect(inDialog(find.text(en.categoryNames[key]!)), findsOneWidget);
        expect(inDialog(find.text(info.what)), findsOneWidget);
        expect(inDialog(find.text(en.confirm)), findsOneWidget);

        await tester.tap(inDialog(find.text(en.confirm)));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
          find.text(
            en.selectedFormat.replaceFirst(
              '{category}',
              en.categoryNames[key]!,
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('each category shows a different description', (tester) async {
      await open(tester);
      final seen = <String>{};
      for (final key in ['Burns', 'Skin Issues', 'Scratch', _injury]) {
        await tester.tap(find.text(en.categoryNames[key]!));
        await tester.pumpAndSettle();
        final text = tester
            .widgetList<Text>(inDialog(find.byType(Text)))
            .map((t) => t.data)
            .join('|');
        seen.add(text);
        await tester.tap(inDialog(find.text(en.cancel)));
        await tester.pumpAndSettle();
      }
      expect(seen, hasLength(4));
    });

    testWidgets('Cancel does not select the category', (tester) async {
      await open(tester);
      await tester.tap(find.text('Burns'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(en.cancel)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected:'), findsNothing);
    });

    testWidgets('tapping outside the pop-up does not select the category', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Scratch'));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.textContaining('Selected:'), findsNothing);
    });

    testWidgets('the back button does not select the category', (tester) async {
      await open(tester);
      await tester.tap(find.text('Skin Issues'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected:'), findsNothing);
    });

    testWidgets('the pop-up is in Tagalog when the language is', (
      tester,
    ) async {
      await open(tester, language: AppLanguage.tl);
      final tl = JournalEntryStrings.tl;
      await tester.tap(find.text(tl.categoryNames['Burns']!));
      await tester.pumpAndSettle();
      final info = classificationInfoFor('Burns', tagalog: true)!;
      expect(inDialog(find.text(info.what)), findsOneWidget);
      expect(inDialog(find.text(tl.confirm)), findsOneWidget);
      expect(inDialog(find.text(en.confirm)), findsNothing);
    });
  });

  group('Injury type (Deep / Minor)', () {
    Future<void> openInjuryTypeStep(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(en.confirm)));
      await tester.pumpAndSettle();
    }

    testWidgets('after Confirm, Deep and Minor are offered with their '
        'descriptions', (tester) async {
      await openInjuryTypeStep(tester);
      final info = classificationInfoFor(_injury, tagalog: false)!;
      expect(inDialog(find.text(en.injuryTypeTitle)), findsOneWidget);
      expect(inDialog(find.text(en.minor)), findsOneWidget);
      expect(inDialog(find.text(en.deep)), findsOneWidget);
      expect(inDialog(find.text(info.minorSigns)), findsOneWidget);
      expect(inDialog(find.text(info.seriousSigns)), findsOneWidget);
    });

    testWidgets('the descriptions are the drafted wording', (tester) async {
      final info = classificationInfoFor(_injury, tagalog: false)!;
      final minor = info.minorSigns.toLowerCase();
      expect(minor, contains('shallow'));
      expect(minor, contains('top layer of skin'));
      expect(minor, contains('gentle pressure'));
      expect(minor, contains('close together'));
      final deep = info.seriousSigns.toLowerCase();
      for (final word in [
        'fat',
        'muscle',
        'bone',
        'gape',
        '10 minutes',
        'dirty or puncturing',
      ]) {
        expect(deep, contains(word), reason: word);
      }
    });

    testWidgets('one is required before Confirm works', (tester) async {
      await openInjuryTypeStep(tester);
      final confirm = tester.widget<ElevatedButton>(
        inDialog(find.widgetWithText(ElevatedButton, en.confirm)),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('choosing Deep and confirming selects Injury — Deep', (
      tester,
    ) async {
      await openInjuryTypeStep(tester);
      await tester.tap(inDialog(find.text(en.deep)));
      await tester.pump();
      await tester.tap(inDialog(find.text(en.confirm)));
      await tester.pumpAndSettle();
      expect(find.text('Selected: Injury — Deep'), findsOneWidget);
    });

    testWidgets('choosing Minor selects Injury — Minor', (tester) async {
      await openInjuryTypeStep(tester);
      await tester.tap(inDialog(find.text(en.minor)));
      await tester.pump();
      await tester.tap(inDialog(find.text(en.confirm)));
      await tester.pumpAndSettle();
      expect(find.text('Selected: Injury — Minor'), findsOneWidget);
    });

    testWidgets('closing without choosing selects nothing', (tester) async {
      await openInjuryTypeStep(tester);
      await tester.tap(inDialog(find.text(en.cancel)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected:'), findsNothing);
    });

    testWidgets('the options are in Tagalog too', (tester) async {
      await open(tester, language: AppLanguage.tl);
      final tl = JournalEntryStrings.tl;
      await tester.tap(find.text(tl.categoryNames[_injury]!));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(tl.confirm)));
      await tester.pumpAndSettle();
      final info = classificationInfoFor(_injury, tagalog: true)!;
      expect(inDialog(find.text(tl.deep)), findsOneWidget);
      expect(inDialog(find.text(tl.minor)), findsOneWidget);
      expect(inDialog(find.text(info.minorSigns)), findsOneWidget);
      expect(inDialog(find.text(info.seriousSigns)), findsOneWidget);
    });

    testWidgets('picking another category clears the Injury type', (
      tester,
    ) async {
      await openInjuryTypeStep(tester);
      await tester.tap(inDialog(find.text(en.deep)));
      await tester.pump();
      await tester.tap(inDialog(find.text(en.confirm)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Burns'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(en.confirm)));
      await tester.pumpAndSettle();
      expect(find.text('Selected: Burns'), findsOneWidget);
      expect(find.textContaining('Deep'), findsNothing);
    });
  });

  group('the one reusable pop-up', () {
    testWidgets('without options, Confirm returns right away', (tester) async {
      CategoryDialogResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await showCategoryInfoDialog(
                context,
                title: 'T',
                description: 'D',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.option, isNull);
    });
  });
}
