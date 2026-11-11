import 'package:fine_aid/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, void Function(String?) done) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => done(
                await showDialog<String>(
                  context: context,
                  builder: (_) => const EditPhoneDialog(initial: '09171234567'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel closes it cleanly (the number was right)', (
    tester,
  ) async {
    String? result = 'untouched';
    await open(tester, (v) => result = v);
    expect(find.text('Edit Phone Number'), findsOneWidget);
    // type something, then change their mind
    await tester.enterText(find.byType(TextField), '09999999999');
    await tester.tap(find.text('Cancel'));
    // step through the closing animation, where the crash used to happen
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, isNull);
    expect(find.text('Edit Phone Number'), findsNothing);
  });

  testWidgets('Save and resend gives the typed number', (tester) async {
    String? result;
    await open(tester, (v) => result = v);
    await tester.enterText(find.byType(TextField), '09181234567');
    await tester.tap(find.text('Save & Resend'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, '09181234567');
  });

  testWidgets('it can be opened and cancelled again and again', (tester) async {
    var closed = 0;
    await open(tester, (_) => closed++);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(closed, 3);
  });
}
