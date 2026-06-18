import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthChecklistScreen extends StatefulWidget {
  const HealthChecklistScreen({super.key});

  @override
  State<HealthChecklistScreen> createState() => _HealthChecklistScreenState();
}

class _HealthChecklistScreenState extends State<HealthChecklistScreen> {
  bool _diabetes = false;
  bool _hemophilia = false;
  bool _severeAllergies = false;
  bool _noneOfTheAbove = false;
  bool _isLoading = false;

  void _toggleNoneOfTheAbove(bool? value) {
    setState(() {
      _noneOfTheAbove = value ?? false;
      if (_noneOfTheAbove) {
        _diabetes = false;
        _hemophilia = false;
        _severeAllergies = false;
      }
    });
  }

  void _toggleCondition(void Function(bool) setter, bool? value) {
    setState(() {
      setter(value ?? false);
      if (value == true) _noneOfTheAbove = false;
    });
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'healthProfile': {
                'diabetes': _diabetes,
                'hemophiliaOrBloodDisorders': _hemophilia,
                'severeAllergies': _severeAllergies,
                'noneOfTheAbove': _noneOfTheAbove,
              },
              'healthProfileSavedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      Navigator.pushNamed(context, '/onboarding');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your health profile. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _conditionTile({
    required String title,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: theme.textTheme.titleSmall),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canContinue =
        _diabetes || _hemophilia || _severeAllergies || _noneOfTheAbove;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text('Health Profile', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'To provide the effective medical assistance, we need to understand your '
                'health profile. Certain conditions can significantly affect how your body '
                'responds to injuries and the specific clinical protocols required for '
                'immediate care.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _conditionTile(
                title: 'Diabetes',
                value: _diabetes,
                onChanged: (v) => _toggleCondition((val) => _diabetes = val, v),
              ),
              _conditionTile(
                title: 'Hemophilia or Blood Disorders',
                value: _hemophilia,
                onChanged: (v) =>
                    _toggleCondition((val) => _hemophilia = val, v),
              ),
              _conditionTile(
                title: 'Severe Allergies',
                value: _severeAllergies,
                onChanged: (v) =>
                    _toggleCondition((val) => _severeAllergies = val, v),
              ),
              _conditionTile(
                title:
                    "I don't have any of the listed conditions (Provide Standard Clinical Protocols)",
                value: _noneOfTheAbove,
                onChanged: _toggleNoneOfTheAbove,
              ),
              const SizedBox(height: 12),
              Text('Privacy & Data Use:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                'In accordance with the Data Privacy Act, your personal information is '
                'stored securely only on your device and is not shared with anyone without '
                'your explicit consent.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || !canContinue)
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
