import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../i18n/notification_strings.dart';

/// "Remind me" — turns on the healing check-in reminder for the entry being
/// saved. Not shown to guests (they get no notifications).
class RemindMeCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const RemindMeCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final text = NotificationStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(
          text.remindMeTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(text.remindMeSubtitle),
      ),
    );
  }
}
