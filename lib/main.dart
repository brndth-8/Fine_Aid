import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/text_scale_controller.dart';
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
import 'services/notification_inbox_store.dart';
import 'core/navigation/app_navigator.dart';
import 'core/widgets/global_offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Explicit (matches the mobile default, but stated outright): local
  // writes — journal entries, first aid saves, follow-up conversations —
  // resolve instantly from an on-device cache and sync automatically once
  // connectivity returns, with no separate sync-queue code needed.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Notification setup touches FCM (a network call) — timed out and
  // swallowed so a slow or absent connection at first launch never leaves
  // the app stuck before its first frame even paints.
  try {
    await NotificationService().initialize().timeout(
      const Duration(seconds: 8),
    );
  } catch (e) {
    debugPrint('NotificationService.initialize failed/timed out: $e');
  }
  await TextScaleController.instance.load();
  // Local-only and fast — loads before first frame so the notification
  // bell's unread badge is correct immediately, not just after the
  // Notifications screen has been opened once.
  await NotificationInboxStore.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TextScaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Fine Aid',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          // Applies the Personalization > Text Size setting app-wide,
          // instantly, on top of whatever the device's own system text
          // scale already is.
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final deviceScale = mediaQuery.textScaler.scale(1.0);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  deviceScale * TextScaleController.instance.scale,
                ),
              ),
              child: GlobalOfflineBanner(child: child!),
            );
          },
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
  String? _lastUid;

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
          if (_lastUid != null) {
            _lastUid = null;
            NotificationService().stopListeningForSystemAnnouncements();
          }
          return const LoginScreen();
        }

        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          NotificationService().listenForSystemAnnouncements();
        }

        return FutureBuilder<Map<String, bool>>(
          future: AuthService().fetchOnboardingFlags(user.uid),
          builder: (context, statusSnapshot) {
            if (statusSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final flags = statusSnapshot.data;

            // Already fully onboarded (the common case on every normal
            // login) — go straight to the app.
            if (flags?['onboardingComplete'] == true) {
              return const DashboardScreen();
            }

            // Otherwise resume at whichever step genuinely has not been
            // completed yet, instead of restarting the whole setup flow
            // (eg, re-sending an OTP the user already verified) every
            // time the app is reopened mid-setup.
            if (flags?['phoneVerified'] != true) return const OtpScreen();
            if (flags?['termsAccepted'] != true) return const TermsScreen();
            if (flags?['permissionStepComplete'] != true) {
              return const PermissionScreen();
            }
            if (flags?['healthProfileComplete'] != true) {
              return const HealthChecklistScreen();
            }
            return const DashboardScreen();
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
