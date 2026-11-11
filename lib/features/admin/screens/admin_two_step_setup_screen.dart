import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin_two_step.dart';
import '../theme/admin_theme.dart';
import 'admin_login_screen.dart';

/// Shown when admins must sign in with an authenticator code but this admin
/// hasn't set one up yet. It is the only thing they can reach: the rules and
/// Cloud Functions refuse everything else until they sign in with a code.
/// After setting it up they sign out and sign in again, this time with a code.
class AdminTwoStepSetupScreen extends StatefulWidget {
  const AdminTwoStepSetupScreen({super.key});

  @override
  State<AdminTwoStepSetupScreen> createState() =>
      _AdminTwoStepSetupScreenState();
}

class _AdminTwoStepSetupScreenState extends State<AdminTwoStepSetupScreen> {
  bool _busy = false;

  Future<void> _backToLogin(String? notice) async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AdminLoginScreen(notice: notice)),
      (_) => false,
    );
  }

  Future<void> _setUp() async {
    if (_busy) return;
    setState(() => _busy = true);
    final enrolled = await showAuthenticatorSetup(context);
    if (!mounted) return;
    if (enrolled) {
      await _backToLogin(
        'Authenticator app set up. Sign in again and enter the code from '
        'your app.',
      );
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 40,
                      color: AdminTheme.maroon,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set up two-step verification',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Admins now sign in with a 6-digit code from an '
                      'authenticator app as well as their password. Set it up '
                      'once; it takes about a minute. You will not be able to '
                      'use the admin portal until you do.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.maroon,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _busy ? null : _setUp,
                      child: const Text('Set up authenticator app'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => _backToLogin(null),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
