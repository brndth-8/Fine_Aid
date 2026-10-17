import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Fine_Aid_BG.png',
                  fit: BoxFit.cover,
                  alignment: isWide ? Alignment.center : Alignment.bottomCenter,
                ),
              ),

              // Slight overlay helps buttons stay readable on wide backgrounds
              if (isWide)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
                ),

              SafeArea(
                child: Align(
                  alignment: isWide ? Alignment.center : Alignment.topCenter,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 360 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 22,
                          right: 22,
                          top: 0,
                          bottom: isWide ? 0 : 45,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isWide
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.end,
                          children: [
                            if (isWide)
                              Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildLogo(context, 240),
                                      const SizedBox(height: 24),
                                      _buildButtons(context),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              SizedBox(height: constraints.maxHeight * 0.16),
                              _buildLogo(
                                context,
                                math.min(300, constraints.maxWidth * 0.78),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.14),
                              _buildButtons(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // The FineAid logo with its tagline.
  Widget _buildLogo(BuildContext context, double width) {
    return Column(
      children: [
        Image.asset('assets/images/FINE_AID_Logo.png', width: width),
        const SizedBox(height: 4),
        Text(
          'Your Smart First-Aid Assistance',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF780000)),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login-form');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Log In',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/registration');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B0000),
              side: const BorderSide(color: Color(0xFF8B0000)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Create Account',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Row(
          children: [
            Expanded(child: Divider(color: Colors.grey)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or', style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider(color: Colors.grey)),
          ],
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/dashboard');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B0000),
              side: const BorderSide(color: Color(0xFF8B0000)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Continue as Guest',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
