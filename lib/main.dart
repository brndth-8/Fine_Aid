import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/registration_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/confirmation_screen.dart';
import 'features/auth/screens/terms_screen.dart';
import 'features/auth/screens/permission_screen.dart';
import 'features/auth/screens/health_checklist_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fine Aid',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/otp': (context) => const OtpScreen(),
        '/confirmation': (context) => const ConfirmationScreen(),
        '/terms': (context) => const TermsScreen(),
        '/permission': (context) => const PermissionScreen(),
        '/health-checklist': (context) => const HealthChecklistScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
