import 'package:fine_aid/core/widgets/custom_bottom_nav_bar.dart';
import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/auth/screens/login_form_screen.dart';
import 'package:fine_aid/features/auth/screens/login_screen.dart';
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
    WidgetTester tester,
    Widget screen, {
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
  }

  group('login screen', () {
    testWidgets('Log In, Create Account and Continue as Guest', (tester) async {
      await pump(tester, const LoginScreen());
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('login form screen', () {
    testWidgets('labels, fields, Log In, Forgot Password and Register', (
      tester,
    ) async {
      await pump(tester, const LoginFormScreen());
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Enter Username'), findsOneWidget);
      expect(find.text('Enter Password'), findsOneWidget);
      expect(find.text('Keep me signed in'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(
        find.textContaining('Register here', findRichText: true),
        findsOneWidget,
      );
      // one back arrow
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await pump(tester, const LoginFormScreen());
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('empty fields still show the required messages', (
      tester,
    ) async {
      await pump(tester, const LoginFormScreen());
      await tester.tap(find.text('Log In'));
      await tester.pump();
      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });

  group('health profile', () {
    final en = ChecklistStrings.en;

    ElevatedButton continueButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, en.continueButton),
        );

    testWidgets('starts with Continue off; the allergy types are hidden', (
      tester,
    ) async {
      await pump(tester, const HealthChecklistScreen());
      expect(find.text(en.commonAllergies), findsOneWidget);
      expect(find.text(en.allergyFood), findsNothing);
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('Common Allergies opens to the six types', (tester) async {
      await pump(tester, const HealthChecklistScreen());
      await tester.tap(find.text(en.commonAllergies));
      await tester.pump();
      for (final label in [
        en.allergyRhinitis,
        en.allergyFood,
        en.allergySkin,
        en.allergyInsect,
        en.allergyDrug,
        en.allergyLatex,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('choosing one allergy turns Continue on', (tester) async {
      await pump(tester, const HealthChecklistScreen());
      await tester.tap(find.text(en.commonAllergies));
      await tester.pump();
      await tester.tap(find.text(en.allergyDrug));
      await tester.pump();
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('"none of the listed" and the allergies exclude each other', (
      tester,
    ) async {
      await pump(tester, const HealthChecklistScreen());
      await tester.tap(find.text(en.commonAllergies));
      await tester.pump();
      await tester.tap(find.text(en.allergyFood));
      await tester.pump();
      await tester.tap(find.text(en.noneOfTheAbove));
      await tester.pump();
      // "none" is chosen and the allergy is cleared: one box ticked.
      int ticked() => tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .where((c) => c.value == true)
          .length;
      expect(ticked(), 1);
      expect(continueButton(tester).onPressed, isNotNull);
      // picking an allergy again clears "none": still one box ticked.
      await tester.tap(find.text(en.allergySkin));
      await tester.pump();
      expect(ticked(), 1);
    });

    testWidgets('the descriptions are all still there', (tester) async {
      await pump(tester, const HealthChecklistScreen());
      for (final text in [
        en.diabetesInfo,
        en.hemophiliaInfo,
        en.severeAllergiesInfo,
        en.noneInfo,
      ]) {
        expect(find.text(text), findsOneWidget);
      }
    });

    testWidgets('the allergy types are translated', (tester) async {
      await pump(
        tester,
        const HealthChecklistScreen(),
        language: AppLanguage.tl,
      );
      final tl = ChecklistStrings.tl;
      await tester.tap(find.text(tl.commonAllergies));
      await tester.pump();
      for (final label in [
        tl.allergyFood,
        tl.allergySkin,
        tl.allergyInsect,
        tl.allergyDrug,
        tl.allergyLatex,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tl.allergyFood, isNot(en.allergyFood));
    });
  });

  group('bottom bar', () {
    testWidgets('three destinations; the middle one is the AI button', (
      tester,
    ) async {
      var tapped = -1;
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              itemKeys: keys,
              items: const [
                BottomNavItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Health Journal',
                ),
                BottomNavItem(
                  icon: Icons.crop_free,
                  label: 'AI Vision Camera',
                  badge: 'AI',
                ),
                BottomNavItem(
                  icon: Icons.support_agent_outlined,
                  label: 'Help and Support',
                ),
              ],
              onItemTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      expect(find.text('Health Journal'), findsOneWidget);
      expect(find.text('AI Vision Camera'), findsOneWidget);
      expect(find.text('Help and Support'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      // the Help Tour can still find each button
      for (final k in keys) {
        expect(k.currentContext, isNotNull);
      }

      await tester.tap(find.text('AI'));
      expect(tapped, 1);
      await tester.tap(find.text('Health Journal'));
      expect(tapped, 0);
      await tester.tap(find.text('Help and Support'));
      expect(tapped, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
