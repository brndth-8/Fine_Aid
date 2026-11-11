import 'package:fine_aid/core/widgets/custom_bottom_nav_bar.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  /// The dashboard on a small phone (360 wide) with the system font at
  /// [scale] times its normal size. (The test font is wider than a real one,
  /// so anything that fits here fits on a phone.)
  Future<void> openDashboard(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(360, 780);
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
  }

  Future<void> finish(WidgetTester tester) async {
    // Let the dashboard's own timers run out before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('360 px wide, text at ${scale}x: nothing overflows', (
      tester,
    ) async {
      await openDashboard(tester, scale);
      expect(tester.takeException(), isNull);

      // scroll the whole page: top bar, banner, books, calendar
      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // the navigation labels are all there
      for (final label in [
        'Health Journal',
        'AI Vision Camera',
        'Help and Support',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await finish(tester);
    });
  }

  testWidgets('the bottom bar grows with the text instead of cutting labels', (
    tester,
  ) async {
    await openDashboard(tester, 1.0);
    final normal = tester.getSize(find.byType(CustomBottomNavBar)).height;
    await finish(tester);

    await openDashboard(tester, 2.0);
    final large = tester.getSize(find.byType(CustomBottomNavBar)).height;
    expect(large, greaterThan(normal));

    // and every label sits inside the bar
    final bar = tester.getRect(find.byType(CustomBottomNavBar));
    for (final label in [
      'Health Journal',
      'AI Vision Camera',
      'Help and Support',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.5), reason: label);
      expect(rect.top, greaterThanOrEqualTo(bar.top), reason: label);
    }
    await finish(tester);
  });

  testWidgets('textbook titles are shown in full, never cut with "..."', (
    tester,
  ) async {
    await openDashboard(tester, 1.5);
    final titles = tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Card), matching: find.byType(Text)),
        )
        .toList();
    expect(titles, isNotEmpty);
    for (final t in titles) {
      expect(t.maxLines, isNull, reason: t.data);
      expect(t.overflow, isNot(TextOverflow.ellipsis), reason: t.data);
    }
    // each title ends inside its card
    final cards = find.byType(Card);
    final card = tester.getRect(cards.first);
    final title = tester.getRect(
      find.descendant(of: cards.first, matching: find.byType(Text)).last,
    );
    expect(title.bottom, lessThanOrEqualTo(card.bottom));
    await finish(tester);
  });

  testWidgets(
    'the page can scroll far enough to show the end of the calendar',
    (tester) async {
      await openDashboard(tester, 1.0);
      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(0, -3000));
      await tester.pumpAndSettle();
      // the legend under the calendar ("Today") is on screen, above the bar
      final legend = tester.getRect(find.text('Today'));
      final bar = tester.getRect(find.byType(CustomBottomNavBar));
      expect(legend.bottom, lessThanOrEqualTo(bar.top + 1));
      await finish(tester);
    },
  );
}
