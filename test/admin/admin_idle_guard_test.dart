import 'package:fine_aid/features/admin/screens/widgets/admin_idle_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The guard compares wall-clock time, which widget tests don't fake, so each
// test moves a fake clock in step with the pumped frames. Uses a 10 s timeout
// with a 4 s warning to keep it short; real values live in admin_config.dart.
class _Clock {
  DateTime now = DateTime(2026, 1, 1, 9);

  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

Widget _app(_Clock clock, {required Future<void> Function() onTimeout}) =>
    MaterialApp(
      home: AdminIdleGuard(
        timeout: const Duration(seconds: 10),
        warning: const Duration(seconds: 4),
        clock: () => clock.now,
        onIdleTimeout: onTimeout,
        child: const Scaffold(body: Center(child: Text('dashboard'))),
      ),
    );

void main() {
  testWidgets('no warning and no sign-out while within the idle limit', (
    tester,
  ) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));
    await clock.elapse(tester, 5);
    expect(find.text('Stay signed in'), findsNothing);
    expect(timedOut, 0);
  });

  testWidgets('warning appears near the limit, then sign-out fires once', (
    tester,
  ) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));

    await clock.elapse(tester, 7);
    expect(find.text('Stay signed in'), findsOneWidget);
    expect(find.textContaining('signed out soon due to inactivity'), findsOne);
    expect(timedOut, 0);

    await clock.elapse(tester, 4);
    expect(timedOut, 1);
    await clock.elapse(tester, 5);
    expect(timedOut, 1, reason: 'must not fire a second time');
  });

  testWidgets('a tap resets the timer before the warning', (tester) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));

    await clock.elapse(tester, 5);
    await tester.tap(find.text('dashboard'));
    await clock.elapse(tester, 5);
    expect(find.text('Stay signed in'), findsNothing);
    expect(timedOut, 0);

    await clock.elapse(tester, 6);
    expect(timedOut, 1);
  });

  testWidgets('a key press resets the timer', (tester) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));

    await clock.elapse(tester, 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await clock.elapse(tester, 5);
    expect(find.text('Stay signed in'), findsNothing);
    expect(timedOut, 0);
  });

  testWidgets('"Stay signed in" closes the warning and restarts the timer', (
    tester,
  ) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));

    await clock.elapse(tester, 7);
    expect(find.text('Stay signed in'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Stay signed in'), findsNothing);

    await clock.elapse(tester, 5);
    expect(timedOut, 0);
    await clock.elapse(tester, 6);
    expect(timedOut, 1);
  });

  testWidgets('stray pointer activity does not dismiss the warning', (
    tester,
  ) async {
    final clock = _Clock();
    var timedOut = 0;
    await tester.pumpWidget(_app(clock, onTimeout: () async => timedOut++));

    await clock.elapse(tester, 7);
    expect(find.text('Stay signed in'), findsOneWidget);

    // A tap on the (non-dismissible) barrier must not count as activity.
    await tester.tapAt(const Offset(5, 5));
    await clock.elapse(tester, 4);
    expect(timedOut, 1);
  });
}
