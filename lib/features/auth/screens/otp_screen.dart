import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/api/semaphore_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String? _phoneNumber;
  String? _verificationMethod;
  String? _otpError;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _phoneNumber = doc.data()?['phoneNumber'] as String?;
          _verificationMethod =
              doc.data()?['verificationMethod'] as String? ?? 'email';
        });
      }

      debugPrint(
        'OTP: method=$_verificationMethod '
        'phone=$_phoneNumber',
      );

      if (_verificationMethod == 'phone' && _phoneNumber != null) {
        await _sendOtp();
      }
    } catch (e) {
      debugPrint('OTP loadUserInfo error: $e');
      if (mounted) {
        setState(() => _otpError = 'Could not load account info: $e');
      }
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber == null) {
      setState(() => _otpError = 'No phone number found for this account.');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    final success = await SemaphoreService().sendOtp(
      phoneNumber: _phoneNumber!,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startResendCooldown();
      } else {
        setState(() {
          _isLoading = false;
          _otpError =
              'Failed to send OTP. Please check your '
              'phone number and try again.';
        });
      }
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _handleSubmit() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    final result = await SemaphoreService().verifyOtp(code: code);

    if (!mounted) return;

    switch (result) {
      case OtpVerificationResult.success:
        await SemaphoreService().clearOtp();
        if (mounted) Navigator.pushNamed(context, '/terms');
        break;
      case OtpVerificationResult.invalid:
        setState(() {
          _isLoading = false;
          _otpError = 'Incorrect code. Please try again.';
        });
        break;
      case OtpVerificationResult.expired:
        setState(() {
          _isLoading = false;
          _otpError = 'Code has expired. Please request a new one.';
          _codeSent = false;
        });
        break;
      case OtpVerificationResult.tooManyAttempts:
        setState(() {
          _isLoading = false;
          _otpError =
              'Too many failed attempts. '
              'Please request a new code.';
          _codeSent = false;
        });
        break;
      case OtpVerificationResult.notFound:
      case OtpVerificationResult.error:
        setState(() {
          _isLoading = false;
          _otpError = 'Verification failed. Please try again.';
        });
        break;
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhoneMethod = _verificationMethod == 'phone';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/images/FINE_AID_Logo.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OTP Verification',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPhoneMethod
                              ? _codeSent
                                    ? 'Enter the OTP sent '
                                          'to $_phoneNumber'
                                    : _isLoading
                                    ? 'Sending OTP to '
                                          '$_phoneNumber...'
                                    : _otpError != null
                                    ? 'Tap Resend OTP '
                                          'to try again.'
                                    : 'Preparing to '
                                          'send OTP...'
                              : 'You chose email '
                                    'verification. Check your '
                                    'email for a verification '
                                    'link, then tap Continue.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),

                        if (isPhoneMethod && _codeSent) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              6,
                              (index) => SizedBox(
                                width: 44,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  enabled: !_isLoading,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                  ),
                                  onChanged: (value) =>
                                      _onDigitChanged(index, value),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_isLoading && !_codeSent) ...[
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 16),
                        ],

                        if (_otpError != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _otpError!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : isPhoneMethod
                              ? (_codeSent ? _handleSubmit : null)
                              : () => Navigator.pushNamed(context, '/terms'),
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
                              : Text(isPhoneMethod ? 'Submit' : 'Continue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Resend button
              if (isPhoneMethod)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    onPressed:
                        (_isResending || _resendCooldown > 0 || _isLoading)
                        ? null
                        : () async {
                            setState(() {
                              _isResending = true;
                              _codeSent = false;
                              _otpError = null;
                            });
                            for (final c in _controllers) {
                              c.clear();
                            }
                            await _sendOtp();
                            if (mounted) {
                              setState(() => _isResending = false);
                            }
                          },
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend OTP in '
                                '${_resendCooldown}s'
                          : "Didn't receive the OTP? "
                                'Resend',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
