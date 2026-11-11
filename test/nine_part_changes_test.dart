import 'dart:io';

import 'package:fine_aid/core/severe_case.dart';
import 'package:fine_aid/core/widgets/assessment_questions.dart';
import 'package:fine_aid/core/widgets/first_aid_step_list.dart';
import 'package:fine_aid/core/widgets/medication_picker.dart';
import 'package:fine_aid/data/first_aid_guides.dart';
import 'package:fine_aid/data/first_aid_step_images.dart';
import 'package:fine_aid/data/health_profile_summary.dart';
import 'package:fine_aid/data/healing_durations.dart';
import 'package:fine_aid/data/journal_evaluation.dart';
import 'package:fine_aid/data/medications.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/journal/screens/edit_entry_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_entry_menu.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/checklist_strings.dart';
import 'package:fine_aid/i18n/ai_scan_stats_strings.dart';
import 'package:fine_aid/i18n/first_aid_guides_tl.dart';
import 'package:fine_aid/i18n/notification_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:fine_aid/services/emergency_alert.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WoundAssessment _assessment({
  TriageLevel triage = TriageLevel.firstAid,
  String bleeding = 'none',
  String depth = 'superficial',
  bool isWound = true,
  String? error,
}) => WoundAssessment(
  isWound: isWound,
  confidence: 0.9,
  woundType: 'laceration',
  visibleBleeding: bleeding,
  apparentDepth: depth,
  foreignObjectVisible: false,
  infectionSignsVisible: false,
  triage: triage,
  redFlags: const [],
  firstAidSteps: const [],
  otcOptions: const [],
  needsProfessionalEvaluation: false,
  uncertainties: const [],
  error: error,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  // ------------------------------------------------------------------ 1
  group('1. severe cases are emergencies, not first aid', () {
    test('emergency triage, heavy bleeding or a deep wound is severe', () {
      expect(isSevereCase(_assessment(triage: TriageLevel.emergency)), isTrue);
      expect(isSevereCase(_assessment(bleeding: 'severe')), isTrue);
      expect(isSevereCase(_assessment(depth: 'deep')), isTrue);
    });

    test('ordinary results are not', () {
      expect(isSevereCase(_assessment()), isFalse);
      expect(
        isSevereCase(_assessment(triage: TriageLevel.urgentCare)),
        isFalse,
      );
      expect(isSevereCase(_assessment(bleeding: 'moderate')), isFalse);
    });

    test('no wound, or a failed scan, is never severe', () {
      expect(isSevereCase(_assessment(isWound: false, depth: 'deep')), isFalse);
      expect(isSevereCase(_assessment(depth: 'deep', error: 'x')), isFalse);
    });

    test('the alert vibration is long pulses that repeat', () {
      // [wait, buzz, wait, buzz, ...]: every buzz is a second or more
      final buzzes = [
        for (var i = 1; i < EmergencyAlert.pattern.length; i += 2)
          EmergencyAlert.pattern[i],
      ];
      expect(buzzes.length, greaterThanOrEqualTo(3));
      expect(buzzes.every((ms) => ms >= 1000), isTrue);
    });

    test('the alert never throws when there is no vibration plugin', () async {
      await EmergencyAlert.start();
      await EmergencyAlert.stop();
    });
  });

  // ------------------------------------------------------------------ 2
  group('2. first aid steps', () {
    test('the AI steps are split into phase, text, why and picture', () {
      final steps = phasedStepsFromAi([
        'Before: Wash your hands with soap and water — keeps germs out',
        'During: Apply a mild, fragrance-free moisturizer — soothes the skin',
        'After: Consult a doctor for formal evaluation if it is not better',
      ]);
      expect(steps[0].phase, GuidePhase.before);
      expect(steps[0].text, 'Wash your hands with soap and water');
      expect(steps[0].why, 'keeps germs out');
      expect(steps[1].phase, GuidePhase.during);
      expect(steps[1].imageKey, 'Apply_mild_fragrance_free_moisturizer_1');
      expect(steps[2].imageKey, 'consult_a_doctor_for_formal_evaluation_1');
      expect(steps[2].why, isNull);
    });

    test('the Tagalog words are shown but the English picks the phase', () {
      final steps = phasedStepsFromAi(
        ['During: Rinse the wound — washes out dirt'],
        shown: ['Habang: Banlawan ang sugat — natatanggal ang dumi'],
      );
      expect(steps.single.phase, GuidePhase.during);
      expect(steps.single.text, 'Banlawan ang sugat');
      expect(steps.single.why, 'natatanggal ang dumi');
    });

    test('each of the five new pictures goes with its step', () {
      expect(
        firstAidStepImageKey('Prepare clean warm water and a soft towel'),
        'prepare_clean_warm_water_and_a_soft_towel_1',
      );
      expect(
        firstAidStepImageKey(
          'Wash the affected area and remove surface debris',
        ),
        'wash_the_affected_are_and_remove_surface_debris_1',
      );
      expect(
        firstAidStepImageKey('Protect the face from direct sunlight'),
        'protect_the_face_from_direct_sunlight_1',
      );
      expect(
        firstAidStepImageKey('Consult a doctor for formal evaluation'),
        'consult_a_doctor_for_formal_evaluation_1',
      );
      expect(
        firstAidStepImageKey('Apply mild, fragrance-free moisturizer'),
        'Apply_mild_fragrance_free_moisturizer_1',
      );
      for (final key in [
        'prepare_clean_warm_water_and_a_soft_towel_1',
        'wash_the_affected_are_and_remove_surface_debris_1',
        'protect_the_face_from_direct_sunlight_1',
        'consult_a_doctor_for_formal_evaluation_1',
        'Apply_mild_fragrance_free_moisturizer_1',
      ]) {
        expect(
          File(firstAidStepImagePath(key)).existsSync(),
          isTrue,
          reason: key,
        );
      }
    });

    testWidgets('Before / During / After headings with bullets and no icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstAidStepList(
                steps: const [
                  PhasedStep(phase: GuidePhase.after, text: 'Watch it daily'),
                  PhasedStep(
                    phase: GuidePhase.before,
                    text: 'Wash your hands',
                    why: 'Keeps germs out',
                  ),
                  PhasedStep(phase: GuidePhase.during, text: 'Rinse the wound'),
                ],
                phaseLabel: (p) => p.name.toUpperCase(),
                whyLabel: 'Why:',
              ),
            ),
          ),
        ),
      );
      final order = ['BEFORE', 'DURING', 'AFTER'];
      final ys = [for (final h in order) tester.getTopLeft(find.text(h)).dy];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
      expect(find.text('•  '), findsNWidgets(3));
      expect(find.text('Why: Keeps germs out'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('numbered: 1, 2, 3 carries on across Before / During / After', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstAidStepList(
                steps: const [
                  PhasedStep(phase: GuidePhase.after, text: 'Watch it daily'),
                  PhasedStep(phase: GuidePhase.before, text: 'Wash your hands'),
                  PhasedStep(phase: GuidePhase.during, text: 'Rinse the wound'),
                  PhasedStep(phase: GuidePhase.during, text: 'Pat it dry'),
                ],
                phaseLabel: (p) => p.name.toUpperCase(),
                whyLabel: 'Why:',
                numbered: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('•  '), findsNothing);
      for (final n in ['1.  ', '2.  ', '3.  ', '4.  ']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      // Before has 1, During has 2 and 3, After has 4.
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Wash your hands') < y('Rinse the wound'), isTrue);
      expect(y('1.  ') < y('2.  ') && y('3.  ') < y('4.  '), isTrue);
    });

    test('the Health Kit guide is numbered 1. 2. 3.; the AI result numbers '
        'its steps in maroon circles', () {
      final kit = File(
        'lib/features/dashboard/first_aid_kit_screen.dart',
      ).readAsStringSync();
      expect(kit, contains('numbered: true'));
      expect(kit, isNot(contains('circleNumbers')));
      final result = File(
        'lib/features/camera/screens/assessment_result_screen.dart',
      ).readAsStringSync();
      expect(result, contains('numbered: true'));
      expect(result, contains('circleNumbers: true'));
    });

    testWidgets('circled numbers carry on across the phases', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstAidStepList(
                steps: const [
                  PhasedStep(phase: GuidePhase.before, text: 'Wash'),
                  PhasedStep(phase: GuidePhase.during, text: 'Rinse'),
                  PhasedStep(phase: GuidePhase.after, text: 'Watch'),
                ],
                phaseLabel: (p) => p.name,
                whyLabel: 'Why:',
                numbered: true,
                circleNumbers: true,
              ),
            ),
          ),
        ),
      );
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      // a circle, not the "1." text
      expect(find.text('1.  '), findsNothing);
      final circle = tester.widget<Container>(
        find
            .ancestor(of: find.text('1'), matching: find.byType(Container))
            .first,
      );
      expect((circle.decoration as BoxDecoration).shape, BoxShape.circle);
    });

    test(
      'lacerations, cuts and wounds offer hydrogen peroxide once, then rinse',
      () {
        for (final id in [
          'laceration',
          'minor_cut',
          'scratch',
          'abrasion',
          'puncture_wound',
        ]) {
          for (final guide in [firstAidGuides[id]!, firstAidGuidesTl[id]!]) {
            final step = guide.firstWhere(
              (s) => s.text.toLowerCase().contains('hydrogen peroxide'),
              orElse: () => throw TestFailure('no peroxide step in $id'),
            );
            expect(step.phase, GuidePhase.during, reason: id);
          }
          final en = firstAidGuides[id]!.firstWhere(
            (s) => s.text.contains('first cleaning only'),
          );
          expect(
            en.text,
            contains('rinse it off with clean water'),
            reason: id,
          );
          expect(en.text, contains('Do not use it again'), reason: id);
        }
        // a burn is not given it
        for (final s in firstAidGuides['burn']!) {
          expect(s.text.toLowerCase(), isNot(contains('hydrogen peroxide')));
        }
      },
    );

    test('rash: air-dry, no towel rubbing, uncovered', () {
      final text = firstAidGuides['rash']!.map((s) => s.text).join(' ');
      expect(text, contains('air-dry'));
      expect(text, contains('Do not rub it with a towel'));
      expect(text, contains('uncovered'));
    });

    test('supplies come with an alternative', () {
      final lac = firstAidGuides['laceration']!.firstWhere(
        (s) => s.phase == GuidePhase.before && s.text.contains('gauze'),
      );
      expect(lac.text, contains('or a clean cloth if you do not have gauze'));
      expect(lac.text, contains('adhesive bandage is fine'));
    });

    test('simple words: no "tepid" anywhere in the guides', () {
      for (final guides in [firstAidGuides, firstAidGuidesTl]) {
        for (final steps in guides.values) {
          for (final s in steps) {
            expect(
              '${s.text} ${s.why}'.toLowerCase(),
              isNot(contains('tepid')),
            );
          }
        }
      }
    });

    test('the Tagalog guides still match the English ones step for step', () {
      for (final id in firstAidGuides.keys) {
        final en = firstAidGuides[id]!;
        final tl = firstAidGuidesTl[id]!;
        expect(tl.length, en.length, reason: id);
        for (var i = 0; i < en.length; i++) {
          expect(tl[i].phase, en[i].phase, reason: '$id step $i');
        }
      }
    });
  });

  // ------------------------------------------------------------------ 3
  group('3. Health Kit category pictures', () {
    test(
      'every category has its picture file and the folder is registered',
      () {
        for (final name in [
          'Other_skin_issue',
          'Rash',
          'Swelling',
          'Bruise',
          'Burn',
          'Puncture_wound',
          'Abrasion',
          'Scratch',
          'Minor_cut',
          'Laceration',
        ]) {
          expect(
            File('assets/images/health_kit/$name.png').existsSync(),
            isTrue,
            reason: name,
          );
        }
        expect(
          File('pubspec.yaml').readAsStringSync(),
          contains('assets/images/health_kit/'),
        );
      },
    );
  });

  group('3. Health Kit shows the pictures, not icons', () {
    testWidgets('each injury card has its picture', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: FirstAidKitScreen()));
      await tester.pump();

      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName)
          .toSet();
      for (final name in [
        'Laceration',
        'Minor_cut',
        'Scratch',
        'Abrasion',
        'Puncture_wound',
        'Burn',
        'Bruise',
        'Swelling',
        'Rash',
        'Other_skin_issue',
      ]) {
        expect(assets, contains('assets/images/health_kit/$name.png'));
      }
      // the old category icons are gone
      expect(find.byIcon(Icons.cut_outlined), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_outlined), findsNothing);
    });
  });

  // ------------------------------------------------------------------ 4
  group('4. questions before the result', () {
    Future<AssessmentAnswers?> run(
      WidgetTester tester,
      Future<void> Function() script, {
      required bool skin,
      List<String> saved = const [],
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AssessmentAnswers? result;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await askAssessmentQuestions(
                    context,
                    skinIssue: skin,
                    savedMedications: saved,
                  );
                  done = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await script();
      expect(done, isTrue);
      return result;
    }

    Future<void> chooseRating(WidgetTester tester, int n) async {
      await tester.tap(find.text('$n').first);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    test('skin issues are told apart from wounds and other injuries', () {
      expect(isSkinIssueCategory('Rash'), isTrue);
      expect(isSkinIssueCategory('Other Skin Issue'), isTrue);
      for (final c in [
        'Laceration',
        'Minor Cut',
        'Scratch',
        'Burn',
        'Bruise',
      ]) {
        expect(isSkinIssueCategory(c), isFalse, reason: c);
      }
    });

    testWidgets('a wound: pain rating only, then medication', (tester) async {
      final answers = await run(tester, () async {
        // pain scale first; no yes/no question about pain or itch
        expect(find.text('Do you feel any pain?'), findsNothing);
        expect(find.text('How much pain are you feeling?'), findsOneWidget);
        await chooseRating(tester, 3);
        expect(find.text('Do you take any medication?'), findsOneWidget);
        // Continue is disabled until Yes/No is chosen
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Continue'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }, skin: false);
      expect(answers!.pain, 3);
      expect(answers.itch, isNull);
      expect(answers.medications, isEmpty);
    });

    testWidgets('a skin issue: pain? itch? then medication', (tester) async {
      final answers = await run(tester, () async {
        // an animal or insect? No: the pain and itch questions follow
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        expect(find.text('Do you feel any pain?'), findsOneWidget);
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();
        await chooseRating(tester, 2); // pain 2
        expect(find.text('Do you feel any itchiness?'), findsOneWidget);
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();
        expect(find.text('How itchy is it?'), findsOneWidget);
        expect(find.text('No itch'), findsOneWidget);
        await chooseRating(tester, 4); // itch 4
        await tester.tap(find.text('No'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }, skin: true);
      expect(answers!.pain, 2);
      expect(answers.itch, 4);
    });

    testWidgets('a skin issue with no pain and no itch asks neither rating', (
      tester,
    ) async {
      final answers = await run(tester, () async {
        await tester.tap(find.text('No')); // an animal or insect?
        await tester.pumpAndSettle();
        await tester.tap(find.text('No')); // pain?
        await tester.pumpAndSettle();
        expect(find.text('How much pain are you feeling?'), findsNothing);
        await tester.tap(find.text('No')); // itch?
        await tester.pumpAndSettle();
        expect(find.text('How itchy is it?'), findsNothing);
        await tester.tap(find.text('No')); // medication?
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }, skin: true);
      expect(answers!.pain, isNull);
      expect(answers.itch, isNull);
    });

    testWidgets('typing a medication searches the list', (tester) async {
      final answers = await run(tester, () async {
        await chooseRating(tester, 1);
        // nothing is in the profile, so the question is asked: Yes, then
        // type to search
        await tester.tap(find.text('Yes'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'parac');
        await tester.pump();
        await tester.tap(find.text('Paracetamol'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }, skin: false);
      expect(answers!.medications, ['Paracetamol']);
    });

    testWidgets(
      'the "You indicated that..." summary lists conditions and medication',
      (tester) async {
        late List<String> lines;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                lines = acknowledgementLines(
                  context,
                  profile: {
                    'diabetes': true,
                    'diabetesType': 'type1',
                    'hemophiliaOrBloodDisorders': true,
                    'bloodDisorderType': 'hemophiliaA',
                  },
                  medications: ['Insulin', 'Warfarin'],
                );
                return const SizedBox();
              },
            ),
          ),
        );
        expect(lines, [
          'You indicated that you have Type 1 Diabetes and Hemophilia A.',
          'You are taking Insulin and Warfarin.',
        ]);
      },
    );

    test('nothing to acknowledge gives no lines', () {
      expect(profileConditionLabels(null, ChecklistStrings.en), isEmpty);
      expect(
        profileConditionLabels({'noneOfTheAbove': true}, ChecklistStrings.en),
        isEmpty,
      );
      expect(profileMedications(null), isEmpty);
    });
  });

  // ------------------------------------------------------------------ 5
  group('5. health checklist', () {
    test(
      'medication search: starts-with first, excludes chosen, empty is empty',
      () {
        expect(searchMedications(''), isEmpty);
        final r = searchMedications('a');
        expect(r.first.toLowerCase().startsWith('a'), isTrue);
        expect(searchMedications('PARAC'), ['Paracetamol']);
        expect(
          searchMedications('paracetamol', exclude: ['paracetamol']),
          isEmpty,
        );
        expect(isKnownMedication(' insulin '), isTrue);
        expect(isKnownMedication('my herbal tea'), isFalse);
      },
    );

    test('adding a medication trims, de-duplicates and ignores blanks', () {
      var list = <String>[];
      list = withMedication(list, '  Losartan   ');
      list = withMedication(list, 'losartan');
      list = withMedication(list, '   ');
      list = withMedication(list, 'Herbal  tea');
      expect(list, ['Losartan', 'Herbal tea']);
    });

    test('profile summary names the saved conditions', () {
      final s = ChecklistStrings.en;
      expect(
        profileConditionLabels({
          'diabetes': true,
          'diabetesType': 'gestational',
          'allergyTypes': ['food', 'latex'],
          'otherCondition': 'Asthma',
        }, s),
        ['Gestational Diabetes', 'Food Allergies', 'Latex Allergies', 'Asthma'],
      );
      expect(joinWithAnd(['A', 'B', 'C'], 'and'), 'A, B and C');
    });

    Future<void> pumpChecklist(WidgetTester tester, AppLanguage lang) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: lang,
          child: const MaterialApp(home: HealthChecklistScreen()),
        ),
      );
      await tester.pump();
    }

    for (final entry in {
      AppLanguage.en: ChecklistStrings.en,
      AppLanguage.tl: ChecklistStrings.tl,
    }.entries) {
      final s = entry.value;
      testWidgets('${entry.key.name}: Hemophilia A under blood disorders, '
          'an Other box, and a medication section', (tester) async {
        await pumpChecklist(tester, entry.key);
        expect(find.text(s.hemophiliaA), findsNothing);

        // the card opens (chevron) to its types
        await tester.tap(find.text(s.hemophilia));
        await tester.pumpAndSettle();
        expect(find.text(s.hemophiliaA), findsOneWidget);
        expect(find.text(s.bloodDisorderOther), findsOneWidget);

        // the "specify your condition" box is always there
        expect(find.text(s.specifyCondition), findsOneWidget);
        expect(find.text(s.specifyConditionHint), findsOneWidget);
      });
    }

    testWidgets(
      'Continue waits for what "Other" needs, and the medication picker works',
      (tester) async {
        await pumpChecklist(tester, AppLanguage.en);
        final s = ChecklistStrings.en;

        ElevatedButton continueButton() => tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, s.continueButton),
        );
        expect(continueButton().onPressed, isNull);

        expect(continueButton().onPressed, isNull); // nothing typed yet
        await tester.enterText(find.byType(TextField).first, 'Asthma');
        await tester.pump();
        expect(continueButton().onPressed, isNotNull);

        // medications: type, pick from the list, shows as a chip
        await tester.enterText(find.byType(TextField).last, 'war');
        await tester.pump();
        await tester.tap(find.text('Warfarin'));
        await tester.pump();
        expect(find.widgetWithText(InputChip, 'Warfarin'), findsOneWidget);
      },
    );
  });

  // ------------------------------------------------------------------ 6
  group('6. check-in, satisfaction and wound-care reminder', () {
    test('the check-in asks "How are you feeling?" with three answers', () {
      final en = NotificationStrings.en;
      expect(en.checkInBody, 'How are you feeling?');
      expect(en.actionBetter, 'Feeling better');
      expect(en.actionNotYet, 'No change');
      expect(en.actionWorse, 'Getting worse');
      expect(en.dialogBetter, 'Feeling better');
      expect(en.dialogNotYet, 'No change');
      expect(en.dialogWorse, 'Getting worse');
    });

    test('the check-in no longer opens an evaluation', () {
      final service = File(
        'lib/services/firebase/notification_service.dart',
      ).readAsStringSync();
      final detail = File(
        'lib/features/journal/screens/entry_detail_screen.dart',
      ).readAsStringSync();
      final inbox = File(
        'lib/features/dashboard/screens/notifications_screen.dart',
      ).readAsStringSync();
      for (final source in [service, detail, inbox]) {
        expect(source, isNot(contains('showSatisfactionDialog')));
        expect(source, isNot(contains('recordResultSatisfaction')));
        expect(source, isNot(contains('satisfactionAsked')));
      }
    });

    test('the wound-care reminder wording', () {
      expect(
        NotificationStrings.en.woundCareBody,
        "It's time to clean your wound.",
      );
      expect(NotificationStrings.tl.woundCareBody, isNotEmpty);
    });

    test('only open wounds and burns get the wound-care reminder', () {
      expect(
        woundCareCategories,
        containsAll([
          WoundCategories.laceration,
          WoundCategories.minorCut,
          WoundCategories.scratch,
          WoundCategories.abrasion,
          WoundCategories.punctureWound,
          WoundCategories.burn,
        ]),
      );
      for (final c in [
        WoundCategories.bruise,
        WoundCategories.swelling,
        WoundCategories.rash,
      ]) {
        expect(woundCareCategories.contains(c), isFalse, reason: c);
      }
    });

    test('the old "was the first aid effective" question is gone', () {
      final s = NotificationStrings.en;
      expect(s.checkInBody.toLowerCase(), isNot(contains('effective')));
      expect(
        AiScanStatsStrings.en.feedbackQuestion,
        'Are you satisfied with the result?',
      );
    });

    test('the saved satisfaction answer shows in the Evaluation', () {
      String? text(bool? answer) => buildJournalEvaluation({
        'classification': 'Laceration',
        'milestoneResponded': true,
        'feelingBetter': true,
        'resultSatisfied': ?answer,
      }, tagalog: false);
      expect(text(true), contains('satisfied with the result'));
      expect(text(false), contains('not satisfied with the result'));
      expect(text(null), isNot(contains('satisfied')));
    });
  });

  // ------------------------------------------------------------------ 7
  group('7. journal entry menu and edit', () {
    final data = <String, dynamic>{
      'title': 'My cut',
      'description': 'On my finger',
      'imageUrls': <String>[],
    };

    testWidgets('a three-dot menu offers Edit and Delete', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalEntryMenu(entryId: 'e1', data: data),
          ),
        ),
      );
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Edit opens the entry with its content, and can add photos', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalEntryMenu(entryId: 'e1', data: data),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(EditEntryScreen), findsOneWidget);
      expect(find.text('My cut'), findsOneWidget);
      expect(find.text('On my finger'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      // adding a photo offers the camera and the gallery
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Upload image'), findsOneWidget);
    });

    testWidgets('a blank title is not saved', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditEntryScreen(entryId: 'e1', data: data),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.text('Please enter a title.'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------ 8
  group('8. Help: the pain scale is 0 to 5', () {
    test('Step 2 says 0 to 5 in English and Tagalog, with no 10', () {
      final en = File('lib/i18n/help_content_en.dart').readAsStringSync();
      final tl = File('lib/i18n/help_content_tl.dart').readAsStringSync();
      expect(en, contains('Pain Rating Scale (0 to 5)'));
      expect(tl, contains('Pain Rating Scale (0 hanggang 5)'));
      for (final text in [en, tl]) {
        expect(text, isNot(contains('8–10')));
        expect(text, isNot(contains('5–7')));
      }
    });
  });
}
