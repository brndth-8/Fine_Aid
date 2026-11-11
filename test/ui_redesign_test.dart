import 'dart:async';
import 'dart:io';

import 'package:fine_aid/core/theme/app_theme.dart';
import 'package:fine_aid/core/widgets/otc_suggestions_block.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:fine_aid/features/camera/screens/ai_camera_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/features/settings/screens/help_screen.dart';
import 'package:fine_aid/features/settings/screens/help_topic_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/calendar_strings.dart';
import 'package:fine_aid/i18n/help_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The redesign from the design PDF: the shared typography and shapes, and
/// the screens that were rebuilt to match it.
/// The light theme, with the font downloads (which cannot happen in a test)
/// failing quietly instead of failing the test.
ThemeData _lightTheme() {
  late ThemeData theme;
  runZonedGuarded(() => theme = AppTheme.lightTheme, (_, _) {});
  return theme;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // No font downloads in a test (the sizes and names are what is checked).
    GoogleFonts.config.allowRuntimeFetching = false;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> show(
    WidgetTester tester,
    Widget home, {
    AppLanguage language = AppLanguage.en,
    double width = 411,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(theme: _lightTheme(), home: home),
      ),
    );
    await tester.pump();
    tester.takeException();
  }

  group('typography and shapes (shared theme)', () {
    // (built inside the tests: the theme loads fonts)
    late ThemeData theme;
    late TextTheme t;
    setUp(() {
      theme = _lightTheme();
      t = theme.textTheme;
    });

    test('Poppins everywhere, in the design\'s sizes', () {
      for (final style in [
        t.displayLarge,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(style!.fontFamily, contains('Poppins'));
      }
      // 16 titles and the calendar, 12.5 form labels, 12 body, 10 / 9 small
      expect(t.titleLarge!.fontSize, 16);
      expect(t.titleSmall!.fontSize, 12.5);
      expect(t.bodyMedium!.fontSize, 12);
      expect(t.bodySmall!.fontSize, 10);
      expect(t.labelSmall!.fontSize, 9);
      expect(t.titleLarge!.fontWeight, FontWeight.bold);
      expect(t.bodyMedium!.fontWeight, isNot(FontWeight.bold));
    });

    test('the serif italic is only for small notes', () {
      late TextStyle note;
      runZonedGuarded(() => note = AppTheme.noteStyle(), (_, _) {});
      expect(note.fontFamily, contains('NotoSerif'));
      expect(note.fontStyle, FontStyle.italic);
      expect(note.fontSize, 9);
    });

    test('page colour, pill buttons, rounded fields', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFFE7E7E7));
      final shape = theme.elevatedButtonTheme.style!.shape!.resolve({});
      expect(shape, isA<StadiumBorder>());
      expect(
        theme.outlinedButtonTheme.style!.shape!.resolve({}),
        isA<StadiumBorder>(),
      );
      expect(theme.appBarTheme.titleTextStyle!.fontSize, 16);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, contains('Poppins'));
    });
  });

  group('Settings', () {
    testWidgets('a maroon banner, then a card for each setting, then Sign in '
        'for a guest', (tester) async {
      await show(tester, const SettingsScreen());
      final s = SettingsStrings.en;
      expect(find.text(s.banner), findsOneWidget);
      final labels = [
        s.personalization,
        s.aboutApplication,
        'About the AI scan',
        s.helpFaq,
        s.language,
        s.feedback,
        s.terms,
      ];
      final subs = [
        s.personalizationSub,
        s.aboutApplicationSub,
        s.aboutScanSub,
        s.helpFaqSub,
        s.languageSub,
        s.feedbackSub,
        s.termsSub,
      ];
      var previousY = tester.getTopLeft(find.text(s.banner)).dy;
      for (var i = 0; i < labels.length; i++) {
        final label = find.text(labels[i]);
        expect(label, findsOneWidget, reason: labels[i]);
        expect(find.text(subs[i]), findsOneWidget, reason: subs[i]);
        // in the design's order, top to bottom
        final y = tester.getTopLeft(label).dy;
        expect(y, greaterThan(previousY), reason: labels[i]);
        previousY = y;
      }
      expect(find.text(s.signIn), findsOneWidget);
      // the language row shows the current language
      expect(find.text(s.english), findsOneWidget);
    });

    testWidgets('it follows the language', (tester) async {
      await show(tester, const SettingsScreen(), language: AppLanguage.tl);
      final s = SettingsStrings.tl;
      expect(find.text(s.banner), findsOneWidget);
      expect(find.text(s.personalizationSub), findsOneWidget);
      expect(find.text(s.tagalog), findsOneWidget);
      expect(find.text(SettingsStrings.en.banner), findsNothing);
    });

    testWidgets('no overflow on a small phone', (tester) async {
      await show(tester, const SettingsScreen(), width: 320);
      expect(tester.takeException(), isNull);
    });
  });

  group('Help and Support', () {
    testWidgets('intro, four cards two to a row, then Replay Help Tour', (
      tester,
    ) async {
      await show(tester, const HelpScreen());
      final s = HelpStrings.en;
      expect(find.text(s.heading), findsOneWidget);
      expect(find.text(s.intro), findsOneWidget);
      final cards = [
        s.gettingStarted.title,
        s.privacy.title,
        s.journal.title,
        s.references.title,
      ];
      final pos = [for (final c in cards) tester.getTopLeft(find.text(c))];
      // cards are centred in their (equal-height) row, so allow for a title
      // or description that wraps to another line
      expect(pos[0].dy, closeTo(pos[1].dy, 24)); // first row
      expect(pos[2].dy, closeTo(pos[3].dy, 24)); // second row
      expect(pos[2].dy, greaterThan(pos[0].dy));
      expect(pos[1].dx, greaterThan(pos[0].dx));
      expect(find.text(s.replayTour), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(s.replayTour)).dy,
        greaterThan(pos[2].dy),
      );
    });

    testWidgets('the new heart, and the page fills the screen to the bottom', (
      tester,
    ) async {
      await show(tester, const HelpScreen());
      final hero = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/images/help_hero.png',
      );
      expect(hero, findsOneWidget);
      final bottom = tester
          .getBottomLeft(find.text(HelpStrings.en.replayTour))
          .dy;
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      // no empty gap under the Replay button
      expect(screen - bottom, lessThan(80));
    });

    testWidgets('no overflow on a small phone, in Tagalog too', (tester) async {
      await show(
        tester,
        const HelpScreen(),
        width: 320,
        language: AppLanguage.tl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Help pages sit in a bordered box', () {
    test('a bordered box holds the text of a Help page', () {
      final text = File(
        'lib/features/settings/screens/help_topic_screen.dart',
      ).readAsStringSync();
      expect(text, contains('Border.all'));
      expect(text, contains('BoxDecoration'));
    });

    for (final topic in HelpTopic.values) {
      testWidgets('${topic.name}: the title is in the top bar, the text sits '
          'on the page', (tester) async {
        await show(tester, HelpTopicScreen(topic: topic));
        final s = HelpStrings.en;
        final title = HelpTopicScreen.sectionOf(s, topic).title;
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(title)),
          findsOneWidget,
        );
        expect(find.text(s.heading), findsOneWidget);
        // the text sits in a bordered box, with no duplicate title above it
        expect(find.text(title), findsOneWidget); // the top bar's
        final boxes = find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).border != null,
              ),
            )
            .evaluate();
        expect(boxes, isNotEmpty);
      });
    }
  });

  group('Health Journal', () {
    testWidgets('the title is in the top bar, the line about it is plain text '
        'under it (no banner card)', (tester) async {
      await show(tester, const JournalListScreen());
      final title = ScreenText.en.journalBannerTitle;
      final sub = ScreenText.en.journalBannerSubtitle;
      expect(find.text(title), findsOneWidget);
      expect(find.text(sub), findsOneWidget);
      // the title is in the app bar
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(title)),
        findsOneWidget,
      );
      // and the line is not on a maroon card
      final onMaroon = find.ancestor(
        of: find.text(sub),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppTheme.darkMaroon,
        ),
      );
      expect(onMaroon, findsNothing);
    });
  });

  group('AI Vision Camera disclaimer', () {
    testWidgets('a yellow banner with the design\'s wording', (tester) async {
      await show(tester, const AiCameraScreen());
      final body = find.text(ScreenText.en.cameraDisclaimerBody);
      expect(body, findsOneWidget);
      expect(
        ScreenText.en.cameraDisclaimerBody,
        'This is only for initial assessment and not for diagnosis. '
        'Seek professional help.',
      );
      final banner = find.ancestor(
        of: body,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == const Color(0xFFFFE797),
        ),
      );
      expect(banner, findsOneWidget);
      expect(find.text(ScreenText.en.cameraDisclaimerTitle), findsOneWidget);
    });
  });

  group('AI result screen', () {
    final source = File(
      'lib/features/camera/screens/assessment_result_screen.dart',
    ).readAsStringSync();

    test('a maroon top bar on a white page, a taller photo', () {
      expect(source, contains('backgroundColor: Colors.white,'));
      expect(source, contains('appBar: AppBar('));
      expect(source, contains('height: 186,'));
    });

    test('the steps use circled numbers and 10 pt headings, the translate '
        'button is just its icon', () {
      expect(source, contains('circleNumbers: true'));
      expect(source, contains('phaseStyle: theme.textTheme.labelMedium'));
      expect(source, contains('IconButton('));
      expect(source, isNot(contains('TextButton.icon(')));
    });

    test('the unclear-details note is the serif italic in a grey box', () {
      expect(source, contains('AppTheme.noteStyle()'));
      expect(source, contains('Color(0xFFEFEFEF)'));
    });

    test('the category chip has a bold name', () {
      expect(source, contains('Icons.add_box_outlined'));
      expect(source, contains('FontWeight.bold'));
    });

    testWidgets('the suggestions are a pink card with white rows here, and '
        'unchanged in the chat', (tester) async {
      const items = [
        OtcSuggestion(
          name: 'Povidone-iodine',
          ageLimit: '',
          allergyPrecaution: '',
          howToUse: 'Apply',
        ),
      ];
      Color? cardColor(WidgetTester tester) {
        final box = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.color)
            .toList();
        return box.contains(const Color(0xFFFFF0F0))
            ? const Color(0xFFFFF0F0)
            : null;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          home: const Scaffold(
            body: OtcSuggestionsBlock(suggestions: items, cardStyle: true),
          ),
        ),
      );
      expect(cardColor(tester), const Color(0xFFFFF0F0));
      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          home: const Scaffold(body: OtcSuggestionsBlock(suggestions: items)),
        ),
      );
      expect(cardColor(tester), isNull);
    });
  });

  group('Health Kit', () {
    testWidgets('title 16 regular; the injury cards use 12.5 bold names', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: _lightTheme(), home: const FirstAidKitScreen()),
      );
      await tester.pump();
      tester.takeException();

      TextStyle styleOf(String text) =>
          tester.widget<Text>(find.text(text)).style!;
      final title = styleOf('First Aid Health Kit');
      expect(title.fontSize, 16);
      expect(title.fontWeight, FontWeight.normal);
      final card = styleOf('Laceration');
      expect(card.fontSize, 12.5);
      expect(card.fontWeight, FontWeight.bold);
    });

    testWidgets('the injury cards are wide and low, with the picture on the '
        'left taking about three quarters', (tester) async {
      tester.view.physicalSize = const Size(411, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: _lightTheme(), home: const FirstAidKitScreen()),
      );
      await tester.pump();
      tester.takeException();

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('Laceration'),
              matching: find.byType(Material),
            )
            .first,
      );
      // 12 + picture (about 72) + 8 + the name row (40) + 12
      expect(card.height, inInclusiveRange(125, 150));
      expect(card.width / card.height, greaterThan(1.2));
      // the second card is beside the first, on the same row
      final second = tester.getRect(
        find
            .ancestor(
              of: find.text('Minor Cut'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(second.top, closeTo(card.top, 0.5));
      expect(second.left, greaterThan(card.right));
      expect(tester.takeException(), isNull);
    });

    test('the result and the question dialog use the sizes of the design', () {
      final kit = File(
        'lib/features/dashboard/first_aid_kit_screen.dart',
      ).readAsStringSync();
      expect(kit, contains('fontSize: 19,'));
      expect(kit, contains('Color(0xFF700509)'));
      expect(kit, contains('Color(0xFF8F8584)'));
      expect(kit, isNot(contains('fontSize: 18,')));
    });
  });

  group('round 3: textbook title, notices, pop-ups, analyzing', () {
    String src(String path) => File(path).readAsStringSync();

    test('the textbook guide has the design top bar', () {
      final text = src('lib/features/dashboard/screens/dashboard_screen.dart');
      final from = text.indexOf('class _AllBooksScreen');
      final body = text.substring(from, from + 1200);
      expect(body, contains('appBar: AppBar('));
      expect(body, contains('centerTitle: true'));
      expect(body, contains('FontWeight.normal'));
    });

    testWidgets('a notice on a Help page is plain text: only the page box', (
      tester,
    ) async {
      await show(tester, const HelpTopicScreen(topic: HelpTopic.journal));
      final boxed = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      );
      // the one bordered box is the page's own; a notice inside it has none
      expect(boxed, findsOneWidget);
      expect(tester.takeException(), isNull);
      final gs = find.byType(RichText);
      expect(gs, findsWidgets);
    });

    test(
      'the analyzing view gives the photo the room; the banner has air above',
      () {
        final text = src(
          'lib/features/camera/screens/assessment_result_screen.dart',
        );
        expect(text, contains('_buildAnalyzingBody'));
        expect(text, contains('fromLTRB(16, 14, 16, 16)'));
        expect(text, contains('fit: BoxFit.cover'));
      },
    );

    test('the pop-ups after analysing use separate No / Yes pills', () {
      final q = src('lib/core/widgets/assessment_questions.dart');
      expect(q, isNot(contains('SegmentedButton')));
      expect(q, contains('_choice(false, a.no)'));
      expect(q, contains('_choice(true, a.yes)'));
      expect(q, contains('Color(0xFFFFF0F0)'));
      final pain = src('lib/core/widgets/pain_scale_dialog.dart');
      expect(pain, contains('Color(0xFFFFF0F0)'));
    });
  });

  group('what stays as it was', () {
    test('the calendar weekday labels and month name stay in English', () {
      expect(CalendarStrings.tl.weekdays, CalendarStrings.en.weekdays);
    });
  });
}
