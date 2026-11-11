import 'package:fine_aid/features/auth/screens/login_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A smoke test: the first screen a new person sees builds and offers the
/// three ways in. (The old test here was the Flutter template's counter test,
/// which this app never had.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('the welcome screen offers Log In, Create Account and Guest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const AppLanguageScope(
        language: AppLanguage.en,
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
