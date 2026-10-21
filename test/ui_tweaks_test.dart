import 'package:fine_aid/core/widgets/custom_bottom_nav_bar.dart';
import 'package:fine_aid/features/auth/screens/registration_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/nav_strings.dart';
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

  group('contact number placeholder', () {
    testWidgets('small, light and light gray; typed text is left alone', (
      tester,
    ) async {
      // (wide, because the test font draws text much wider than a real one)
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pump();

      final phone = tester.widget<TextField>(
        find.ancestor(
          of: find.text('9123456789'),
          matching: find.byType(TextField),
        ),
      );
      final hint = phone.decoration!.hintStyle!;
      expect(hint.fontSize, 12);
      expect(hint.fontWeight, FontWeight.w300);
      expect(hint.color, const Color(0xFFBDBDBD));
      // the typed digits keep the field's normal style
      expect(phone.style, isNull);

      // another field's placeholder is untouched
      final username = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Enter a username'),
          matching: find.byType(TextField),
        ),
      );
      expect(username.decoration!.hintStyle?.color, isNull);
      expect(username.decoration!.hintStyle?.fontWeight, isNull);
    });
  });

  group('bottom bar labels', () {
    Future<void> pump(
      WidgetTester tester,
      double width,
      AppLanguage language,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: Builder(
            builder: (context) {
              final n = NavStrings.of(context);
              return MaterialApp(
                home: Scaffold(
                  bottomNavigationBar: CustomBottomNavBar(
                    items: [
                      BottomNavItem(
                        icon: Icons.menu_book_outlined,
                        label: n.healthJournal,
                      ),
                      BottomNavItem(
                        icon: Icons.crop_free,
                        label: n.aiVisionCamera,
                        badge: 'AI',
                      ),
                      BottomNavItem(
                        icon: Icons.support_agent_outlined,
                        label: n.helpAndSupport,
                      ),
                    ],
                    onItemTap: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final width in [320.0, 360.0, 412.0]) {
      for (final language in AppLanguage.values) {
        testWidgets('${language.name} at ${width.toInt()} dp: 13 sp, no '
            'overflow, bar height unchanged', (tester) async {
          await pump(tester, width, language);
          final n = NavStrings.of(tester.element(find.byType(Scaffold)));
          for (final label in [
            n.healthJournal,
            n.aiVisionCamera,
            n.helpAndSupport,
          ]) {
            final text = tester.widget<Text>(find.text(label));
            expect(
              DefaultTextStyle.of(
                tester.element(find.text(label)),
              ).style.fontSize,
              13,
            );
            expect(text.maxLines, 2);
          }
          // the bar itself is still 70 dp tall (+42 dp of room above it)
          expect(tester.getSize(find.byType(CustomBottomNavBar)).height, 112);
          expect(tester.takeException(), isNull);
        });
      }
    }

    test('Tagalog labels exist', () {
      expect(NavStrings.tl.helpAndSupport, isNot(NavStrings.en.helpAndSupport));
    });
  });
}
