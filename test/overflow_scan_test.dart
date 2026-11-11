import 'package:fine_aid/core/widgets/nearby_healthcare_sheet.dart';
import 'package:fine_aid/features/auth/screens/forgot_password_screen.dart';
import 'package:fine_aid/features/auth/screens/health_checklist_screen.dart';
import 'package:fine_aid/features/auth/screens/login_form_screen.dart';
import 'package:fine_aid/features/auth/screens/login_screen.dart';
import 'package:fine_aid/features/auth/screens/terms_screen.dart';
import 'package:fine_aid/features/chatbot/screens/chatbot_screen.dart';
import 'package:fine_aid/features/settings/screens/ai_scan_info_screen.dart';
import 'package:fine_aid/features/settings/screens/guest_profile_gate_screen.dart';
import 'package:fine_aid/features/settings/screens/licenses_screen.dart';
import 'package:fine_aid/features/auth/screens/registration_screen.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/features/journal/screens/journal_list_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/features/settings/screens/feedback_screen.dart';
import 'package:fine_aid/features/settings/screens/help_screen.dart';
import 'package:fine_aid/features/settings/screens/personalization_screen.dart';
import 'package:fine_aid/features/settings/screens/settings_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "RIGHT OVERFLOWED BY n PIXELS" scan: the screens a person meets, on a narrow
/// phone (320 and 360 wide) at the app's largest text size (160%) on top of a
/// large system font, in English and Filipino. (The test font is wider than the
/// real one, so what fits here fits on a phone.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> open(
    WidgetTester tester,
    Widget home, {
    required double width,
    required double scale,
    required AppLanguage language,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    // some screens animate forever: step frames instead of settling
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // Screens that open as they are.
  final screens = <String, Widget Function()>{
    'Settings': () => const SettingsScreen(),
    'Help and Support': () => const HelpScreen(),
    'Personalization': () => const PersonalizationScreen(),
    'Feedback': () => const FeedbackScreen(),
    'Login': () => const LoginScreen(),
    'Registration': () => const RegistrationScreen(),
    'Health Journal': () => const JournalListScreen(),
    'New entry': () => const NewEntryScreen(),
    'First Aid Health Kit': () => const FirstAidKitScreen(),
    'Login form': () => const LoginFormScreen(),
    'Forgot password': () => const ForgotPasswordScreen(),
    'Terms': () => const TermsScreen(),
    'Licenses': () => const LicensesScreen(),
    'AI scan info': () => const AiScanInfoScreen(),
    'Chat': () => const ChatbotScreen(),
    'Health checklist': () => const HealthChecklistScreen(),
    'Guest profile gate': () => const GuestProfileGateScreen(),
  };

  for (final width in [320.0, 360.0]) {
    for (final language in AppLanguage.values) {
      for (final entry in screens.entries) {
        testWidgets(
          '${entry.key} at ${width.toInt()} px, 160% text, ${language.name}',
          (tester) async {
            ConnectivityService().lastKnownOnline = true;
            addTearDown(() => ConnectivityService().lastKnownOnline = null);
            await open(
              tester,
              entry.value(),
              width: width,
              scale: 1.6,
              language: language,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('Nearby Healthcare sheet at ${width.toInt()} px, 160% text, '
          '${language.name}', (tester) async {
        await open(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showNearbyHealthcareSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
          width: width,
          scale: 1.6,
          language: language,
        );
        await tester.tap(find.text('open'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(find.byType(NearbyHealthcareSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        // the category row in particular
        expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
        final dropdown = tester.getRect(
          find.byType(DropdownButtonFormField<String?>),
        );
        expect(dropdown.right, lessThanOrEqualTo(width));
      });
    }
  }
}
