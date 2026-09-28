import 'package:flutter/material.dart';
import 'admin_login_screen.dart';

class AdminLandingScreen extends StatelessWidget {
  const AdminLandingScreen({super.key});

  static const _accentColor = Color(0xFF8B0000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/admin_landing_background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          'Welcome To,',
                          style: TextStyle(
                            fontSize: isWide ? 32 : 24,
                            fontWeight: FontWeight.w700,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/FINE_AID_Logo.png',
                                  width: isWide ? 380 : 260,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your Smart First Aid Assistant',
                                  style:
                                      (isWide
                                              ? Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge
                                              : Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium)
                                          ?.copyWith(
                                            color: _accentColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                ),
                                SizedBox(height: isWide ? 56 : 40),
                                SizedBox(
                                  width: isWide ? 280 : 220,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminLoginScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _accentColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      'Get Started',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
