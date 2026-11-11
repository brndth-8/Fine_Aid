import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// System Security puts its two columns in an IntrinsicHeight so the Password
/// policy card can grow to the height of the protections card. That only works
/// if everything in those columns can report its height without being laid
/// out first (a LayoutBuilder cannot). This pins that for the widget kinds the
/// page uses: Switch, DropdownButton, Wrap, Row/Expanded and bordered boxes.
void main() {
  testWidgets('the right column grows to the left column and nothing throws', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final left = Container(
      key: const Key('left'),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++)
            Row(
              children: [
                const Expanded(child: Text('A protection with a long label')),
                DropdownButton<int>(
                  value: 5,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 minutes')),
                  ],
                  onChanged: (_) {},
                ),
                Switch(value: true, onChanged: (_) {}),
              ],
            ),
          Wrap(
            spacing: 8,
            children: const [Text('Lock after'), Text('Locked for')],
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 120,
                          color: Colors.blue,
                          key: const Key('session'),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            key: const Key('password'),
                            color: Colors.green,
                            child: const Text('Password policy'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final leftRect = tester.getRect(find.byKey(const Key('left')));
    final password = tester.getRect(find.byKey(const Key('password')));
    // The password card's bottom edge is the protections card's bottom edge.
    expect(password.bottom, closeTo(leftRect.bottom, 0.5));
    expect(password.height, greaterThan(100));
  });
}
