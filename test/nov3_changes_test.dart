import 'dart:io';
import 'package:fine_aid/core/widgets/assessment_questions.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/assessment_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('animal involved (cut, scratch, laceration)', () {
    test('only those three results are asked', () {
      expect(isCutScratchLacerationCategory('Laceration'), isTrue);
      expect(isCutScratchLacerationCategory('Minor Cut'), isTrue);
      expect(isCutScratchLacerationCategory('scratch'), isTrue);
      for (final other in ['Burn', 'Bruise', 'Rash', 'Abrasion', 'Swelling']) {
        expect(isCutScratchLacerationCategory(other), isFalse, reason: other);
      }
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: italic question with Yes and No', (
        tester,
      ) async {
        bool? answer;
        await tester.pumpWidget(
          AppLanguageScope(
            language: language,
            child: MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      answer = await askAnimalInvolved(context),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final s = language == AppLanguage.tl
            ? AssessmentStrings.tl
            : AssessmentStrings.en;
        final question = tester.widget<Text>(find.text(s.animalQuestion));
        expect(question.style?.fontStyle, FontStyle.italic);
        expect(find.text(s.yes), findsOneWidget);
        expect(find.text(s.no), findsOneWidget);
        await tester.tap(find.text(s.yes));
        await tester.pumpAndSettle();
        expect(answer, isTrue);
      });
    }

    testWidgets('No gives false', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await askAnimalInvolved(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    test('Yes shows the "cannot address" message and ends the scan', () {
      expect(
        AssessmentStrings.en.animalCannotHelp,
        'I cannot specifically address the issue you are pertaining to. '
        'Seek medical help if needed.',
      );
      final screen = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(screen, contains('isCutScratchLacerationCategory('));
      expect(screen, contains('_showAnimalDialog()'));
      // asked after the scan, before the pain scale
      expect(
        screen.indexOf('askAnimalInvolved(context)'),
        lessThan(screen.indexOf('answers = await _askQuestions(assessment)')),
      );
    });
  });

  group('offline strip and the PDF books', () {
    test('the strip moves the screen down instead of covering its top bar', () {
      final banner = source('lib/core/widgets/global_offline_banner.dart');
      expect(banner, contains('statusBar + _stripHeight'));
      expect(banner, contains('padding: media.padding.copyWith(top: 0)'));
    });

    test('the book title and page count in the top bar are white', () {
      final viewer = source(
        'lib/features/dashboard/screens/textbook_viewer_screen.dart',
      );
      expect(
        'color: Colors.white'.allMatches(viewer).length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('Health Kit works offline', () {
    final kit = source('lib/features/dashboard/first_aid_kit_screen.dart');

    test('no concern box, reminder, journal save or follow-up question', () {
      for (final gone in [
        '_concernController',
        '_remindMe',
        '_saveToJournal',
        '_sendFollowUp',
        'RemindMeCheckbox',
        'showModalBottomSheet',
      ]) {
        expect(kit, isNot(contains(gone)), reason: gone);
      }
    });

    test('a card starts the questions straight away', () {
      expect(kit, contains('await _startQuestions();'));
    });
  });

  group('Settings and Help', () {
    test('no Rate this app row in Settings', () {
      expect(
        source('lib/features/settings/screens/settings_screen.dart'),
        isNot(contains('rateApp')),
      );
    });

    test('Help uses the new heart, a low banner and maroon card titles', () {
      final help = source('lib/features/settings/screens/help_screen.dart');
      expect(help, contains('aspectRatio: 3 / 2'));
      expect(help, contains('assets/images/help_hero.png'));
      expect(help, contains('color: theme.colorScheme.primary'));
    });
  });
}
