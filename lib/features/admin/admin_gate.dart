import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firebase/auth_service.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_landing_screen.dart';

/// Routes to the admin login or dashboard depending on auth + admin status.
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
          return const AdminLandingScreen();
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

            // Not an admin — sign out and show landing
            AuthService().signOut();
            return const AdminLandingScreen();
          },
        );
      },
    );
  }
}
