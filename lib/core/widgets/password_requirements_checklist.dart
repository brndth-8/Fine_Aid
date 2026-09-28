import 'package:flutter/material.dart';
import '../password_requirements.dart';

/// Live checklist of password requirements, ticking off each one as the
/// user types — rebuild this on every keystroke of the password field
/// (eg via `AnimatedBuilder`/`ValueListenableBuilder` on the controller,
/// or a parent `setState` in `onChanged`).
class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;
  const PasswordRequirementsChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final requirement in passwordRequirements)
          _requirementRow(theme, requirement.label, requirement.isMet(password)),
        if (password.isNotEmpty)
          _requirementRow(
            theme,
            'Not a commonly used password',
            !isCommonPassword(password),
          ),
      ],
    );
  }

  Widget _requirementRow(ThemeData theme, String label, bool met) {
    final color = met ? Colors.green.shade700 : Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
