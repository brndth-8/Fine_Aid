import 'package:fine_aid/features/auth/screens/terms_screen.dart';
import 'package:fine_aid/features/settings/screens/help_topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One back button per screen — the arrow, never also a "Back" text
/// button.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  for (final topic in HelpTopic.values) {
    testWidgets('help topic "${topic.name}": a single arrow, no Back button', (
      tester,
    ) async {
      await pump(tester, HelpTopicScreen(topic: topic));
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });
  }

  testWidgets('read-only Terms (opened from Settings): one arrow, no Back text '
      'button', (tester) async {
    await pump(tester, const TermsScreen(readOnly: true));
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('Terms during sign-up has no back control (nothing to go back '
      'to) and keeps its Agree button', (tester) async {
    await pump(tester, const TermsScreen());
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    expect(find.text('Back'), findsNothing);
    expect(find.text('I Agree & Continue'), findsOneWidget);
  });

  testWidgets('tapping the arrow goes back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HelpTopicScreen(topic: HelpTopic.privacy),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
