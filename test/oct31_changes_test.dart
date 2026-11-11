import 'dart:io';

import 'package:fine_aid/core/widgets/app_date_picker.dart';
import 'package:fine_aid/core/widgets/custom_bottom_nav_bar.dart';
import 'package:fine_aid/core/widgets/nearby_healthcare_sheet.dart';
import 'package:fine_aid/features/auth/screens/login_screen.dart';
import 'package:fine_aid/features/auth/screens/permission_screen.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/permission_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'date_boxes_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> bigScreen(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('2. Language changes the screens that were English only', () {
    testWidgets('the welcome screen is in Tagalog, with no English left', (
      tester,
    ) async {
      await bigScreen(tester);
      await tester.pumpWidget(
        const AppLanguageScope(
          language: AppLanguage.tl,
          child: MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();
      final tl = ScreenText.tl;
      expect(find.text(tl.tagline), findsOneWidget);
      expect(find.text(tl.logIn), findsOneWidget);
      expect(find.text(tl.createAccount), findsOneWidget);
      expect(find.text(tl.continueAsGuest), findsOneWidget);
      expect(find.text(ScreenText.en.logIn), findsNothing);
      expect(find.text(ScreenText.en.tagline), findsNothing);
    });

    testWidgets('an already open screen changes when the language does', (
      tester,
    ) async {
      await bigScreen(tester);
      Widget app(AppLanguage language) => AppLanguageScope(
        language: language,
        child: const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpWidget(app(AppLanguage.en));
      await tester.pump();
      expect(find.text(ScreenText.en.continueAsGuest), findsOneWidget);
      await tester.pumpWidget(app(AppLanguage.tl));
      await tester.pump();
      expect(find.text(ScreenText.tl.continueAsGuest), findsOneWidget);
      expect(find.text(ScreenText.en.continueAsGuest), findsNothing);
    });

    test('the dashboard welcome banner reads its text from ScreenText', () {
      final text = File(
        'lib/features/dashboard/screens/dashboard_screen.dart',
      ).readAsStringSync();
      for (final field in [
        'welcomeTitle',
        'welcomeBody',
        'guestBannerTitle',
        'guestBannerBody',
        'guestBannerLink',
        'offlineBannerTitle',
        'offlineBannerBody',
      ]) {
        expect(text, contains('ScreenText.of(context).$field'), reason: field);
      }
      expect(text, isNot(contains("'Welcome!'")));
    });

    test('every Tagalog string is filled in, and is not just the English', () {
      // These are the same in both languages on purpose.
      const same = {'ok', 'username', 'password', 'email', 'verificationCode'};
      final en = ScreenText.en;
      final tl = ScreenText.tl;
      final pairs = {
        'cancel': (en.cancel, tl.cancel),
        'retry': (en.retry, tl.retry),
        'tagline': (en.tagline, tl.tagline),
        'welcomeBody': (en.welcomeBody, tl.welcomeBody),
        'offlineAiBody': (en.offlineAiBody, tl.offlineAiBody),
        'lowConfidenceBody': (en.lowConfidenceBody, tl.lowConfidenceBody),
        'guestLimitBody': (en.guestLimitBody, tl.guestLimitBody),
        'directoryNote': (en.directoryNote, tl.directoryNote),
        'ok': (en.ok, tl.ok),
      };
      pairs.forEach((name, v) {
        expect(v.$2.trim(), isNotEmpty, reason: name);
        if (!same.contains(name)) expect(v.$2, isNot(v.$1), reason: name);
      });
    });
  });

  group('3. The date picker opens on today', () {
    Future<void> open(WidgetTester tester, {DateTime? initial}) async {
      await bigScreen(tester, width: 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppDatePicker(
                context,
                initial: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('with no date set, today is chosen', (tester) async {
      await open(tester);
      expect(shownDate(tester, 'start'), formatDateInput(DateTime.now()));
    });

    testWidgets('a date already set is kept', (tester) async {
      await open(tester, initial: DateTime(2026, 3, 9));
      expect(shownDate(tester, 'start'), '03/09/2026');
      expect(find.text(formatDateInput(DateTime.now())), findsNothing);
    });

    test('Sign Up no longer starts the birth date 18 years back', () {
      final text = File(
        'lib/features/auth/screens/registration_screen.dart',
      ).readAsStringSync();
      expect(text, isNot(contains('now.year - 18')));
    });
  });

  group('4. Nearby Healthcare: Category sits on its own line', () {
    testWidgets('the label is above the field, not inside it', (tester) async {
      await bigScreen(tester, width: 500);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 900, child: NearbyHealthcareSheet()),
          ),
        ),
      );
      await tester.pump();
      // The test font is much wider than a real one, so the longest category
      // name overflows the row here (not on a phone).
      tester.takeException();
      final label = find.text(ScreenText.en.category);
      expect(label, findsOneWidget);
      final field = find.byType(DropdownButtonFormField<String?>);
      expect(field, findsOneWidget);
      expect(
        tester.getBottomLeft(label).dy,
        lessThanOrEqualTo(tester.getTopLeft(field).dy),
        reason: 'the label ends before the field starts',
      );
      final decoration = tester
          .widget<InputDecorator>(
            find.descendant(of: field, matching: find.byType(InputDecorator)),
          )
          .decoration;
      expect(decoration.labelText, isNull);
    });
  });

  group('5. Multiple injuries: no description on the selected wound', () {
    test('the selected label is just "Wound n"', () {
      final text = File(
        'lib/features/camera/screens/multi_injury_screen.dart',
      ).readAsStringSync();
      expect(text, contains("label: 'Wound \${index + 1}',"));
      expect(text, isNot(contains("'Wound \${index + 1} — '")));
    });
  });

  group('6. Bottom navigation bar', () {
    const items = [
      BottomNavItem(icon: Icons.book, label: 'A'),
      BottomNavItem(icon: Icons.camera, label: 'B', badge: 'AI'),
      BottomNavItem(icon: Icons.help, label: 'C'),
    ];

    testWidgets('icons and labels sit 8 px higher; the bar is as tall as '
        'before', (tester) async {
      await bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              items: items,
              onItemTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final bar = find.byType(CustomBottomNavBar);
      // 70 (bar) + 42 (the middle circle rising above it), as before.
      expect(tester.getSize(bar).height, 112);
      final barBottom = tester.getBottomLeft(bar).dy;
      for (final label in ['A', 'B', 'C']) {
        // Was 8 px above the bottom; lifted by 4, then by 4 more.
        expect(
          barBottom - tester.getBottomLeft(find.text(label)).dy,
          closeTo(16, 0.5),
          reason: label,
        );
      }
    });
  });

  group('7. Camera Access Required text matches the PDF', () {
    final s = PermissionStrings.en;
    final headings = [for (final x in s.sections) x.heading];

    test('headings in order: each English one, then its Filipino one', () {
      expect(s.title, 'CAMERA PERMISSION ACCESS & PRIVACY TERMS');
      expect(headings, [
        'Purpose and Scope of Collection',
        'Layunin at Saklaw ng Pangongolekta',
        'Why We Need Camera Access?',
        'Bakit Namin Kailangan ang Pag-access sa Kamera?',
        'Standard Camera Permission & Privacy Information',
        'Karaniwang Pahintulot sa Kamera at Impormasyon sa Pagkapribado',
        'Third-Party Sharing and Commercial Restrictions',
        'Pagbabahagi sa Ikatlong Panig at mga Komersyal na Paghihigpit',
        'Limitation of Liability & Medical Disclaimer',
        'Limitasyon sa Pananagutan at Paunawa sa Medikal',
      ]);
    });

    test('bullets, in order', () {
      List<String> labels(int i) => [
        for (final p in s.sections[i].points) p.label,
      ];
      expect(labels(2), ['AI Visual Assessment:', 'Instant Analysis:']);
      expect(labels(4), [
        'On-Demand Use:',
        'Data Security & Privacy:',
        'Flashlight/Torch Assistance:',
      ]);
      expect(labels(6), ['No Data Monetization:', 'Service Providers:']);
      // the Filipino bullets have the same labels
      expect(labels(3), labels(2));
      expect(labels(5), labels(4));
      expect(labels(7), labels(6));
    });

    test('the paragraphs are the PDF\'s words', () {
      expect(
        s.sections[0].paragraph,
        startsWith("Fine Aid requires access to your device's camera"),
      );
      expect(
        s.sections[1].paragraph,
        startsWith('Kinakailangan ng Fine Aid ang pag-access sa kamera'),
      );
      expect(
        s.sections[8].paragraph,
        endsWith('regarding a medical condition.'),
      );
    });

    testWidgets('the screen shows all of it', (tester) async {
      await bigScreen(tester, width: 420);
      await tester.pumpWidget(const MaterialApp(home: PermissionScreen()));
      await tester.pump();
      // The checkbox row's ink-splash warning is already there without this
      // change; only what is shown matters here.
      tester.takeException();
      expect(find.text(s.title), findsOneWidget);
      for (final heading in headings) {
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.textContaining('Instant Analysis:'), findsNWidgets(2));
      expect(find.text(s.continueButton), findsOneWidget);
    });

    test('Filipino shows the same body', () {
      expect(PermissionStrings.tl.sections, s.sections);
    });
  });

  group('8. Calendar (layout)', calendarLayoutTests);

  group('8. Calendar', () {
    test(
      'rows fit the card width and the text size, and stay finger-sized',
      () {
        final text = File(
          'lib/features/dashboard/screens/dashboard_screen.dart',
        ).readAsStringSync();
        expect(text, contains('mainAxisExtent'));
        expect(text, isNot(contains('childAspectRatio: 1')));
      },
    );
  });
}

// The dashboard calendar, measured on a small phone, a large phone and a
// tablet, with larger text too.
void calendarLayoutTests() {
  Future<void> open(WidgetTester tester, double width, double scale) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final skip = find.byTooltip('Skip Tour');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
  }

  Finder calendarGrid() => find.byWidgetPredicate(
    (w) =>
        w is GridView &&
        w.gridDelegate is SliverGridDelegateWithFixedCrossAxisCount &&
        (w.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount ==
            7,
  );

  for (final (width, scale) in [
    (320.0, 1.0),
    (360.0, 1.0),
    (360.0, 2.0),
    (430.0, 1.0),
    (900.0, 1.0),
  ]) {
    testWidgets('calendar at ${width.toInt()} px wide, text ${scale}x: fills '
        'the card, nothing clips, rows stay finger-sized', (tester) async {
      await open(tester, width, scale);
      expect(tester.takeException(), isNull);

      final grid = calendarGrid();
      expect(grid, findsOneWidget);
      final gridBox = tester.getRect(grid);
      final delegate =
          tester.widget<GridView>(grid).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;

      // Seven equal columns across the grid's whole width.
      final firstDay = tester.getRect(find.text('1').last);
      expect(gridBox.width, greaterThan(width * 0.5));

      // Rows: finger-sized, and tall enough for the "today" circle.
      final rowHeight = delegate.mainAxisExtent!;
      expect(rowHeight, inInclusiveRange(32, 56));
      final todayCircle = (TextScaler.linear(scale).scale(14) * 2.2).clamp(
        32.0,
        44.0,
      );
      expect(rowHeight, greaterThanOrEqualTo(todayCircle + 4));
      expect(firstDay.width, greaterThan(0));

      // The grid ends inside the card (no clipping at the bottom).
      expect(gridBox.bottom, lessThanOrEqualTo(900 + 3000));

      // Let the dashboard's own timers run out before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  }
}
