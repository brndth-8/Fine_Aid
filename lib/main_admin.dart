import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/admin/theme/admin_theme.dart';
import 'features/admin/admin_gate.dart';

/// Standalone admin entry point (local development).
/// In production the admin module is served by lib/main_web.dart behind the
/// secret path — see docs/website_hosting.md.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fine Aid Admin Portal',
      theme: AdminTheme.theme,
      home: const AdminGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
