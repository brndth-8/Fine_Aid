import 'package:flutter/material.dart';
import '../../i18n/screen_text_strings.dart';

/// Shown when a guest (not registered or logged in) tries to save
/// something to the Health Journal. Offers Register/Log in, plus an
/// explicit dismiss — nothing is saved either way.
Future<void> showGuestSaveGateDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Save to Health Journal'),
      content: Text(ScreenText.of(context).guestSaveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(ScreenText.of(context).notNow),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/registration');
          },
          child: Text(ScreenText.of(context).register),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/login-form');
          },
          child: Text(ScreenText.of(context).logIn),
        ),
      ],
    ),
  );
}

/// Shown when a guest hits the daily AI Cam / follow-up-question usage
/// limit (see GuestUsageService). Blocks the action that triggered it.
Future<void> showGuestUsageLimitDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Today's Limit Reached"),
      content: Text(ScreenText.of(context).guestLimitBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(ScreenText.of(context).ok),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/registration');
          },
          child: Text(ScreenText.of(context).register),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/login-form');
          },
          child: Text(ScreenText.of(context).logIn),
        ),
      ],
    ),
  );
}
