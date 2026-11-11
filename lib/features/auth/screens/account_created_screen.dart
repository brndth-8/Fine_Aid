import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../i18n/registration_strings.dart';

/// Shown once after a successful sign-up, before the verification step: the
/// account exists and is signed in. Continue goes back to the root, where
/// AuthGate takes the person to verification.
class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = RegistrationStrings.of(context);
    // Designed on a light background, so it stays light in dark mode too.
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFE7E7E7),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 110),
                    const SizedBox(height: 32),
                    const _CheckBadge(),
                    const SizedBox(height: 32),
                    Text(
                      s.accountCreatedTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppTheme.darkMaroon,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.accountCreatedBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF040504),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(s.continueButton),
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

/// A check mark in a pink circle with a few confetti shapes around it.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _ConfettiPainter(),
        child: Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFF4B8B8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppTheme.darkMaroon,
              size: 52,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final colors = [
      const Color(0xFFF4B8B8),
      AppTheme.mutedRose,
      AppTheme.darkMaroon,
    ];
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + (i.isEven ? 0 : math.pi / 12);
      final radius = i.isEven ? 68.0 : 58.0;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()..color = colors[i % colors.length];
      if (i % 3 == 0) {
        canvas.drawCircle(p, 3.5, paint);
      } else {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -2, 10, 4),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
