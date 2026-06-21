import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TermsScreen extends StatefulWidget {
  final bool readOnly;

  const TermsScreen({super.key, this.readOnly = false});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isLoading = false;

  Future<void> _handleAgree() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'termsAccepted': true,
              'termsAcceptedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      Navigator.pushNamed(context, '/permission');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your acceptance. Please try again.'),
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
        child: Padding(
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
              Text(
                'Terms & Conditions',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Disclaimer',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This application uses Artificial Intelligence (AI) to provide '
                          'initial First Aid guidance only. It is not a diagnostic tool and '
                          'does not provide a definitive medical opinion.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NOT A SUBSTITUTE FOR PROFESSIONAL CARE',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'I understand that the visual and textual information provided is '
                          'an educational tool designed to improve my health literacy. I am '
                          'solely responsible for the final decisions I make regarding my '
                          'health care, including when to seek a medical professional.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'By continuing, you agree to use this application as a guide only '
                          'and assume all responsibility for any actions taken based on its '
                          'content.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              if (widget.readOnly)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Back'),
                )
              else
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAgree,
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
                      : const Text('I Agree & Continue'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
