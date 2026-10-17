import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/data/journal_evaluation.dart';
import 'package:fine_aid/features/journal/screens/entry_detail_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _aiEntry({Map<String, dynamic> extra = const {}}) => {
  'classification': 'Laceration',
  'source': 'ai_camera',
  'visibleBleeding': 'none',
  'apparentDepth': 'superficial',
  'warningSigns': <String>[],
  'triage': 'selfCare',
  'needsProfessionalEvaluation': false,
  'painScore': 2,
  'firstAidSteps': [
    'Rinse the wound gently with clean water.',
    'Cover with a sterile non-stick dressing.',
    'Keep the area clean and dry.',
    'A fourth step that should not appear.',
  ],
  ...extra,
};

void main() {
  group('Evaluation (English)', () {
    test('an AI-camera entry becomes a predictable, template-based summary', () {
      expect(
        buildJournalEvaluation(_aiEntry(), tagalog: false, monitoredDays: 3),
        'Laceration recorded in this entry. '
        'Assessment noted: no visible bleeding; the wound appears superficial. '
        'No warning signs were flagged. '
        'Reported pain score: 2/10 (Mild). '
        'Assessed care level: Self Care. '
        'Advice given: Rinse the wound gently with clean water; '
        'Cover with a sterile non-stick dressing; Keep the area clean and dry. '
        'Monitored for 3 days.',
      );
    });

    test('the same input always gives the same text', () {
      final a = buildJournalEvaluation(_aiEntry(), tagalog: false);
      final b = buildJournalEvaluation(_aiEntry(), tagalog: false);
      expect(a, b);
    });

    test('it only states what the data supports (nothing invented)', () {
      final text = buildJournalEvaluation(_aiEntry(), tagalog: false)!;
      for (final word in ['margin', 'approximated', 'redness', 'drainage']) {
        expect(text.toLowerCase(), isNot(contains(word)));
      }
    });

    test('an older entry without pain / observations still summarizes', () {
      final text = buildJournalEvaluation({
        'classification': 'Burns',
      }, tagalog: false)!;
      expect(text, 'Burns recorded in this entry.');
    });

    test('a manual entry: classification and days monitored only', () {
      expect(
        buildJournalEvaluation(
          {
            'classification': 'Skin Issues',
            'severity': 'Minor',
            'remindMe': true,
          },
          tagalog: false,
          monitoredDays: 1,
        ),
        'Skin Issues recorded in this entry. Monitored for 1 day.',
      );
    });

    test('no classification -> no evaluation', () {
      expect(buildJournalEvaluation({}, tagalog: false), isNull);
      expect(
        buildJournalEvaluation({'classification': '  '}, tagalog: false),
        isNull,
      );
    });

    test(
      '"no warning signs" is only claimed when the entry has that field',
      () {
        final without = buildJournalEvaluation({
          'classification': 'Burn',
          'painScore': 3,
        }, tagalog: false)!;
        expect(without, isNot(contains('warning signs')));
      },
    );

    test('listed warning signs are shown (first three)', () {
      final text = buildJournalEvaluation(
        _aiEntry(
          extra: {
            'warningSigns': [
              'heavy bleeding.',
              'exposed bone',
              'fever',
              'extra',
            ],
          },
        ),
        tagalog: false,
      )!;
      expect(
        text,
        contains('Warning signs noted: heavy bleeding; exposed bone; fever.'),
      );
      expect(text, isNot(contains('extra')));
    });

    test('pain 7+ or urgent triage adds the consultation recommendation', () {
      final pain = buildJournalEvaluation(
        _aiEntry(extra: {'painScore': 8}),
        tagalog: false,
      )!;
      expect(pain, contains('Reported pain score: 8/10 (Severe).'));
      expect(pain, contains('Professional consultation was recommended.'));

      final triage = buildJournalEvaluation(
        _aiEntry(extra: {'triage': 'urgentCare', 'painScore': 2}),
        tagalog: false,
      )!;
      expect(triage, contains('Assessed care level: Urgent Care.'));
      expect(triage, contains('Professional consultation was recommended.'));

      final minor = buildJournalEvaluation(_aiEntry(), tagalog: false)!;
      expect(minor, isNot(contains('Professional consultation')));
    });

    test('a pain score outside 1-10 is ignored', () {
      final text = buildJournalEvaluation(
        _aiEntry(extra: {'painScore': 15}),
        tagalog: false,
      )!;
      expect(text, isNot(contains('pain score')));
    });

    test('the healing-milestone answer is included', () {
      final better = buildJournalEvaluation(
        _aiEntry(extra: {'milestoneResponded': true, 'feelingBetter': true}),
        tagalog: false,
      )!;
      expect(
        better,
        contains('At the expected healing time, you reported feeling better.'),
      );
      final worse = buildJournalEvaluation(
        _aiEntry(extra: {'milestoneResponded': true, 'feelingBetter': false}),
        tagalog: false,
      )!;
      expect(worse, contains('not feeling better'));
      expect(worse, contains('professional consultation is recommended'));
    });

    test('a First Aid Assistant entry uses its own warning-sign fields', () {
      final text = buildJournalEvaluation({
        'classification': 'Burn',
        'source': 'first_aid_assistant',
        'redFlags': ['Burns of this size need professional evaluation.'],
        'hasRedFlag': true,
        'firstAidSteps': ['Cool the burn under cool running water.'],
      }, tagalog: false)!;
      expect(text, contains('Warning signs noted: Burns of this size'));
      expect(text, contains('Professional consultation was recommended.'));
      expect(
        text,
        contains('Advice given: Cool the burn under cool running water.'),
      );
    });
  });

  group('Evaluation with the 0-5 pain scale', () {
    Map<String, dynamic> entry(int pain, {Map<String, dynamic>? extra}) =>
        _aiEntry(extra: {'painScore': pain, 'painScaleMax': 5, ...?extra});

    test('shows X/5 and the rating name', () {
      expect(
        buildJournalEvaluation(entry(2), tagalog: false)!,
        contains('Reported pain score: 2/5 (Minor).'),
      );
      expect(
        buildJournalEvaluation(entry(0), tagalog: false)!,
        contains('Reported pain score: 0/5 (No pain).'),
      );
      expect(
        buildJournalEvaluation(entry(5), tagalog: false)!,
        contains('Reported pain score: 5/5 (Worst pain).'),
      );
    });

    test('0 is a real score, not "missing"', () {
      expect(
        buildJournalEvaluation(entry(0), tagalog: false)!,
        contains('pain score'),
      );
    });

    test('4 and 5 add the consultation recommendation; 3 does not', () {
      expect(
        buildJournalEvaluation(entry(4), tagalog: false)!,
        contains('Professional consultation was recommended.'),
      );
      expect(
        buildJournalEvaluation(entry(5), tagalog: false)!,
        contains('Professional consultation was recommended.'),
      );
      expect(
        buildJournalEvaluation(entry(3), tagalog: false)!,
        isNot(contains('Professional consultation')),
      );
    });

    test('a score above 5 on the new scale is ignored', () {
      expect(
        buildJournalEvaluation(entry(7), tagalog: false)!,
        isNot(contains('pain score')),
      );
    });

    test('older entries (no painScaleMax) still read as X/10', () {
      final text = buildJournalEvaluation(
        _aiEntry(extra: {'painScore': 8}),
        tagalog: false,
      )!;
      expect(text, contains('Reported pain score: 8/10 (Severe).'));
      expect(text, contains('Professional consultation was recommended.'));
    });

    test('Tagalog uses the Tagalog rating name', () {
      expect(
        buildJournalEvaluation(entry(2), tagalog: true)!,
        contains('Iniulat na antas ng sakit: 2/5 (Maliit).'),
      );
    });
  });

  group('Evaluation with the injury type', () {
    test('Deep / Minor is stated, in both languages', () {
      final deep = {
        'classification': 'Injury (Wounds/laceration/Abrasion)',
        'severity': 'Deep',
      };
      expect(
        buildJournalEvaluation(deep, tagalog: false)!,
        'Injury (Wounds/laceration/Abrasion) recorded in this entry. '
        'Injury type: Deep.',
      );
      expect(
        buildJournalEvaluation({...deep, 'severity': 'Minor'}, tagalog: true)!,
        contains('Uri ng pinsala: Maliit.'),
      );
    });

    test('no type is claimed when none was chosen', () {
      expect(
        buildJournalEvaluation({
          'classification': 'Burns',
          'severity': null,
        }, tagalog: false)!,
        isNot(contains('Injury type')),
      );
    });

    test('a full manual entry: category, type, pain', () {
      final text = buildJournalEvaluation({
        'classification': 'Injury (Wounds/laceration/Abrasion)',
        'severity': 'Minor',
        'painScore': 2,
        'painScaleMax': 5,
      }, tagalog: false)!;
      expect(
        text,
        'Injury (Wounds/laceration/Abrasion) recorded in this entry. '
        'Injury type: Minor. Reported pain score: 2/5 (Minor).',
      );
    });
  });

  group('Evaluation (Tagalog)', () {
    test('the same entry in Tagalog', () {
      expect(
        buildJournalEvaluation(_aiEntry(), tagalog: true, monitoredDays: 3),
        'Naitala sa entry na ito ang Laceration. '
        'Napansin sa pagsusuri: walang nakikitang pagdurugo; mukhang mababaw ang sugat. '
        'Walang babalang palatandaan na naitala. '
        'Iniulat na antas ng sakit: 2/10 (Banayad). '
        'Antas ng pangangalaga ayon sa pagsusuri: Pangangalaga sa Sarili. '
        'Mga payong ibinigay: Rinse the wound gently with clean water; '
        'Cover with a sterile non-stick dressing; Keep the area clean and dry. '
        'Binantayan sa loob ng 3 araw.',
      );
    });

    test('no English template wording leaks into the Tagalog text', () {
      final text = buildJournalEvaluation(
        _aiEntry(extra: {'painScore': 9, 'milestoneResponded': true}),
        tagalog: true,
        monitoredDays: 5,
      )!;
      for (final english in [
        'recorded in this entry',
        'Assessment noted',
        'Reported pain score',
        'Monitored for',
        'Professional consultation',
      ]) {
        expect(text, isNot(contains(english)));
      }
    });
  });

  group('Journal Overview (entry detail screen)', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> pump(
      WidgetTester tester,
      Map<String, dynamic> data, {
      AppLanguage language = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(
            home: EntryDetailScreen(
              entryId: 'e1',
              data: {
                'title': 'AI Camera Assessment',
                'description': 'Wound type: Laceration',
                'createdAt': Timestamp.now(),
                ...data,
              },
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the Evaluation for a saved entry', (tester) async {
      await pump(tester, _aiEntry());
      expect(find.text('Evaluation'), findsOneWidget);
      expect(
        find.textContaining('Laceration recorded in this entry.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Reported pain score: 2/10 (Mild).'),
        findsOneWidget,
      );
      expect(find.textContaining('not a medical diagnosis'), findsOneWidget);
    });

    testWidgets('shows the Evaluation in Tagalog', (tester) async {
      await pump(tester, _aiEntry(), language: AppLanguage.tl);
      expect(find.text('Ebalwasyon'), findsOneWidget);
      expect(find.text('Evaluation'), findsNothing);
      expect(
        find.textContaining('Naitala sa entry na ito ang Laceration.'),
        findsOneWidget,
      );
    });

    testWidgets('an older entry with no classification shows no Evaluation', (
      tester,
    ) async {
      await pump(tester, {'classification': null});
      expect(find.text('Evaluation'), findsNothing);
    });
  });
}
