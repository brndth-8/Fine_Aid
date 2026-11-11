import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/checklist_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic>? saved,
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(home: HealthChecklistScreen(initialProfile: saved)),
      ),
    );
    await tester.pump();
  }

  final s = ChecklistStrings.en;
  ElevatedButton continueButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, s.continueButton),
      );

  testWidgets('Diabetes, blood disorders and allergies are chevron cards', (
    tester,
  ) async {
    await pump(tester);
    // three closed cards, each with a down chevron
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNWidgets(3));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await tester.tap(find.text(s.diabetes));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNWidgets(2));

    // tapping the header again closes it
    await tester.tap(find.text(s.diabetes));
    await tester.pumpAndSettle();
    expect(find.text(s.diabetesType1), findsNothing);
  });

  testWidgets('choosing a type chooses the condition and enables Continue', (
    tester,
  ) async {
    await pump(tester);
    expect(continueButton(tester).onPressed, isNull);
    await tester.tap(find.text(s.diabetes));
    await tester.pumpAndSettle();
    expect(continueButton(tester).onPressed, isNull); // opening is not choosing
    await tester.tap(find.text(s.diabetesType2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.disclaimerOk));
    await tester.pumpAndSettle();
    expect(continueButton(tester).onPressed, isNotNull);
    // a closed card that has something chosen shows a tick
    await tester.tap(find.text(s.diabetes));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('"none of the above" clears what was chosen', (tester) async {
    await pump(tester);
    await tester.tap(find.text(s.diabetes));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.diabetesType1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.disclaimerOk));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.noneOfTheAbove));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is Checkbox && w.value == true),
      findsOneWidget, // only "none of the above"
    );
  });

  testWidgets('typing a condition is the "other" condition', (tester) async {
    await pump(tester);
    expect(find.text(s.specifyCondition), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Asthma');
    await tester.pump();
    expect(continueButton(tester).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('Tagalog: the specify box has its own wording', (tester) async {
    await pump(tester, language: AppLanguage.tl);
    expect(find.text(ChecklistStrings.tl.specifyCondition), findsOneWidget);
    expect(
      ChecklistStrings.tl.specifyCondition,
      isNot(ChecklistStrings.en.specifyCondition),
    );
  });
}
