import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firebase/auth_service.dart';
import 'admin_access.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_landing_screen.dart';
import 'screens/admin_two_step_setup_screen.dart';

enum _Access { yes, no, needsTwoStep }

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
        return FutureBuilder<_Access>(
          // Listed in `admins` AND carrying the server-set admin claim. The
          // token is refreshed so a session that started before the claim
          // was granted picks it up. When admins must use an authenticator
          // code, a sign-in without one only gets the set-up screen.
          future: AuthService().isAdmin(user.uid).then((listed) async {
            if (!listed || !await hasAdminClaim(user)) return _Access.no;
            return await twoStepSatisfied(user)
                ? _Access.yes
                : _Access.needsTwoStep;
          }),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final access = adminSnapshot.data ?? _Access.no;

            if (access == _Access.yes) {
              return const AdminDashboardScreen();
            }
            if (access == _Access.needsTwoStep) {
              return const AdminTwoStepSetupScreen();
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
