import 'package:fine_aid/features/admin/screens/widgets/admin_sidebar_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The admin must fit any screen. On a tall monitor the sidebar used to shrink
/// to its menu and float in the middle of the window; it must instead run the
/// full height, with the admin tile at the bottom.
void main() {
  Widget shell({required double navHeight}) => MaterialApp(
    home: Scaffold(
      body: AdminWideShell(
        sidebar: AdminSidebarFrame(
          color: Colors.red,
          header: const SizedBox(key: Key('header'), height: 80),
          nav: SizedBox(key: const Key('nav'), height: navHeight),
          footer: const SizedBox(key: Key('footer'), height: 60),
        ),
        content: const ColoredBox(key: Key('content'), color: Colors.white),
      ),
    ),
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final size in [
    const Size(1920, 1080), // a big monitor
    const Size(2560, 1440), // bigger still
    const Size(1366, 768), // a laptop
    const Size(1024, 700),
  ]) {
    testWidgets(
      'the sidebar fills the height at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(shell(navHeight: 400));
        expect(tester.takeException(), isNull);
        final sidebar = tester.getRect(find.byType(AdminSidebarFrame));
        expect(sidebar.top, 0);
        expect(sidebar.bottom, size.height, reason: 'no gap above or below');
        expect(sidebar.width, 240);
        // Logo at the very top, the admin tile at the very bottom.
        expect(tester.getRect(find.byKey(const Key('header'))).top, 0);
        expect(
          tester.getRect(find.byKey(const Key('footer'))).bottom,
          size.height,
        );
        // The page takes everything to the right, also the full height.
        final content = tester.getRect(find.byKey(const Key('content')));
        expect(content.left, 240);
        expect(content.right, size.width);
        expect(content.height, size.height);
      },
    );
  }

  testWidgets(
    'a short window scrolls the menu and keeps the logo and admin tile in view',
    (tester) async {
      setSize(tester, const Size(1366, 400));
      await tester.pumpWidget(shell(navHeight: 900));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('header'))).top, 0);
      expect(tester.getRect(find.byKey(const Key('footer'))).bottom, 400);
      // The menu is taller than the room left for it, so it scrolls.
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(AdminSidebarFrame),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll, isNotNull);
      await tester.drag(find.byKey(const Key('nav')), const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('footer'))).bottom, 400);
    },
  );

  testWidgets('in the phone drawer the frame fills the drawer', (tester) async {
    setSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: Drawer(
            width: 280,
            child: SafeArea(
              child: AdminSidebarFrame(
                width: double.infinity,
                header: const SizedBox(height: 80),
                nav: const SizedBox(key: Key('nav'), height: 300),
                footer: const SizedBox(key: Key('footer'), height: 60),
              ),
            ),
          ),
          body: const SizedBox(),
        ),
      ),
    );
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(const Key('footer'))).bottom, 800);
  });
}
