import 'package:flutter/material.dart';
import '../password_requirements.dart';

/// The live "At least 8 characters / 1 uppercase / …" list shown under a
/// new-password field (Sign Up and Edit Profile).
class PasswordChecklist extends StatelessWidget {
  final String password;
  const PasswordChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final requirement in passwordRequirements)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  requirement.isMet(password)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: requirement.isMet(password)
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  requirement.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: requirement.isMet(password)
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
