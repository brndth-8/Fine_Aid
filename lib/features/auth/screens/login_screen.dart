import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/offline_entry_dialog.dart';
import '../../../i18n/screen_text_strings.dart';

class LoginScreen extends StatelessWidget {
  /// Replaces the internet check (tests).
  final Future<bool> Function()? isOnline;

  const LoginScreen({super.key, this.isOnline});

  /// Log In, Create Account and Continue as Guest check the connection first:
  /// with no internet the offline prompt comes first, and only "Proceed to
  /// Offline Mode" lets the person in (as a guest, with the offline features).
  void _enter(BuildContext context, String route) {
    enterOnlineOrOffline(
      context,
      isOnline: isOnline,
      onOnline: () {
        if (context.mounted) Navigator.pushNamed(context, route);
      },
      onOffline: () {
        if (context.mounted) Navigator.pushNamed(context, '/dashboard');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The design is light (a white page with red waves), so this screen always
    // uses the light theme, even when the phone is in dark mode.
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_background_maroon.png',
                    fit: BoxFit.cover,
                    alignment: isWide
                        ? Alignment.center
                        : Alignment.bottomCenter,
                  ),
                ),

                // Slight overlay helps buttons stay readable on wide backgrounds
                if (isWide)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
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
                                        _buildButtons(context, 260),
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
                                _buildButtons(
                                  context,
                                  constraints.maxWidth * 0.72,
                                ),
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
          ScreenText.of(context).tagline,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF780000)),
        ),
      ],
    );
  }

  // Log In (filled), Create Account (outlined), a divider, then Continue as
  // Guest (grey): all pill-shaped with bold labels, [width] wide.
  Widget _buildButtons(BuildContext context, double width) {
    final theme = Theme.of(context);
    const maroon = Color(0xFF8B0000);
    // Bold 16, as in the design.
    final label = theme.textTheme.titleLarge;
    const height = Size(double.infinity, 44);

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _enter(context, '/login-form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              minimumSize: height,
              shape: const StadiumBorder(),
              textStyle: label,
            ),
            child: Text(ScreenText.of(context).logIn),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _enter(context, '/registration'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: maroon,
              side: const BorderSide(color: maroon, width: 1.5),
              minimumSize: height,
              shape: const StadiumBorder(),
              textStyle: label,
            ),
            child: Text(ScreenText.of(context).createAccount),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ScreenText.of(context).or,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _enter(context, '/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCCCCC),
              foregroundColor: const Color(0xFF333333),
              elevation: 0,
              minimumSize: height,
              shape: const StadiumBorder(),
              textStyle: label,
            ),
            child: Text(ScreenText.of(context).continueAsGuest),
          ),
        ],
      ),
    );
  }
}
