import 'package:fine_aid/features/admin/screens/sections/admin_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Philippine time', () {
    test('a Manila date and time becomes the right moment (UTC+8)', () {
      final when = manilaInstant(
        DateTime(2026, 11, 12),
        const TimeOfDay(hour: 15, minute: 30),
      );
      expect(when.toUtc(), DateTime.utc(2026, 11, 12, 7, 30));
    });

    test('just after midnight in Manila is the evening before in UTC', () {
      final when = manilaInstant(
        DateTime(2026, 11, 12),
        const TimeOfDay(hour: 0, minute: 30),
      );
      expect(when.toUtc(), DateTime.utc(2026, 11, 11, 16, 30));
    });

    test(
      'the Manila clock reading round-trips, whatever the computer timezone',
      () {
        final when = manilaInstant(
          DateTime(2026, 12, 31),
          const TimeOfDay(hour: 23, minute: 59),
        );
        final wall = manilaWallClock(when);
        expect(
          [wall.year, wall.month, wall.day, wall.hour, wall.minute],
          [2026, 12, 31, 23, 59],
        );
      },
    );

    test('it is shown with PHT', () {
      expect(
        formatManila(DateTime.utc(2026, 11, 12, 7, 30)),
        'Nov 12, 2026 3:30 PM PHT',
      );
      expect(kScheduleTimezone, 'Asia/Manila');
      expect(kScheduleTimezoneLabel, contains('Asia/Manila'));
    });
  });

  group('the form rules', () {
    final now = DateTime.utc(2026, 11, 12, 0, 0); // 8:00 AM in Manila
    final today = DateTime(2026, 11, 12);

    String? problem({
      String title = 'Hello',
      bool toSelected = false,
      int users = 0,
      bool schedule = false,
      DateTime? date,
      TimeOfDay? time,
    }) => notificationFormProblem(
      title: title,
      toSelectedUsers: toSelected,
      userCount: users,
      schedule: schedule,
      date: date,
      time: time,
      now: now,
    );

    test('a title is always needed', () {
      expect(problem(title: '  '), 'Enter a title first.');
    });

    test('send to all: nothing else is needed', () {
      expect(problem(), isNull);
    });

    test('specific users need at least one user, and not too many', () {
      expect(problem(toSelected: true), 'Pick at least one user.');
      expect(problem(toSelected: true, users: 1), isNull);
      expect(problem(toSelected: true, users: 500), isNull);
      expect(problem(toSelected: true, users: 501), contains('at most 500'));
    });

    test('scheduling needs a date and a time', () {
      expect(problem(schedule: true), 'Pick a date and time to schedule it.');
      expect(
        problem(schedule: true, date: today),
        'Pick a date and time to schedule it.',
      );
    });

    test('the scheduled time must be in the future, in Manila time', () {
      // It is 8:00 AM in Manila: 7:00 AM today has passed, 8:00 is too soon,
      // 8:02 is fine.
      expect(
        problem(
          schedule: true,
          date: today,
          time: const TimeOfDay(hour: 7, minute: 0),
        ),
        contains('in the future'),
      );
      expect(
        problem(
          schedule: true,
          date: today,
          time: const TimeOfDay(hour: 8, minute: 0),
        ),
        contains('in the future'),
      );
      expect(
        problem(
          schedule: true,
          date: today,
          time: const TimeOfDay(hour: 8, minute: 2),
        ),
        isNull,
      );
      expect(
        problem(
          schedule: true,
          date: DateTime(2026, 11, 13),
          time: const TimeOfDay(hour: 1, minute: 0),
          toSelected: true,
          users: 2,
        ),
        isNull,
      );
    });

    test('a list of users is summarised', () {
      expect(recipientsSummary([]), 'No users');
      expect(recipientsSummary(['juan']), 'juan');
      expect(recipientsSummary(['juan', 'maria']), 'juan, maria');
      expect(recipientsSummary(['a', 'b', 'c', 'd', 'e']), 'a, b +3 more');
    });
  });

  group('user picker (search and multi-select)', () {
    Future<void> pump(
      WidgetTester tester, {
      List<String> start = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = List<String>.of(start);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: AdminUserPicker(
                  allUsernames: const ['alice', 'bob', 'carol'],
                  selected: selected,
                  onChanged: (list) => setState(() => selected = list),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('starts empty and says so', (tester) async {
      await pump(tester);
      expect(find.text('No users picked yet.'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('picking users adds them as chips, several in a row', (
      tester,
    ) async {
      await pump(tester);
      for (final name in ['bob', 'alice']) {
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }
      expect(find.widgetWithText(InputChip, 'bob'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'alice'), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('a chosen user is not offered again', (tester) async {
      await pump(tester, start: ['bob']);
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      // 'bob' is only the chip, not also a menu entry; the others are offered.
      expect(find.widgetWithText(MenuItemButton, 'bob'), findsNothing);
      expect(find.widgetWithText(MenuItemButton, 'alice'), findsWidgets);
    });

    testWidgets('a chip can be removed, and Clear all empties the list', (
      tester,
    ) async {
      await pump(tester, start: ['alice', 'bob']);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'alice'),
          matching: find.byType(Icon),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'alice'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('No users picked yet.'), findsOneWidget);
    });
  });
}
