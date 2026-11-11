// The fake document below deliberately implements Firestore's sealed
// snapshot type: it only stands in for it in a layout test.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/features/admin/screens/sections/admin_content_management.dart';
import 'package:fine_aid/features/admin/screens/sections/admin_feedback.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_pagination.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_report_pdf.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_shared_widgets.dart';
import 'package:fine_aid/features/admin/theme/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const phone = Size(360, 800);
const tablet = Size(768, 1024);
const laptop = Size(1366, 768);
const monitor = Size(1700, 900);

/// Wide enough for the three action links even in the test font, whose
/// letters are about twice as wide as a real font's.
const ultrawide = Size(2800, 1000);

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

/// Stands in for the Firestore-backed pager so the page can be laid out in a
/// test with two articles and no network.
class _Pager extends ChangeNotifier implements AdminPageController {
  _Pager(this.docs);

  @override
  List<AdminDoc> docs;
  @override
  bool loading = false;
  @override
  Object? error;
  @override
  int page = 1;
  @override
  int? total = 2;

  @override
  int get pageSize => 10;
  @override
  Query<Map<String, dynamic>> get query => throw UnimplementedError();
  @override
  int? get totalPages => 1;
  @override
  bool get hasPrev => false;
  @override
  bool get hasNext => false;
  @override
  int get rangeStart => 1;
  @override
  int get rangeEnd => docs.length;
  @override
  void goToFirst() {}
  @override
  void next() {}
  @override
  void previous() {}
  @override
  Future<void> goToLast() async {}
  @override
  void retry() {}
}

AdminDoc _article(String id, Map<String, dynamic> data) => _Doc(id, data);

Future<void> _pumpContent(WidgetTester tester, Size size) async {
  setSize(tester, size);
  final pager = _Pager([
    _article('a1', {
      'title': 'PHYSIOGEL (Skin)',
      'category': 'Skin',
      'source': 'Red Cross manual',
      'status': 'Live',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 20)),
    }),
    _article('a2', {
      'title':
          'A very long product name that keeps going and going and going on',
      'category': 'Emergency',
      'status': 'unpublished',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 21)),
    }),
  ]);
  addTearDown(pager.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AdminTheme.theme,
      home: Scaffold(body: AdminContentManagement(pager: pager)),
    ),
  );
  await tester.pump();
}

bool _horizontalScrollers(Widget w) =>
    w is SingleChildScrollView && w.scrollDirection == Axis.horizontal;

