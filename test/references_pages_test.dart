import 'package:fine_aid/features/settings/screens/help_topic_screen.dart';
import 'package:fine_aid/features/settings/screens/reference_detail_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/help_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: const MaterialApp(
          home: HelpTopicScreen(topic: HelpTopic.references),
        ),
      ),
    );
    await tester.pump();
  }

  final cases = [
    ('English', AppLanguage.en, HelpStrings.en),
    ('Tagalog', AppLanguage.tl, HelpStrings.tl),
  ];

  for (final (name, language, strings) in cases) {
    for (final label in strings.references.cardLabels) {
      testWidgets('$name: "$label" opens its own page and back returns to '
          'References', (tester) async {
        await pump(tester, language: language);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        // The new page: title + placeholder, exactly one back arrow.
        expect(find.byType(ReferenceDetailScreen), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(find.text(strings.contentComingSoon), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
        expect(find.text('Back'), findsNothing);

        await tester.tap(find.byIcon(Icons.arrow_back_ios));
        await tester.pumpAndSettle();
        expect(find.byType(ReferenceDetailScreen), findsNothing);
        expect(find.text(strings.references.title), findsOneWidget);
        expect(find.text(label), findsOneWidget);
      });
    }
  }

  testWidgets('both reference cards show a tap cue (chevron)', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
  });

  testWidgets('other help topics are unchanged (no tappable cards)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: HelpTopicScreen(topic: HelpTopic.privacy)),
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  test('the placeholder is translated', () {
    expect(
      HelpStrings.tl.contentComingSoon,
      isNot(HelpStrings.en.contentComingSoon),
    );
  });
}
