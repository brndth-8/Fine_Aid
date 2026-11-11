import 'package:flutter/material.dart';

/// A round pink badge holding one icon: the look shared by the app's
/// pop-ups ("Professional care recommended", "No Internet Connection").
class PopupBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const PopupBadge({
    super.key,
    required this.icon,
    this.color = const Color(0xFF7A0000),
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF8D7DA),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// White rounded pop-up: [badge] on top, a bold maroon [title], the [body]
/// widgets, then one maroon pill button. Tapping the button closes it.
///
/// Used for the Health Journal's "Professional care recommended" and offline
/// notices. [dismissible] false means only the button closes it.
Future<void> showIconPopup(
  BuildContext context, {
  required Widget badge,
  required String title,
  required List<Widget> body,
  required String buttonLabel,
  bool dismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return PopScope(
        canPop: dismissible,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  badge,
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF7A0000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...body,
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(buttonLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
