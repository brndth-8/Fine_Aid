import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/registration_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/confirmation_screen.dart';
import 'features/auth/screens/terms_screen.dart';
import 'features/auth/screens/permission_screen.dart';
import 'features/auth/screens/health_checklist_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'services/firebase/auth_service.dart';
import 'features/auth/screens/login_form_screen.dart';
import 'services/firebase/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
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
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/login-form': (context) => const LoginFormScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/otp': (context) => const OtpScreen(),
        '/confirmation': (context) => const ConfirmationScreen(),
        '/terms': (context) => const TermsScreen(),
        '/permission': (context) => const PermissionScreen(),
        '/health-checklist': (context) => const HealthChecklistScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: AuthService().hasCompletedOnboarding(user.uid),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Default to true if check failed (e.g. offline with no cache)
            // so existing logged-in users always reach the Dashboard.
            final completed = onboardingSnapshot.data ?? true;
            if (completed) {
              return const DashboardScreen();
            }
            return const OtpScreen();
          },
        );
      },
    );
  }
}
