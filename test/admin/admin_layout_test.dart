import 'package:fine_aid/features/admin/screens/widgets/admin_shared_widgets.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_sidebar_parts.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_user_info.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three window sizes the admin page must hold up at (logical pixels).
const phone = Size(360, 800);
const tablet = Size(768, 1024);
const desktop = Size(1366, 768);

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

const navLabels = [
  'Dashboard',
  'User Management',
  'Content Management',
  'Notifications',
  'Journal Log Review',
  'Feedback',
  'Reports & Analytics',
  'Audit Logs',
  'System Security',
];

Widget sidebarColumn({String selected = 'Dashboard', double width = 240}) {
  return Container(
    width: width,
    color: const Color(0xFF690000),
    child: SingleChildScrollView(
      child: Column(
        children: [
          const AdminNavSection('OVERVIEW', first: true),
          for (final l in navLabels.take(1))
            AdminNavItem(
              icon: Icons.dashboard_outlined,
              label: l,
              selected: selected == l,
              onTap: () {},
            ),
          const AdminNavSection('MANAGEMENT'),
          for (final l in navLabels.skip(1).take(3))
            AdminNavItem(
              icon: Icons.article_outlined,
              label: l,
              selected: selected == l,
              onTap: () {},
            ),
          const AdminNavSection('MONITORING'),
          for (final l in navLabels.skip(4).take(3))
            AdminNavItem(
              icon: Icons.book_outlined,
              label: l,
              selected: selected == l,
              onTap: () {},
            ),
          const AdminNavSection('SYSTEM'),
          for (final l in navLabels.skip(7))
            AdminNavItem(
              icon: Icons.security_outlined,
              label: l,
              selected: selected == l,
              onTap: () {},
            ),
          AdminNavFooter(onOpenAccount: () {}, onLogout: () {}),
        ],
      ),
    ),
  );
}

