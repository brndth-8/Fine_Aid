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

  Future<void> pump(WidgetTester tester, AppLanguage language) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: const MaterialApp(home: HealthChecklistScreen()),
      ),
    );
    await tester.pump();
  }

  for (final lang in {
    AppLanguage.en: ChecklistStrings.en,
    AppLanguage.tl: ChecklistStrings.tl,
  }.entries) {
    final s = lang.value;

    testWidgets('${lang.key.name}: diabetes opens to its types, disclaimer '
        'when one is chosen', (tester) async {
      await pump(tester, lang.key);
      final ticked = find.byWidgetPredicate(
        (w) => w is Checkbox && w.value == true,
      );

      // Closed: no type list, no pop-up.
      expect(find.text(s.diabetesType1), findsNothing);
      expect(find.text(s.disclaimer), findsNothing);

      // Opening the card chooses nothing: the types show, no pop-up.
      await tester.tap(find.text(s.diabetes));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsNothing);
      for (final name in [
        s.diabetesType1,
        s.diabetesType2,
        s.diabetesGestational,
        s.diabetesPrediabetes,
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(ticked, findsNothing);

      // Choosing a type is how Diabetes is chosen: the pop-up comes.
      await tester.tap(find.text(s.diabetesType2));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsOneWidget);
      await tester.tap(find.text(s.disclaimerOk));
      await tester.pumpAndSettle();
      expect(ticked, findsOneWidget);

      // Single choice: another type moves the tick, with no second pop-up.
      await tester.tap(find.text(s.diabetesGestational));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsNothing);
      expect(ticked, findsOneWidget);

      // The pop-up never blocked the selection or the Continue button.
      final cont = find.widgetWithText(ElevatedButton, s.continueButton);
      expect(tester.widget<ElevatedButton>(cont).onPressed, isNotNull);

      // Tapping the chosen type again clears it: no pop-up, nothing chosen.
      await tester.tap(find.text(s.diabetesGestational));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsNothing);
      expect(ticked, findsNothing);

      // Choosing again pops up again.
      await tester.tap(find.text(s.diabetesType1));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsOneWidget);
    });

    testWidgets('${lang.key.name}: every checked condition shows it; food '
        'allergy examples are listed', (tester) async {
      await pump(tester, lang.key);

      await tester.tap(find.text(s.hemophilia));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsNothing); // opening chooses nothing
      await tester.tap(find.text(s.hemophiliaA));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsOneWidget);
      await tester.tap(find.text(s.disclaimerOk));
      await tester.pumpAndSettle();

      await tester.tap(find.text(s.commonAllergies));
      await tester.pumpAndSettle();
      expect(find.text(s.foodAllergyExamples), findsOneWidget);
      await tester.tap(find.text(s.allergyFood));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsOneWidget);
      await tester.tap(find.text(s.disclaimerOk));
      await tester.pumpAndSettle();

      // "None of the above" is not a condition: no pop-up.
      await tester.tap(find.text(s.noneOfTheAbove));
      await tester.pumpAndSettle();
      expect(find.text(s.disclaimer), findsNothing);
    });
  }
}
