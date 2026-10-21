import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/settings_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A "Settings" page (pushed on top of a home page) with a button that asks
  // for the logout confirmation and records the answer.
  bool? answer;

  Future<void> open(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    answer = null;
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Builder(
                      builder: (context) => Scaffold(
                        body: Column(
                          children: [
                            const Text('settings page'),
                            ElevatedButton(
                              onPressed: () async =>
                                  answer = await confirmLogout(context),
                              child: const Text('open logout'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('go to settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go to settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open logout'));
    await tester.pumpAndSettle();
  }

  final en = SettingsStrings.en;
  final tl = SettingsStrings.tl;

  testWidgets('English: title, message, Cancel and Log out', (tester) async {
    await open(tester);
    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(
      answer,
      isNull,
      reason: 'nothing is decided until a button is tapped',
    );
  });

  testWidgets('Tagalog: title, message, Kanselahin and Mag-log out', (
    tester,
  ) async {
    await open(tester, language: AppLanguage.tl);
    expect(find.text('Mag-log out?'), findsOneWidget);
    expect(
      find.text('Sigurado ka bang gusto mong mag-log out?'),
      findsOneWidget,
    );
    expect(find.text('Kanselahin'), findsOneWidget);
    expect(find.text('Mag-log out'), findsOneWidget);
    expect(find.text(en.logOutConfirmTitle), findsNothing);
  });

  testWidgets('Cancel: no logout, same screen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('tapping outside the dialog does not log out', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('the Android back button does not log out', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    // back closed only the dialog, not the Settings page behind it
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('"Log out" confirms', (tester) async {
    await open(tester);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('double-tapping "Log out" answers once and keeps the screen', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Log out'));
    await tester.tap(find.text('Log out'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(answer, isTrue);
    expect(tester.takeException(), isNull);
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('"Log out" looks different from "Cancel"', (tester) async {
    await open(tester);
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final logout = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Log out'),
    );
    expect(cancel, isNotNull);
    final scheme = Theme.of(
      tester.element(find.byType(AlertDialog)),
    ).colorScheme;
    expect(
      logout.style?.backgroundColor?.resolve({}),
      scheme.primary,
      reason: 'the theme\'s dark red',
    );
    expect(
      logout.style?.foregroundColor?.resolve({}),
      scheme.onPrimary,
      reason: 'readable text on the dark red',
    );
  });

  test('every new text exists in both languages', () {
    expect(tl.logOutConfirmTitle, isNot(en.logOutConfirmTitle));
    expect(tl.logOutConfirmMessage, isNot(en.logOutConfirmMessage));
    expect(tl.logOutConfirmCancel, isNot(en.logOutConfirmCancel));
    expect(tl.logOutConfirmButton, isNot(en.logOutConfirmButton));
  });
}
