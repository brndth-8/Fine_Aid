import 'dart:io';

import 'package:fine_aid/data/first_aid_guides.dart';
import 'package:fine_aid/data/journal_evaluation.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/first_aid_guides_tl.dart';
import 'package:fine_aid/i18n/health_kit_content_tl.dart';
import 'package:fine_aid/i18n/health_kit_ui_strings.dart';
import 'package:fine_aid/i18n/health_kit_locale.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _all(Iterable<GuideStep> steps) =>
    steps.map((s) => '${s.text} ${s.why}').join(' ').toLowerCase();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('5A OTC names are generic only', () {
    test('no brand names remain in the app source', () {
      final brands = RegExp(
        r'betadine|biogesic|bactroban|neosporin|tylenol|advil|medicol|'
        r'band-aid|vaseline',
        caseSensitive: false,
      );
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (brands.hasMatch(text)) offenders.add(entity.path);
      }
      expect(offenders, isEmpty);
    });

    test('the AI prompt asks for generic names and no "(Brand)" format', () {
      final source = File(
        'lib/services/api/gemini_service.dart',
      ).readAsStringSync();
      expect(source, contains('GENERIC NAMES ONLY'));
      expect(source, isNot(contains('Brand example')));
      expect(source, contains('Povidone-iodine'));
    });
  });

  group('5B first-aid guides', () {
    final ids = healthKitContentTl.keys.toList();

    test('every Health Kit category has an English and a Tagalog guide', () {
      expect(ids, hasLength(10));
      for (final id in ids) {
        expect(firstAidGuides[id], isNotNull, reason: 'EN $id');
        expect(firstAidGuidesTl[id], isNotNull, reason: 'TL $id');
      }
      expect(firstAidGuides.keys.toSet(), ids.toSet());
      expect(firstAidGuidesTl.keys.toSet(), ids.toSet());
    });

    test('each guide has Before, During and After steps, each with a why', () {
      for (final entry in firstAidGuides.entries) {
        final phases = entry.value.map((s) => s.phase).toSet();
        expect(phases, GuidePhase.values.toSet(), reason: entry.key);
        for (final step in entry.value) {
          expect(step.text.trim(), isNotEmpty, reason: entry.key);
          expect(step.why.trim(), isNotEmpty, reason: '${entry.key} why');
        }
        // phases appear in order: all Before, then During, then After
        final order = entry.value.map((s) => s.phase.index).toList();
        expect(order, [...order]..sort(), reason: '${entry.key} order');
      }
    });

    test('the Tagalog guide matches the English one step for step', () {
      for (final id in ids) {
        final en = firstAidGuides[id]!;
        final tl = firstAidGuidesTl[id]!;
        expect(tl.length, en.length, reason: id);
        for (var i = 0; i < en.length; i++) {
          expect(tl[i].phase, en[i].phase, reason: '$id #$i phase');
          expect(tl[i].text, isNot(en[i].text), reason: '$id #$i text');
          expect(tl[i].why, isNot(en[i].why), reason: '$id #$i why');
        }
      }
    });

    test('contraindications are stated where they apply', () {
      final burn = _all(firstAidGuides['burn']!);
      expect(burn, contains('ice directly'));
      expect(burn, contains('butter'));
      expect(burn, contains('blisters'));

      for (final id in ['laceration', 'abrasion']) {
        final text = _all(firstAidGuides[id]!);
        expect(text, contains('hydrogen peroxide'), reason: id);
        expect(text, contains('petroleum jelly'), reason: id);
        expect(text, contains('moist'), reason: id);
      }
      for (final id in ['bruise', 'swelling']) {
        expect(_all(firstAidGuides[id]!), contains('not directly on skin'));
      }
    });

    test('materials are named: gloves, running water, non-stick dressing', () {
      expect(_all(firstAidGuides['laceration']!), contains('gloves'));
      expect(_all(firstAidGuides['laceration']!), contains('running water'));
      expect(
        _all(firstAidGuides['abrasion']!),
        contains('sterile non-stick dressing'),
      );
    });

    test('every original step is still there', () {
      expect(_all(firstAidGuides['abrasion']!), contains('rinse the scrape'));
      expect(_all(firstAidGuides['burn']!), contains('10-20 minutes'));
      expect(
        _all(firstAidGuides['puncture_wound']!),
        contains('to clean it out'),
      );
    });

    test('a saved step reads "Phase: step — why"', () {
      final step = firstAidGuides['burn']![2];
      expect(
        guideStepToJournalText(step),
        'During: ${step.text} — ${step.why}',
      );
    });

    test('the phase headings and "why" label are translated', () {
      for (final key in [
        'phase_before',
        'phase_during',
        'phase_after',
        'whyLabel',
      ]) {
        expect(
          HealthKitStrings.of(key, HealthKitLocale.tl),
          isNot(HealthKitStrings.of(key, HealthKitLocale.en)),
          reason: key,
        );
      }
    });
  });

  group('journal Evaluation quotes just the action of a saved step', () {
    test('phase labels and the why are left out; During steps come first', () {
      final text = buildJournalEvaluation({
        'classification': 'Burn',
        'firstAidSteps': [
          'Before: Wash your hands with soap and water. — Keeps germs away.',
          'During: Cool the burn under cool running water. — Stops it going deeper.',
          'During: Do not apply ice directly to the burn. — Ice can damage skin.',
          'After: Change the dressing when wet. — Wet dressings grow germs.',
        ],
      }, tagalog: false)!;
      expect(
        text,
        contains(
          'Advice given: Cool the burn under cool running water; '
          'Do not apply ice directly to the burn.',
        ),
      );
      expect(text, isNot(contains('Keeps germs')));
      expect(text, isNot(contains('Before:')));
    });

    test('with no During step it falls back to the first steps', () {
      final text = buildJournalEvaluation({
        'classification': 'Rash',
        'firstAidSteps': ['Before: Wash your hands. — Germs.'],
      }, tagalog: false)!;
      expect(text, contains('Advice given: Wash your hands.'));
    });
  });

  group('Health Kit screen shows the guide', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> openResult(WidgetTester tester, AppLanguage language) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: const MaterialApp(home: FirstAidKitScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Burn').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump(const Duration(milliseconds: 400));
      // answer "No" to every question
      for (var i = 0; i < 5; i++) {
        final no = find.text('No');
        if (no.evaluate().isEmpty) break;
        await tester.tap(no.last);
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    testWidgets('Before / During / After with a why under each step', (
      tester,
    ) async {
      await openResult(tester, AppLanguage.en);
      expect(find.text('Before: Get Ready'), findsOneWidget);
      expect(find.text('During: The Steps'), findsOneWidget);
      expect(find.text('After: Aftercare'), findsOneWidget);
      expect(
        find.text('Do not apply ice directly to the burn.'),
        findsOneWidget,
      );
      expect(
        find.text('Why: Ice can damage the skin even more.'),
        findsOneWidget,
      );
    });
  });
}
