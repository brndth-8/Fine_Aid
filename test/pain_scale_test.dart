import 'package:fine_aid/core/widgets/pain_scale_dialog.dart';
import 'package:fine_aid/data/pain_assessment.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/pain_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart' show TriageLevel;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pain levels (0-5)', () {
    test('0-1 mild, 2-3 moderate, 4 severe, 5 worst', () {
      for (final n in [0, 1]) {
        expect(painLevelFor(n), PainLevel.mild, reason: '$n');
      }
      for (final n in [2, 3]) {
        expect(painLevelFor(n), PainLevel.moderate, reason: '$n');
      }
      expect(painLevelFor(4), PainLevel.severe);
      expect(painLevelFor(5), PainLevel.worst);
    });

    test('only 4 and 5 add a reminder: 4 professional, 5 urgent', () {
      expect(reminderFromPain(null), ReminderLevel.none);
      for (final n in [0, 1, 2, 3]) {
        expect(reminderFromPain(n), ReminderLevel.none, reason: '$n');
      }
      expect(reminderFromPain(4), ReminderLevel.professional);
      expect(reminderFromPain(5), ReminderLevel.urgent);
    });

    test('a score outside 0-5 is not valid and adds nothing', () {
      expect(isValidPainScore(-1), isFalse);
      expect(isValidPainScore(6), isFalse);
      expect(isValidPainScore(null), isFalse);
      expect(isValidPainScore(0), isTrue);
      expect(isValidPainScore(5), isTrue);
      expect(reminderFromPain(8), ReminderLevel.none);
    });

    test('older 1-10 entries keep their old grouping', () {
      expect(legacyPainLevelFor(3), PainLevel.mild);
      expect(legacyPainLevelFor(5), PainLevel.moderate);
      expect(legacyPainLevelFor(8), PainLevel.severe);
      expect(legacyPainLevelFor(10), PainLevel.worst);
    });
  });

  group('combined with the AI result: the more serious one wins', () {
    ReminderLevel combine(TriageLevel t, bool needsPro, int? pain) =>
        combinedReminder(t, needsPro, pain);

    test('a minor-looking wound with pain 5 still shows urgent care', () {
      expect(combine(TriageLevel.selfCare, false, 5), ReminderLevel.urgent);
      expect(combine(TriageLevel.firstAid, false, 5), ReminderLevel.urgent);
    });

    test('pain 4 on a minor wound -> seek professional consultation', () {
      expect(
        combine(TriageLevel.selfCare, false, 4),
        ReminderLevel.professional,
      );
    });

    test('low or moderate pain on a minor wound adds no reminder', () {
      expect(combine(TriageLevel.selfCare, false, 0), ReminderLevel.none);
      expect(combine(TriageLevel.selfCare, false, 2), ReminderLevel.none);
      expect(combine(TriageLevel.firstAid, false, 3), ReminderLevel.none);
    });

    test('a low pain score never lowers what the AI said', () {
      expect(combine(TriageLevel.emergency, false, 0), ReminderLevel.emergency);
      expect(combine(TriageLevel.urgentCare, false, 1), ReminderLevel.urgent);
      expect(
        combine(TriageLevel.selfCare, true, 1),
        ReminderLevel.professional,
      );
    });

    test('pain 5 does not downgrade an AI emergency', () {
      expect(combine(TriageLevel.emergency, true, 5), ReminderLevel.emergency);
    });

    test('pain 5 raises "professional" to urgent', () {
      expect(combine(TriageLevel.selfCare, true, 5), ReminderLevel.urgent);
    });

    test('no pain score -> the AI result alone (existing behaviour)', () {
      expect(combine(TriageLevel.selfCare, false, null), ReminderLevel.none);
      expect(
        combine(TriageLevel.urgentCare, false, null),
        ReminderLevel.urgent,
      );
    });
  });

  group('pain text: one entry per rating', () {
    for (final (name, strings) in [
      ('English', PainStrings.en),
      ('Tagalog', PainStrings.tl),
    ]) {
      test('$name: six ratings, each with a label, message and small help', () {
        expect(strings.ratings, hasLength(kPainMax - kPainMin + 1));
        for (final r in strings.ratings) {
          expect(r.label.trim(), isNotEmpty);
          expect(r.message.trim(), isNotEmpty);
          expect(r.tips, isNotEmpty);
          for (final tip in r.tips) {
            expect(tip.trim(), isNotEmpty);
          }
        }
      });
    }

    test('every rating has its own message and its own small help', () {
      for (final strings in [PainStrings.en, PainStrings.tl]) {
        expect(
          strings.ratings.map((r) => r.message).toSet(),
          hasLength(6),
          reason: 'messages are all different',
        );
        expect(
          strings.ratings.map((r) => r.tips.join('|')).toSet(),
          hasLength(6),
          reason: 'small help is different for every rating',
        );
      }
    });

    test('rating 5 says to seek medical consultation, before its tips', () {
      expect(
        PainStrings.en.rating(5).message,
        'We advise you to seek medical consultation.',
      );
      expect(PainStrings.tl.rating(5).message, contains('magpakonsulta'));
      expect(PainStrings.en.rating(5).tips, isNotEmpty);
    });

    test('rating 4 recommends professional consultation', () {
      expect(
        PainStrings.en.rating(4).message.toLowerCase(),
        allOf(contains('recommend'), contains('professional consultation')),
      );
    });

    test('ratings 0-3 never tell the user to seek urgent care', () {
      for (var n = 0; n <= 3; n++) {
        final text = PainStrings.en.rating(n).message.toLowerCase();
        expect(text, isNot(contains('seek')), reason: '$n');
        expect(text, isNot(contains('urgent')), reason: '$n');
      }
    });

    test('labels follow the scale: 0 No pain ... 5 Worst pain', () {
      expect(PainStrings.en.rating(0).label, 'No pain');
      expect(PainStrings.en.rating(2).label, 'Minor');
      expect(PainStrings.en.rating(3).label, 'Moderate');
      expect(PainStrings.en.rating(5).label, 'Worst pain');
      expect(PainStrings.tl.rating(0).label, 'Walang sakit');
      expect(PainStrings.tl.rating(5).label, 'Pinakamatinding sakit');
    });

    test('score label names the rating in both languages', () {
      expect(PainStrings.en.scoreLabel(2), 'Pain score: 2/5 (Minor)');
      expect(PainStrings.en.scoreLabel(5), 'Pain score: 5/5 (Worst pain)');
      expect(
        PainStrings.tl.scoreLabel(0),
        'Antas ng sakit: 0/5 (Walang sakit)',
      );
    });

    test('Tagalog is translated, rating by rating', () {
      expect(PainStrings.tl.dialogTitle, isNot(PainStrings.en.dialogTitle));
      for (var n = 0; n <= 5; n++) {
        expect(
          PainStrings.tl.rating(n).label,
          isNot(PainStrings.en.rating(n).label),
        );
        expect(
          PainStrings.tl.rating(n).message,
          isNot(PainStrings.en.rating(n).message),
        );
        expect(
          PainStrings.tl.rating(n).tips.length,
          PainStrings.en.rating(n).tips.length,
          reason: 'same number of tips: $n',
        );
      }
    });
  });

  group('the pain pop-up cannot be skipped', () {
    Future<void> open(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
    }) async {
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showPainScaleDialog(context),
                    child: const Text('scan started'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('scan started'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows 0-5 with a label for each, and a disabled Continue '
        'until a number is chosen', (tester) async {
      await open(tester);
      expect(find.text('How much pain are you feeling?'), findsOneWidget);
      for (var n = 0; n <= 5; n++) {
        expect(find.text('$n'), findsOneWidget);
        expect(find.text(PainStrings.en.rating(n).label), findsOneWidget);
      }
      expect(find.text('6'), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('there is no Skip / Cancel option', (tester) async {
      await open(tester);
      expect(find.textContaining('Skip'), findsNothing);
      expect(find.textContaining('Cancel'), findsNothing);
      expect(find.textContaining('Later'), findsNothing);
    });

    testWidgets('tapping outside the dialog does not close it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('How much pain are you feeling?'), findsOneWidget);
    });

    testWidgets('the back button does not close it', (tester) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('How much pain are you feeling?'), findsOneWidget);
    });

    testWidgets('choosing 0 is allowed ("no pain") and returns it', (
      tester,
    ) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    result = await showPainScaleDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('0'));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continue'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(result, 0);
      expect(find.text('How much pain are you feeling?'), findsNothing);
    });

    testWidgets('choosing 5 returns 5', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    result = await showPainScaleDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(result, 5);
    });

    testWidgets('the pop-up is available in Tagalog', (tester) async {
      await open(tester, language: AppLanguage.tl);
      expect(find.text(PainStrings.tl.dialogTitle), findsOneWidget);
      expect(find.text(PainStrings.tl.rating(0).label), findsOneWidget);
      expect(find.text(PainStrings.tl.rating(5).label), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text(PainStrings.tl.continueButton), findsOneWidget);
    });
  });
}
