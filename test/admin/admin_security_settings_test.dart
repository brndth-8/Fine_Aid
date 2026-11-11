import 'package:fine_aid/features/admin/admin_security_settings.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_idle_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock {
  DateTime now = DateTime(2026, 1, 1, 9);

  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

void main() {
  group('saved settings', () {
    test('nothing saved yet means on, with the default length', () {
      final s = AdminSecuritySettings.fromData(null);
      expect(s.idleTimeoutEnabled, isTrue);
      expect(s.idleTimeoutMinutes, 15);
      expect(s, AdminSecuritySettings.defaults);
    });

    test('a saved off switch and length read back', () {
      final s = AdminSecuritySettings.fromData({
        'idleTimeoutEnabled': false,
        'idleTimeoutMinutes': 30,
      });
      expect(s.idleTimeoutEnabled, isFalse);
      expect(s.idleTimeout, const Duration(minutes: 30));
    });

    test('values that are not allowed fall back to the defaults', () {
      final s = AdminSecuritySettings.fromData({
        'idleTimeoutEnabled': 'no',
        'idleTimeoutMinutes': 7,
      });
      expect(s, AdminSecuritySettings.defaults);
    });
  });

  group('idle guard follows the switch', () {
    Widget app(
      _Clock clock,
      ValueNotifier<({bool on, int seconds})> setting,
      void Function() onTimeout,
    ) => MaterialApp(
      home: ValueListenableBuilder(
        valueListenable: setting,
        builder: (context, s, _) => AdminIdleGuard(
          enabled: s.on,
          timeout: Duration(seconds: s.seconds),
          warning: const Duration(seconds: 4),
          clock: () => clock.now,
          onIdleTimeout: () async => onTimeout(),
          child: const Scaffold(body: Center(child: Text('dashboard'))),
        ),
      ),
    );

    testWidgets('switched off: no warning and no sign-out, however long', (
      tester,
    ) async {
      final clock = _Clock();
      var timedOut = 0;
      final setting = ValueNotifier((on: false, seconds: 10));
      await tester.pumpWidget(app(clock, setting, () => timedOut++));
      await clock.elapse(tester, 60);
      expect(find.text('Stay signed in'), findsNothing);
      expect(timedOut, 0);
    });

    testWidgets('turning it on starts a fresh idle period', (tester) async {
      final clock = _Clock();
      var timedOut = 0;
      final setting = ValueNotifier((on: false, seconds: 10));
      await tester.pumpWidget(app(clock, setting, () => timedOut++));
      await clock.elapse(tester, 60);

      setting.value = (on: true, seconds: 10);
      await tester.pump();
      await clock.elapse(tester, 5);
      expect(find.text('Stay signed in'), findsNothing);
      expect(timedOut, 0);

      await clock.elapse(tester, 6);
      expect(timedOut, 1);
    });

    testWidgets('turning it off while the warning shows closes it', (
      tester,
    ) async {
      final clock = _Clock();
      var timedOut = 0;
      final setting = ValueNotifier((on: true, seconds: 10));
      await tester.pumpWidget(app(clock, setting, () => timedOut++));
      await clock.elapse(tester, 7);
      expect(find.text('Stay signed in'), findsOneWidget);

      setting.value = (on: false, seconds: 10);
      await tester.pump();
      await clock.elapse(tester, 15);
      expect(find.text('Stay signed in'), findsNothing);
      expect(timedOut, 0);
    });

    testWidgets('a longer timeout applies straight away', (tester) async {
      final clock = _Clock();
      var timedOut = 0;
      final setting = ValueNotifier((on: true, seconds: 10));
      await tester.pumpWidget(app(clock, setting, () => timedOut++));
      await clock.elapse(tester, 7);
      expect(find.text('Stay signed in'), findsOneWidget);

      setting.value = (on: true, seconds: 60);
      await tester.pump();
      await clock.elapse(tester, 2);
      expect(find.text('Stay signed in'), findsNothing);
      await clock.elapse(tester, 30);
      expect(timedOut, 0);
    });
  });
}
