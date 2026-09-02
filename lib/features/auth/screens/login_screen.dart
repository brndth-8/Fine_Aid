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
                  'assets/images/FINE_AID_Background.png',
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
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 360 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 22,
                          right: 22,
                          top: isWide ? 0 : 280,
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
                                  child: _buildButtons(context),
                                ),
                              )
                            else
                              _buildButtons(context),
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
            child: const Text('Log In', style: TextStyle(fontSize: 12)),
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
            child: const Text('Create Account', style: TextStyle(fontSize: 12)),
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
            child: const Text(
              'Continue as Guest',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
