import 'package:fine_aid/features/website/landing_page.dart';
import 'package:fine_aid/features/website/site_config.dart';
import 'package:fine_aid/features/website/web_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const sizes = {
    'desktop': Size(1280, 800),
    'tablet': Size(900, 1024),
    'mobile': Size(375, 812),
    'small': Size(320, 640),
  };

  /// google_fonts can't download fonts in tests; ignore only that error.
  Future<void> pumpIgnoringFonts(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 1));
    final errors = <Object>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      if (!e.toString().contains('GoogleFonts')) errors.add(e!);
    }
    expect(errors, isEmpty);
  }

  for (final entry in sizes.entries) {
    testWidgets('landing page lays out without errors (${entry.key})', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpIgnoringFonts(tester, const MaterialApp(home: LandingPage()));

      // Scroll the whole page so every section builds, lays out and animates.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 40; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Dr. Deanne Asdala', findRichText: true),
        findsWidgets,
      );
      expect(find.textContaining('March 11, 2026'), findsOneWidget);
      expect(find.text('Main Menu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose timers
    });
  }

  testWidgets('desktop nav shows all three links', (tester) async {
    tester.view.physicalSize = sizes['desktop']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpIgnoringFonts(tester, const MaterialApp(home: LandingPage()));
    for (final label in ['About', 'Experts', 'Contact Us']) {
      // .last: the nav bar is painted above (after) the page content.
      final rect = tester.getRect(find.text(label).last);
      expect(rect.right, lessThanOrEqualTo(1280), reason: label);
      expect(rect.top, lessThan(84), reason: label);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nav link scrolls to its section and reveals it', (tester) async {
    tester.view.physicalSize = sizes['desktop']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpIgnoringFonts(tester, const MaterialApp(home: LandingPage()));
    await tester.tap(find.text('Experts').last);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final title = find.text('EXPERTS');
    expect(tester.getRect(title).top, inInclusiveRange(84, 200));
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: title, matching: find.byType(AnimatedOpacity)).first,
    );
    expect(opacity.opacity, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('footer email is a real mailto link and can be copied', (
    tester,
  ) async {
    tester.view.physicalSize = sizes['desktop']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    await pumpIgnoringFonts(tester, const MaterialApp(home: LandingPage()));
    expect(SiteConfig.email, 'admin.fineaid@gmail.com');

    final links = tester.widgetList<Link>(find.byType(Link)).toList();
    final mail = links.singleWhere((l) => l.uri?.scheme == 'mailto');
    expect(mail.uri!.path, 'admin.fineaid@gmail.com');
    expect(mail.uri!.queryParameters['subject'], 'Fine Aid Inquiry');
    expect(links.any((l) => l.uri?.scheme == 'tel'), isTrue);

    final copy = find.byTooltip('Copy email address');
    await tester.ensureVisible(copy);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(copy);
    await tester.pump();
    expect(copied, 'admin.fineaid@gmail.com');
    expect(find.text('Email address copied'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown paths show the 404 page, not the admin', (tester) async {
    tester.view.physicalSize = sizes['desktop']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final path in ['/admin', '/login', '/fa-portal', '/x/y']) {
      tester.platformDispatcher.defaultRouteNameTestValue = path;
      await pumpIgnoringFonts(tester, const FineAidWebsite());
      expect(find.byType(NotFoundPage), findsOneWidget, reason: path);
      await tester.pumpWidget(const SizedBox());
    }
    tester.platformDispatcher.clearDefaultRouteNameTestValue();
  });

  test('admin route matching', () {
    // ADMIN_PATH is empty unless passed via --dart-define.
    if (SiteConfig.adminPath.isEmpty) {
      expect(SiteConfig.isAdminRoute('/anything'), isFalse);
      expect(SiteConfig.isAdminRoute('/'), isFalse);
    } else {
      final p = SiteConfig.adminPath;
      expect(SiteConfig.isAdminRoute('/$p'), isTrue);
      expect(SiteConfig.isAdminRoute('/$p/'), isTrue);
      expect(SiteConfig.isAdminRoute('/$p?x=1'), isTrue);
      expect(SiteConfig.isAdminRoute('/${p}x'), isFalse);
      expect(SiteConfig.isAdminRoute('/admin'), isFalse);
    }
  });
}
