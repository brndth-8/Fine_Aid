import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_login_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'services/firebase/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fine Aid Admin Portal',
      theme: AppTheme.lightTheme,
      home: const AdminGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

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
          return const AdminLoginScreen();
        }

        // Check if logged-in user is actually admin
        return FutureBuilder<bool>(
          future: AuthService().isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isAdmin = adminSnapshot.data ?? false;

            if (isAdmin) {
              return const AdminDashboardScreen();
            }

            // Not an admin — sign out and show login
            AuthService().signOut();
            return const AdminLoginScreen();
          },
        );
      },
    );
  }
}
