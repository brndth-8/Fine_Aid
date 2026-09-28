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
  final ScrollController _scrollController = ScrollController();
  // Only actually gates anything when !readOnly (the real acceptance flow);
  // the read-only "view terms later" variant just has a Back button, so
  // there's nothing to unlock there.
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // If the content already fits on screen without scrolling (a tall
    // device, small text scale), there's nothing to scroll TO — don't
    // leave the button permanently disabled in that case. Checked after
    // the first layout, once maxScrollExtent is actually known.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atEnd = position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 24;
    if (atEnd && !_hasScrolledToEnd) {
      setState(() => _hasScrolledToEnd = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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

  Widget _sectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _paragraph(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _bulletList(ThemeData theme, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(theme, 'Medical Disclaimer'),
                          _paragraph(
                            theme,
                            'This application uses Artificial Intelligence (AI) to provide '
                            'initial First Aid guidance only. It is not a diagnostic tool and '
                            'does not provide a definitive medical opinion. Please read these '
                            'carefully before using our mobile application and services.',
                          ),
                          _sectionHeader(theme, '1. Acceptance of Terms'),
                          _paragraph(
                            theme,
                            'By downloading, installing, or using this App, you agree to be '
                            'bound by these Terms.',
                          ),
                          _sectionHeader(
                            theme,
                            '2. No Medical Advice Disclaimer',
                          ),
                          _bulletList(theme, const [
                            'Information Only: All content provided within the App is '
                                'for informational purposes only.',
                            'No Doctor-Patient Relationship: Use of this App does not '
                                'create a doctor-patient relationship.',
                            'Consult Professionals: The App is not a substitute for '
                                'professional medical advice or diagnosis. Always seek the '
                                'advice of your physician or other qualified healthcare '
                                'provider with any questions you may have regarding a '
                                'medical condition.',
                          ]),
                          _sectionHeader(theme, '3. Emergency Disclaimer'),
                          _bulletList(theme, const [
                            'Do Not Use for Emergencies: This App is NOT to be used for '
                                'medical emergencies.',
                            'Emergency Action: If you are experiencing a medical '
                                'emergency, call emergency services or go to the nearest '
                                'hospital emergency room immediately.',
                          ]),
                          _sectionHeader(theme, '4. Privacy and Data Security'),
                          _bulletList(theme, const [
                            'Privacy Policy: Your use of the App is also governed by our '
                                'Privacy Policy.',
                            'Data Compliance: We handle data in accordance with '
                                'applicable laws, including the Data Privacy Act of 2012 '
                                '(Republic Act No. 10173) and other relevant health '
                                'privacy regulations.',
                          ]),
                          _sectionHeader(
                            theme,
                            '5. Permitted Use and Restrictions',
                          ),
                          _paragraph(theme, 'You agree not to:'),
                          _bulletList(theme, const [
                            'Use the App for any illegal purpose.',
                            'Input false, misleading, or inaccurate health data.',
                            'Attempt to hack, reverse-engineer, or disrupt the App\'s '
                                'servers and networks.',
                          ]),
                          Text(
                            'By continuing, you agree to use this application as a guide '
                            'only and assume all responsibility for any actions taken '
                            'based on its content.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (!widget.readOnly && !_hasScrolledToEnd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Please scroll to the end to continue.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
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
                  onPressed: (_isLoading || !_hasScrolledToEnd)
                      ? null
                      : _handleAgree,
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
