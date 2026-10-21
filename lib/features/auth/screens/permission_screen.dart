import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../i18n/permission_strings.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _allowCamera = false;
  bool _isLoading = false;

  // Set once the camera was asked for and refused. The message and the
  // "Open Settings" button show; pressing Continue again then moves on
  // (the choice is saved as "not granted"), so a refusal never loops.
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's Settings: if the camera was switched on there, the
  // "denied" message is no longer true.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_denied) return;
    Permission.camera.status.then((status) {
      if (mounted && status.isGranted) setState(() => _denied = false);
    });
  }

  Future<void> _saveCameraPreference(bool granted) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'cameraPermissionGranted': granted,
            'permissionStepComplete': true,
          })
          .timeout(const Duration(seconds: 10));
    }
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final status = await Permission.camera.request();
      final granted = status.isGranted;

      if (!granted && !_denied) {
        // First refusal: stay here and explain how to turn it on.
        if (mounted) setState(() => _denied = true);
        return;
      }
      if (granted && _denied && mounted) setState(() => _denied = false);

      await _saveCameraPreference(granted);

      if (!mounted) return;
      Navigator.pushNamed(context, '/health-checklist');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PermissionStrings.of(context).genericError)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = PermissionStrings.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  'assets/images/FINE_AID_Logo.png',
                  width: 160,
                  height: 160,
                ),
              ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(s.intro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Text(s.whyTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(s.why, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Text(s.privacyTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(s.privacy, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _allowCamera,
                      onChanged: (value) =>
                          setState(() => _allowCamera = value ?? false),
                      title: Text(s.allowCamera),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              if (_denied) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.deniedMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: openAppSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(s.openSettings),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || !_allowCamera)
                    ? null
                    : _handleContinue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.continueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
