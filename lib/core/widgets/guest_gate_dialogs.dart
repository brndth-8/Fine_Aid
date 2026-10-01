import 'package:flutter/material.dart';

/// Shown when a guest (not registered or logged in) tries to save
/// something to the Health Journal. Offers Register/Log in, plus an
/// explicit dismiss — nothing is saved either way.
Future<void> showGuestSaveGateDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Save to Health Journal'),
      content: const Text('You need to register or log in to save this entry.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/registration');
          },
          child: const Text('Register'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/login-form');
          },
          child: const Text('Log in'),
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
      content: const Text(
        "You've reached today's limit for guests. Register or log in for "
        'unlimited use, or try again tomorrow.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/registration');
          },
          child: const Text('Register'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).pushNamed('/login-form');
          },
          child: const Text('Log in'),
        ),
      ],
    ),
  );
}