void main() {
  group('side navigation', () {
    for (final width in [240.0, 280.0]) {
      testWidgets('section labels start above the nav icons ($width wide)', (
        tester,
      ) async {
        setSize(tester, desktop);
        await tester.pumpWidget(
          app(
            Align(
              alignment: Alignment.topLeft,
              child: sidebarColumn(width: width),
            ),
          ),
        );
        final iconLeft = tester
            .getTopLeft(
              find.descendant(
                of: find.byType(AdminNavItem).first,
                matching: find.byType(Icon),
              ),
            )
            .dx;
        for (final heading in [
          'OVERVIEW',
          'MANAGEMENT',
          'MONITORING',
          'SYSTEM',
        ]) {
          expect(
            tester.getTopLeft(find.text(heading)).dx,
            iconLeft,
            reason: '$heading should line up with the icons',
          );
        }
        // Every item's text still lines up with the others.
        final textLeft = tester.getTopLeft(find.text('Dashboard')).dx;
        for (final label in navLabels) {
          expect(tester.getTopLeft(find.text(label)).dx, textLeft);
        }
      });

      testWidgets(
        'each label has a faint line under it, inset 16px ($width wide)',
        (tester) async {
          setSize(tester, desktop);
          await tester.pumpWidget(
            app(
              Align(
                alignment: Alignment.topLeft,
                child: sidebarColumn(width: width),
              ),
            ),
          );
          final sections = find.byType(AdminNavSection);
          expect(sections, findsNWidgets(4));
          for (final section in sections.evaluate()) {
            final line = find.descendant(
              of: find.byWidget(section.widget),
              matching: find.byType(DecoratedBox),
            );
            final rect = tester.getRect(line.first);
            expect(rect.left, 16);
            expect(rect.width, width - 32);
            final box = tester.widget<DecoratedBox>(line.first);
            final border = (box.decoration as BoxDecoration).border as Border;
            expect(border.bottom.width, 1);
            expect(border.bottom.color, Colors.white.withValues(alpha: 0.2));
            expect(border.top, BorderSide.none);
          }
        },
      );
    }

    testWidgets('label text is 11px, semibold, spaced and uppercase', (
      tester,
    ) async {
      setSize(tester, desktop);
      await tester.pumpWidget(
        app(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 240, child: AdminNavSection('Management')),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('MANAGEMENT'));
      expect(text.style?.fontSize, 11);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.letterSpacing, closeTo(0.88, 0.001));
      expect(text.style?.color, Colors.white.withValues(alpha: 0.6));
    });

    testWidgets('spacing: 16 above, 8 to the line, 6 to the first item', (
      tester,
    ) async {
      setSize(tester, desktop);
      await tester.pumpWidget(
        app(Align(alignment: Alignment.topLeft, child: sidebarColumn())),
      );
      Rect card(String label) => tester.getRect(
        find
            .descendant(
              of: find.widgetWithText(AdminNavItem, label),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      Rect headingBox(String label) => tester.getRect(
        find
            .descendant(
              of: find.widgetWithText(AdminNavSection, label),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      // Above MANAGEMENT: from the Dashboard card to the heading box.
      expect(headingBox('MANAGEMENT').top - card('Dashboard').bottom, 16);
      // Text to its line (the line is the 1px bottom border).
      final text = tester.getRect(find.text('MANAGEMENT'));
      expect(headingBox('MANAGEMENT').bottom - 1 - text.bottom, 8);
      // From the line to the first item card.
      expect(card('User Management').top - headingBox('MANAGEMENT').bottom, 6);
      // OVERVIEW sits flush at the top of its list (the list adds the 8px).
      expect(headingBox('OVERVIEW').top, 0);
    });

    testWidgets(
      'a selected item keeps its text on the same line as the others',
      (tester) async {
        setSize(tester, desktop);
        await tester.pumpWidget(
          app(
            Align(
              alignment: Alignment.topLeft,
              child: sidebarColumn(selected: 'Audit Logs'),
            ),
          ),
        );
        expect(
          tester.getTopLeft(find.text('Audit Logs')).dx,
          tester.getTopLeft(find.text('System Security')).dx,
        );
      },
    );

    testWidgets(
      'icons sit in one fixed column and every label is a single line',
      (tester) async {
        setSize(tester, desktop);
        await tester.pumpWidget(
          app(Align(alignment: Alignment.topLeft, child: sidebarColumn())),
        );
        final iconLefts = {
          for (final w in tester.widgetList<Icon>(
            find.descendant(
              of: find.byType(AdminNavItem),
              matching: find.byType(Icon),
            ),
          ))
            tester.getTopLeft(find.byWidget(w)).dx,
        };
        expect(
          iconLefts.length,
          1,
          reason: 'all nav icons start at the same x',
        );

        for (final label in navLabels) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 1, reason: label);
          expect(text.softWrap, isFalse, reason: label);
          // One line of text: no taller than ~1.5 lines of its own size.
          final size = tester.getSize(find.text(label));
          final fontSize = text.style?.fontSize ?? 14;
          expect(size.height, lessThan(fontSize * 2), reason: '$label wrapped');
        }
      },
    );

    testWidgets(
      'footer: icon, name/role and logout sit on one row, vertically centred',
      (tester) async {
        setSize(tester, desktop);
        await tester.pumpWidget(
          app(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: AdminNavFooter(onOpenAccount: () {}, onLogout: () {}),
              ),
            ),
          ),
        );
        final avatarY = tester.getCenter(find.byType(CircleAvatar)).dy;
        final logoutY = tester.getCenter(find.byIcon(Icons.logout)).dy;
        final textBlockY =
            (tester.getCenter(find.text('Admin')).dy +
                tester.getCenter(find.text('Administrator')).dy) /
            2;
        expect((avatarY - logoutY).abs(), lessThan(1.5));
        expect((avatarY - textBlockY).abs(), lessThan(1.5));
        // Name above role, both left of the logout icon.
        expect(
          tester.getTopLeft(find.text('Admin')).dy,
          lessThan(tester.getTopLeft(find.text('Administrator')).dy),
        );
        expect(
          tester.getCenter(find.text('Administrator')).dx,
          lessThan(tester.getCenter(find.byIcon(Icons.logout)).dx),
        );
      },
    );

    testWidgets('logout and the account tile are separate tap targets', (
      tester,
    ) async {
      setSize(tester, desktop);
      var opened = 0;
      var loggedOut = 0;
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: AdminNavFooter(
                onOpenAccount: () => opened++,
                onLogout: () => loggedOut++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.logout));
      await tester.tap(find.text('Administrator'));
      expect((opened, loggedOut), (1, 1));
    });
  });

  group('clickable summary card', () {
    testWidgets('opens on click', (tester) async {
      setSize(tester, desktop);
      var taps = 0;
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 300,
            height: 136,
            child: AdminStatCard(
              label: 'Registered users',
              value: '12',
              icon: Icons.people_outline,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Registered users'));
      expect(taps, 1);
    });

    testWidgets('is reachable by keyboard and activates with Enter and Space', (
      tester,
    ) async {
      setSize(tester, desktop);
      var taps = 0;
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 300,
            height: 136,
            child: AdminStatCard(
              label: 'Total AI scans',
              value: '40',
              icon: Icons.camera_alt_outlined,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // focus the card
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 2);
    });

    testWidgets('shows a hover state and a focus state', (tester) async {
      setSize(tester, desktop);
      await tester.pumpWidget(
        app(
          Center(
            child: SizedBox(
              width: 300,
              height: 136,
              child: AdminStatCard(
                label: 'Pending escalations',
                value: '1',
                icon: Icons.warning_amber_outlined,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      double borderWidth() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(AdminCardButton),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return ((box.decoration as BoxDecoration).border as Border).top.width;
      }

      expect(borderWidth(), 1, reason: 'idle');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AdminStatCard)));
      await tester.pump();
      expect(borderWidth(), 2, reason: 'hover');
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(borderWidth(), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(borderWidth(), 2, reason: 'keyboard focus');
    });

    testWidgets('a card with no onTap is not a button', (tester) async {
      setSize(tester, desktop);
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 300,
            height: 136,
            child: AdminStatCard(
              label: 'Plain',
              value: '1',
              icon: Icons.info_outline,
            ),
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    for (final size in [phone, tablet, desktop]) {
      testWidgets(
        'three cards are exactly the same size at ${size.width.toInt()} wide',
        (tester) async {
          setSize(tester, size);
          // The same arrangement the dashboard uses.
          final cards = [
            for (final (label, change) in [
              ('Registered users', '+3 this month'),
              ('Total AI scans', null),
              ('Pending escalations', 'Needs attention'),
            ])
              AdminStatCard(
                label: label,
                value: '12',
                change: change,
                icon: Icons.info_outline,
                onTap: () {},
              ),
          ];
          await tester.pumpWidget(
            app(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 720;
                    return stacked
                        ? Column(
                            children: [
                              for (final card in cards) ...[
                                SizedBox(
                                  height: 136,
                                  width: double.infinity,
                                  child: card,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          )
                        : SizedBox(
                            height: 136,
                            child: Row(
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 16),
                                  Expanded(child: cards[i]),
                                ],
                              ],
                            ),
                          );
                  },
                ),
              ),
            ),
          );
          final sizes = [
            for (final card in find.byType(AdminStatCard).evaluate())
              tester.getSize(find.byWidget(card.widget)),
          ];
          expect(sizes.length, 3);
          expect(sizes.toSet().length, 1, reason: 'sizes differ: $sizes');
        },
      );
    }
  });

  group('responsive building blocks', () {
    for (final size in [phone, tablet, desktop]) {
      testWidgets('header with an action fits at ${size.width.toInt()} wide', (
        tester,
      ) async {
        setSize(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AdminHeader(
                    title: 'User management',
                    subtitle:
                        'View, modify, or deactivate user accounts as needed for security or policy compliance.',
                    action: ElevatedButton(
                      onPressed: () {},
                      child: const Text('An action'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('An action'), findsOneWidget);
      });

      testWidgets(
        'a wide table scrolls instead of overflowing at ${size.width.toInt()} wide',
        (tester) async {
          setSize(tester, size);
          await tester.pumpWidget(
            app(
              SingleChildScrollView(
                child: AdminHScroll(
                  minWidth: 760,
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Expanded(child: Text('Column $i')),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          if (size.width < 760) {
            expect(find.byType(SingleChildScrollView), findsNWidgets(2));
          }
        },
      );

      testWidgets('side-by-side panels stack on a narrow window ($size)', (
        tester,
      ) async {
        setSize(tester, size);
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              child: AdminResponsiveRow(
                breakpoint: 900,
                children: const [
                  Expanded(flex: 3, child: SizedBox(height: 50, key: Key('a'))),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: SizedBox(height: 50, key: Key('b'))),
                ],
              ),
            ),
          ),
        );
        final a = tester.getTopLeft(find.byKey(const Key('a')));
        final b = tester.getTopLeft(find.byKey(const Key('b')));
        if (size.width < 900) {
          expect(b.dy, greaterThan(a.dy), reason: 'stacked');
          expect(
            tester.getSize(find.byKey(const Key('a'))).width,
            tester.getSize(find.byKey(const Key('b'))).width,
          );
        } else {
          expect(b.dy, a.dy, reason: 'side by side');
        }
      });
    }
  });

  group('analytics cards', () {
    for (final size in [phone, tablet, desktop]) {
      testWidgets('all four are the same size at ${size.width.toInt()} wide', (
        tester,
      ) async {
        setSize(tester, size);
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AdminResponsiveRow(
                breakpoint: 880,
                children: const [
                  Expanded(
                    child: AdminAnalyticsCard(
                      label: 'Total users',
                      value: '32',
                      change: '↑ +20 this month',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    // No note under the number.
                    child: AdminAnalyticsCard(
                      label: 'Total AI scans',
                      value: '24',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: AdminAnalyticsCard(
                      label: 'Auto-referrals',
                      value: '2',
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: AdminAnalyticsCard(
                      label: 'AI Scan Performance',
                      value: '100%',
                      change: '41 of 41 scans succeeded in the last month',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final sizes = {
          for (final e in find.byType(AdminAnalyticsCard).evaluate())
            tester.getSize(find.byWidget(e.widget)),
        };
        expect(sizes.length, 1, reason: 'sizes differ: $sizes');
        expect(sizes.first.height, AdminAnalyticsCard.height);
      });
    }
  });

  group('page header', () {
    for (final size in [phone, tablet, desktop]) {
      testWidgets(
        'with no action it spans the page and starts at the left ($size)',
        (tester) async {
          setSize(tester, size);
          // The same arrangement every section uses: header above a body,
          // in a Column whose default alignment is centred.
          await tester.pumpWidget(
            app(
              const Column(
                children: [
                  AdminHeader(title: 'Dashboard', subtitle: 'System overview'),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          );
          expect(tester.getSize(find.byType(AdminHeader)).width, size.width);
          expect(tester.getTopLeft(find.text('Dashboard')).dx, lessThan(30));
          expect(
            tester.getTopLeft(find.text('System overview')).dx,
            tester.getTopLeft(find.text('Dashboard')).dx,
          );
        },
      );
    }
  });

  group('user details table', () {
    for (final size in [phone, tablet, desktop]) {
      testWidgets(
        'shows label/value rows and fits at ${size.width.toInt()} wide',
        (tester) async {
          setSize(tester, size);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAdminUserInfo(context, const {
                      'username': 'maria',
                      'firstName': 'Maria',
                      'lastName': 'Santos',
                      'recoveryEmail': 'a.very.long.email.address@example.com',
                    }),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Three labelled tables under a header with the name and @username.
          final tables = find.byKey(const ValueKey('admin-info-table'));
          expect(tables, findsNWidgets(3));
          // Age is its own row, apart from the date of birth.
          expect(find.text('Age'), findsOneWidget);
          expect(find.text('Date of birth'), findsOneWidget);
          // Every row's rule spans the whole table width: no gaps or breaks.
          final rows = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                (w.key as ValueKey).value.toString().startsWith(
                  'admin-info-row-',
                ),
          );
          expect(rows, findsWidgets);
          for (final row in rows.evaluate()) {
            final rowRect = tester.getRect(find.byWidget(row.widget));
            final table = tables.evaluate().firstWhere((t) {
              final r = tester.getRect(find.byWidget(t.widget));
              return r.top <= rowRect.top && r.bottom >= rowRect.bottom;
            });
            // The table has a 1px outer border on each side.
            expect(
              rowRect.width,
              tester.getRect(find.byWidget(table.widget)).width - 2,
            );
          }
          expect(find.text('Maria Santos'), findsOneWidget);
          expect(find.text('@maria'), findsOneWidget);
          expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
          expect(find.text('CONTACT'), findsOneWidget);
          expect(find.text('ACCOUNT'), findsOneWidget);
          expect(find.text('Username'), findsOneWidget);
          expect(find.text('maria'), findsOneWidget);
          expect(find.text('Underage acknowledgment'), findsOneWidget);
          expect(find.text('Not applicable'), findsOneWidget);
          expect(find.text('Not provided'), findsWidgets);
          expect(find.text('Close'), findsOneWidget);
        },
      );
    }
  });
}