void main() {
  group(
    'admin reply to feedback: no minimum, only not-blank and a maximum',
    () {
      test('a short reply is fine', () {
        expect(adminFeedbackResponseProblem('Thanks!'), isNull);
        expect(adminFeedbackResponseProblem('x'), isNull);
      });

      test('a blank reply is refused', () {
        expect(
          adminFeedbackResponseProblem(''),
          'Write a response before sending.',
        );
      });

      test('there is no "at least 60 characters" message anywhere', () {
        for (final n in [1, 10, 59, 60, 100]) {
          expect(
            adminFeedbackResponseProblem('x' * n),
            isNull,
            reason: '$n characters',
          );
        }
      });

      test('over the 1000 maximum is refused with the count', () {
        expect(adminFeedbackResponseProblem('x' * 1000), isNull);
        expect(
          adminFeedbackResponseProblem('x' * 1001),
          'Responses can be at most 1000 characters (now 1001).',
        );
      });

      test('typing and pasting stop at the maximum', () {
        final formatter = LengthLimitingTextInputFormatter(
          adminFeedbackResponseMax,
        );
        final pasted = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: 'y' * 2500),
        );
        expect(pasted.text.length, 1000);
      });
    },
  );

  group('analytics cards link to their pages', () {
    testWidgets('a click and Enter/Space both open the page', (tester) async {
      setSize(tester, laptop);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: AdminAnalyticsCard(
                  label: 'Total users',
                  value: '32',
                  onTap: () => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Total users'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(opened, 3);
    });

    testWidgets('without a link it is plain, and the size never changes', (
      tester,
    ) async {
      setSize(tester, laptop);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const AdminAnalyticsCard(label: 'A', value: '1'),
                AdminAnalyticsCard(label: 'B', value: '2', onTap: () {}),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      expect(
        tester.getSize(find.byType(AdminAnalyticsCard).first),
        tester.getSize(find.byType(AdminAnalyticsCard).last),
      );
    });
  });

  group('report PDF', () {
    test('is a real PDF and copes with empty and non-latin text', () async {
      final bytes = await buildAdminReportPdf(
        title: 'App usage summary',
        headers: const ['Metric', 'Value'],
        rows: const [
          ['Total users', '32'],
          ['Ñandú “quoted” 日本語', '1'],
        ],
        columnFlex: const [3, 1],
        generatedAt: DateTime(2026, 10, 27),
        generatedBy: 'admin@example.com',
        note: 'first 5000 entries only',
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      final empty = await buildAdminReportPdf(
        title: 'Empty',
        headers: const ['A'],
        rows: const [],
        generatedAt: DateTime(2026, 10, 27),
        generatedBy: 'admin',
      );
      expect(String.fromCharCodes(empty.sublist(0, 5)), '%PDF-');
    });
  });

  group('content management display name', () {
    test('drops a trailing category in parentheses', () {
      expect(contentDisplayName('PHYSIOGEL (Skin)', 'Skin'), 'PHYSIOGEL');
      expect(contentDisplayName('Betadine (skin)', 'Skin Care'), 'Betadine');
    });

    test('keeps anything that is not the category', () {
      expect(
        contentDisplayName('Paracetamol (500 mg)', 'Medicine'),
        'Paracetamol (500 mg)',
      );
      expect(contentDisplayName('Plain name', 'Skin'), 'Plain name');
      expect(contentDisplayName('(Skin)', 'Skin'), '(Skin)');
      expect(contentDisplayName('Name (Skin)', ''), 'Name (Skin)');
    });
  });

  group('content management layout', () {
    for (final size in [phone, tablet, laptop, monitor]) {
      testWidgets(
        'fits with no overflow or sideways scrolling at ${size.width.toInt()} wide',
        (tester) async {
          await _pumpContent(tester, size);
          expect(tester.takeException(), isNull);
          expect(find.byWidgetPredicate(_horizontalScrollers), findsNothing);
          // Both articles are there, and the stored-title "(Skin)" is not.
          expect(find.text('PHYSIOGEL'), findsOneWidget);
          expect(find.text('PHYSIOGEL (Skin)'), findsNothing);
          expect(find.text('Skin'), findsWidgets);
          // The title lines up with the table card below it.
          final title = tester.getTopLeft(find.text('Content management')).dx;
          final pagerLeft = tester.getTopLeft(find.byType(AdminPager)).dx;
          expect(title, pagerLeft - 1, reason: 'card has a 1px border');
          expect(title, size.width < 768 ? 16 : 32);
        },
      );
    }

    testWidgets('wide: table and panel side by side, panel 380px', (
      tester,
    ) async {
      await _pumpContent(tester, laptop);
      final panel = tester.getRect(
        find
            .ancestor(
              of: find.text('New article'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(panel.width, 380);
      final pager = tester.getRect(find.byType(AdminPager));
      expect(panel.left, greaterThan(pager.right));
      expect(panel.left - pager.right, closeTo(24 + 1, 1.5));
    });

    testWidgets('below 1100 the panel stacks under the table', (tester) async {
      await _pumpContent(tester, tablet);
      final pager = tester.getRect(find.byType(AdminPager));
      final panelTitle = tester.getTopLeft(find.text('New article'));
      expect(panelTitle.dy, greaterThan(pager.bottom));
    });

    testWidgets('the four columns are 42/24/14/20 percent of the table', (
      tester,
    ) async {
      await _pumpContent(tester, monitor);
      final headerCells = [
        for (final label in [
          'Name of Products',
          'Category',
          'Updated',
          'Action',
        ])
          tester.getRect(find.text(label).first).left,
      ];
      final pagerRect = tester.getRect(find.byType(AdminPager));
      final tableLeft = pagerRect.left;
      final tableWidth = pagerRect.width;
      double fraction(double left, double padding) =>
          (left - tableLeft - 1 - padding) / (tableWidth - 2);
      expect(fraction(headerCells[0], 20), closeTo(0, 0.01));
      expect(fraction(headerCells[1], 20), closeTo(0.42, 0.01));
      expect(fraction(headerCells[2], 20), closeTo(0.66, 0.01));
      expect(fraction(headerCells[3], 20), closeTo(0.80, 0.01));
    });

    testWidgets('large screen: Edit / Unpublish / Delete are links in a row', (
      tester,
    ) async {
      await _pumpContent(tester, ultrawide);
      expect(find.text('Edit'), findsNWidgets(2));
      expect(find.text('Unpublish'), findsOneWidget);
      expect(find.text('Re-publish'), findsOneWidget);
      expect(find.text('Delete'), findsNWidgets(2));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      final edit = tester.getRect(find.text('Edit').first);
      final unpublish = tester.getRect(find.text('Unpublish'));
      final delete = tester.getRect(find.text('Delete').first);
      expect(unpublish.left - edit.right, closeTo(16, 1));
      expect(delete.left - unpublish.right, closeTo(16, 1));
      expect(edit.center.dy, closeTo(delete.center.dy, 1));
      // Delete stays red.
      final style = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete').first,
      );
      expect(
        style.style?.foregroundColor?.resolve({}),
        AdminTheme.theme.colorScheme.error,
      );
    });

    testWidgets('when the actions would not fit they collapse to a ⋯ menu', (
      tester,
    ) async {
      await _pumpContent(tester, laptop);
      expect(find.byIcon(Icons.more_horiz), findsNWidgets(2));
      expect(find.text('Unpublish'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Unpublish'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('small screens hide the Source line', (tester) async {
      await _pumpContent(tester, monitor);
      expect(find.text('Source: Red Cross manual'), findsOneWidget);
      await _pumpContent(tester, phone);
      expect(find.text('Source: Red Cross manual'), findsNothing);
    });

    testWidgets('phone: rows are stacked cards with no header row', (
      tester,
    ) async {
      await _pumpContent(tester, phone);
      expect(find.text('Action'), findsNothing);
      expect(find.text('Updated'), findsNothing);
      // Name above, then the category pill and date on one line.
      final name = tester.getRect(find.text('PHYSIOGEL'));
      final pill = tester.getRect(find.text('Skin').first);
      final date = tester.getRect(find.text('10/20/26'));
      expect(pill.top, greaterThan(name.bottom));
      expect(date.center.dy, closeTo(pill.center.dy, 2));
      // The pager's controls sit centred under the entry count.
      final count = tester.getCenter(find.textContaining('Showing 1'));
      final card = tester.getRect(find.byType(AdminPager));
      expect(count.dx, closeTo(card.center.dx, 2));
    });

    testWidgets('category pill text stays on one line', (tester) async {
      await _pumpContent(tester, monitor);
      final size = tester.getSize(find.text('Emergency').first);
      expect(size.height, lessThan(12 * 1.35 * 1.5));
    });

    testWidgets('panel buttons: side by side, stacked on a phone', (
      tester,
    ) async {
      await _pumpContent(tester, laptop);
      var save = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      var preview = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Preview'),
      );
      expect(save.height, 44);
      expect(save.top, preview.top);
      expect(preview.left - save.right, closeTo(12, 0.5));

      await _pumpContent(tester, phone);
      save = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Save changes'),
      );
      preview = tester.getRect(find.widgetWithText(OutlinedButton, 'Preview'));
      expect(preview.top, greaterThan(save.bottom));
      expect(save.left, preview.left);
      expect(save.width, preview.width);
    });

    testWidgets('panel inputs are 44px high', (tester) async {
      await _pumpContent(tester, laptop);
      final field = tester.getSize(find.widgetWithText(TextField, '').first);
      expect(field.height, greaterThanOrEqualTo(44));
    });
  });
}
