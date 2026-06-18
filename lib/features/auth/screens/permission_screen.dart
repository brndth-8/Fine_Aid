import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _allowCamera = false;
  bool _skipForNow = false;
  bool _isLoading = false;

  Future<void> _saveCameraPreference(bool granted) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'cameraPermissionGranted': granted})
          .timeout(const Duration(seconds: 10));
    }
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      bool granted = false;

      if (_allowCamera && !_skipForNow) {
        final status = await Permission.camera.request();
        granted = status.isGranted;

        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Camera permission was not granted. You can enable it later in Settings.',
              ),
            ),
          );
        }
      }

      await _saveCameraPreference(granted);

      if (!mounted) return;
      Navigator.pushNamed(context, '/health-checklist');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      'Camera Access Required',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'To provide accurate first aid guidance, this application needs to '
                      'use your camera for AI-powered scanning. Your camera will only be '
                      'active when you are using the scanning feature.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Why is this needed?',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The camera allows the AI to analyze visible injuries and skin '
                      'condition to provide real-time, data-driven insights to assist in '
                      'your decision-making.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Privacy & Safety', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      'In accordance with the Data Privacy Act and responsible AI '
                      'frameworks, images are used only for assessment and are not shared '
                      'without your explicit consent.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _allowCamera,
                      onChanged: (value) => setState(() {
                        _allowCamera = value ?? false;
                        if (_allowCamera) _skipForNow = false;
                      }),
                      title: const Text(
                        'I allow the app to access my camera for medical literacy and assessment purposes.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _skipForNow,
                      onChanged: (value) => setState(() {
                        _skipForNow = value ?? false;
                        if (_skipForNow) _allowCamera = false;
                      }),
                      title: const Text('Skip for now'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || (!_allowCamera && !_skipForNow))
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
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
