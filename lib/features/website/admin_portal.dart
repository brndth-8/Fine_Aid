import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import '../admin/admin_gate.dart';
import '../admin/theme/admin_theme.dart';

/// Loaded as a deferred library by the website so that neither the admin
/// screens nor the Firebase SDK ship in the public landing page bundle.
Future<void> initAdmin() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Widget buildAdminPortal() {
  return Title(
    title: 'Fine Aid Admin Portal',
    color: AdminTheme.maroon,
    child: Theme(data: AdminTheme.theme, child: const AdminGate()),
  );
}
