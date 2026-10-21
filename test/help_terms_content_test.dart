import 'package:fine_aid/features/auth/screens/terms_screen.dart';
import 'package:fine_aid/features/settings/screens/help_screen.dart';
import 'package:fine_aid/features/settings/screens/help_topic_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/help_document.dart';
import 'package:fine_aid/i18n/help_strings.dart';
import 'package:fine_aid/i18n/terms_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every string in a section, including nested groups and list items.
Iterable<String> _allText(List<HelpBlock> blocks) sync* {
  Iterable<String> items(List<HelpItem> list) sync* {
    for (final i in list) {
      if (i.label != null) yield i.label!;
      yield i.text;
      yield* items(i.children);
    }
  }

  for (final b in blocks) {
    switch (b) {
      case HelpHeading():
        yield b.text;
      case HelpParagraph():
        if (b.label != null) yield b.label!;
        yield b.text;
      case HelpCallout():
        yield b.text;
      case HelpList():
        yield* items(b.items);
      case HelpGroup():
        yield b.title;
        yield* _allText(b.blocks);
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AppLanguage language = AppLanguage.en,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
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

  group('Help content', () {
    test('the editing note and the known typos are gone', () {
      final all = [
        for (final s in HelpStrings.en.sections) ..._allText(s.blocks),
      ].join('\n');
      expect(all, isNot(contains('Make this better')));
      expect(all, isNot(contains('Signed)')));
      expect(all, isNot(contains('In Full app access')));
      expect(all, isNot(contains('highlighting.')));
      expect(all, contains('Online Mode (Registered & Signed In)'));
      expect(all, contains('cross-referenced'));
      expect(all, contains('human-in-the-loop'));
    });

    test('Tagalog mirrors the English block for block', () {
      for (final (en, tl) in [
        (HelpStrings.en.gettingStarted, HelpStrings.tl.gettingStarted),
        (HelpStrings.en.privacy, HelpStrings.tl.privacy),
        (HelpStrings.en.journal, HelpStrings.tl.journal),
        (HelpStrings.en.references, HelpStrings.tl.references),
      ]) {
        expect(_allText(tl.blocks).length, _allText(en.blocks).length);
      }
    });

    test('References has the four sources and the governance group', () {
      final groups = HelpStrings.en.references.blocks
          .whereType<HelpGroup>()
          .map((g) => g.title)
          .toList();
      expect(groups, [
        'World Health Organization (WHO)',
        'Philippine Red Cross (PRC)',
        'Monthly Index of Medical Specialties (MIMS) Philippines',
        'Department of Health (DOH - Philippines)',
        'Doctor-Reviewed Content & Clinical Governance',
      ]);
    });
  });

  group('Help pages', () {
    String firstBody(HelpSection s) =>
        s.blocks.whereType<HelpHeading>().first.text;

    testWidgets('the Help screen lists the four pages and keeps the rest', (
      tester,
    ) async {
      await _pump(tester, const HelpScreen());
      final s = HelpStrings.en;
      for (final section in s.sections) {
        expect(find.text(section.title), findsOneWidget);
        // Nothing expands in place; the text is on the page itself.
        expect(find.text(firstBody(section)), findsNothing);
      }
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.text(s.heading), findsOneWidget);
      expect(find.text(s.replayTour), findsOneWidget);
    });

    for (final topic in HelpTopic.values) {
      for (final lang in [AppLanguage.en, AppLanguage.tl]) {
        testWidgets('${topic.name} (${lang.name}): opens its own page, back '
            'returns', (tester) async {
          await _pump(tester, const HelpScreen(), language: lang);
          final s = lang == AppLanguage.en ? HelpStrings.en : HelpStrings.tl;
          final section = HelpTopicScreen.sectionOf(s, topic);

          await tester.tap(find.text(section.title));
          await tester.pumpAndSettle();
          expect(find.byType(HelpTopicScreen), findsOneWidget);
          expect(find.text(section.title), findsOneWidget);
          expect(find.text(firstBody(section)), findsOneWidget);
          expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);

          await tester.tap(find.byIcon(Icons.arrow_back_ios));
          await tester.pumpAndSettle();
          expect(find.byType(HelpTopicScreen), findsNothing);
          expect(find.text(s.heading), findsOneWidget);
        });

        testWidgets('${topic.name} (${lang.name}): fits a narrow phone', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            AppLanguageScope(
              language: lang,
              child: MaterialApp(home: HelpTopicScreen(topic: topic)),
            ),
          );
          await tester.pump();
          // Open every nested source (References), then scroll to the end.
          final s = lang == AppLanguage.en ? HelpStrings.en : HelpStrings.tl;
          final section = HelpTopicScreen.sectionOf(s, topic);
          for (final g in section.blocks.whereType<HelpGroup>()) {
            await tester.scrollUntilVisible(
              find.text(g.title),
              200,
              maxScrolls: 1000,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(find.text(g.title));
            await tester.pumpAndSettle();
          }
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -100000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('References: sources open as nested accordions, one at a '
        'time, with a turning chevron', (tester) async {
      await _pump(tester, const HelpTopicScreen(topic: HelpTopic.references));
      final groups = HelpStrings.en.references.blocks
          .whereType<HelpGroup>()
          .toList();
      final who = groups[0];
      final prc = groups[1];

      Future<void> open(String title) async {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          maxScrolls: 1000,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      // Collapsed sources show only their names.
      expect(find.textContaining('Founded on April 7, 1948'), findsNothing);
      expect(
        tester
            .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
            .every((r) => r.turns == 0),
        isTrue,
      );

      await open(who.title);
      expect(find.textContaining('Founded on April 7, 1948'), findsOneWidget);
      expect(
        tester
            .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
            .where((r) => r.turns == 0.5)
            .length,
        1,
      );

      await open(prc.title);
      expect(find.textContaining('Founded on April 7, 1948'), findsNothing);
      expect(find.textContaining('Republic Act No. 95'), findsOneWidget);
    });

    testWidgets('each Help row is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HelpScreen());
      final node = tester.getSemantics(
        find.bySemanticsLabel(HelpStrings.en.privacy.title).first,
      );
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('Terms and Conditions', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    test('follows the document: headings in order, fixes applied', () {
      final headers = TermsStrings.en.sections
          .where((s) => !s.subheader && s.header.isNotEmpty)
          .map((s) => s.header)
          .toList();
      expect(headers, [
        'MEDICAL DISCLAIMER & EMERGENCY SERVICES',
        'APP USAGE & ACCOUNT TERMS',
        'ACCEPTABLE USE POLICY',
        'ADVISORY AND VALIDATION BY HEALTHCARE PROFESSIONALS',
        'PRIVACY AND HEALTH DATA',
        'LIMITATION OF LIABILITY & DISCLAIMER OF WARRANTIES',
        'TERMINATION',
        'CHANGES TO THESE TERMS',
      ]);
      final text = TermsStrings.en.sections
          .map((s) => '${s.paragraph ?? ''} ${s.bullets.join(' ')}')
          .join('\n');
      expect(text, contains('governed by our Privacy Policy, which'));
      expect(text, isNot(contains('[')));
      expect(text, contains('without notice, if you violate these Terms'));
      // Both languages have the same sections.
      expect(TermsStrings.tl.sections.length, TermsStrings.en.sections.length);
    });

    testWidgets('the emergency disclaimer is a prominent boxed notice', (
      tester,
    ) async {
      await _pump(tester, const TermsScreen(readOnly: true));
      final warning = TermsStrings.en.sections.firstWhere(
        (s) => s.header == 'NOT FOR EMERGENCIES',
      );
      expect(find.text('NOT FOR EMERGENCIES'), findsOneWidget);
      final text = tester.widget<Text>(find.text(warning.paragraph!));
      expect(text.style?.fontWeight, FontWeight.bold);
    });
  });
}
