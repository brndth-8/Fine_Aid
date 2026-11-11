import 'package:flutter/material.dart';
import '../../i18n/registration_strings.dart';

/// Under 18: the supervision notice, which can only be closed with its one
/// button. True once acknowledged. The same notice Sign Up shows.
Future<bool> showUnderageNotice(BuildContext context) async {
  final s = RegistrationStrings.of(context);
  final acknowledged = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.underageTitle),
        content: SingleChildScrollView(child: Text(s.underageBody)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.underageButton),
          ),
        ],
      ),
    ),
  );
  return acknowledged == true;
}
