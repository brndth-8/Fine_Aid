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
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
        '/admin-login': (context) => const AdminLoginScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, bool>>? _statusFuture;
  String? _lastUid;

  Future<Map<String, bool>> _checkUserStatus(String uid) async {
    final results = await Future.wait([
      AuthService().isAdmin(uid),
      AuthService().hasCompletedOnboarding(uid),
    ]);
    return {'isAdmin': results[0], 'onboardingComplete': results[1]};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _statusFuture = _checkUserStatus(user.uid);
        }

        return FutureBuilder<Map<String, bool>>(
          future: _statusFuture,
          builder: (context, statusSnapshot) {
            if (statusSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }
            if (statusSnapshot.hasError) {
              debugPrint('AuthGate error: ${statusSnapshot.error}');
              return const LoginScreen();
            }

            final status = statusSnapshot.data;
            final isAdmin = status?['isAdmin'] ?? false;
            final onboardingComplete = status?['onboardingComplete'] ?? true;

            debugPrint(
              'AuthGate — uid: ${user.uid}, '
              'isAdmin: $isAdmin, '
              'onboardingComplete: $onboardingComplete',
            );

            if (isAdmin) return const AdminDashboardScreen();
            if (onboardingComplete) return const DashboardScreen();
            return const OtpScreen();
          },
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
