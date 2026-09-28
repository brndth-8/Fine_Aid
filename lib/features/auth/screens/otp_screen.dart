import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../services/api/semaphore_service.dart';
import '../../../services/firebase/auth_service.dart';
import 'package:flutter/services.dart';

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
  String? _recoveryEmail;
  String? _verificationMethod;
  String? _otpError;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  bool _isSigningOut = false;
  bool _isEditingPhone = false;

  bool get _isPhoneMethod => _verificationMethod == 'phone';
  bool get _isEmailMethod => _verificationMethod == 'email';

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
          _recoveryEmail = doc.data()?['recoveryEmail'] as String?;
          // Every account before today's email-verification option was
          // always phone-verified, so that's the correct default for any
          // account missing this field — not 'email', which would send a
          // real code to a recoveryEmail these older accounts don't have.
          _verificationMethod =
              doc.data()?['verificationMethod'] as String? ?? 'phone';
        });
      }

      debugPrint(
        'OTP: method=$_verificationMethod '
        'phone=$_phoneNumber',
      );

      if (_isPhoneMethod && _phoneNumber != null) {
        await _sendOtp();
      } else if (_isEmailMethod && _recoveryEmail != null) {
        await _sendEmailOtp();
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

  Future<void> _sendEmailOtp() async {
    if (_recoveryEmail == null) {
      setState(() => _otpError = 'No email address found for this account.');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendAccountVerificationOtpEmail')
          .call();
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      _startResendCooldown();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError =
            e.message ?? 'Failed to send the code. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = 'Failed to send the code. Please try again.';
      });
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

  // This step is reached by AuthGate re-routing to OtpScreen directly
  // (not a Navigator push), so there's no previous route to pop back to.
  // Just signing out would leave the half-registered account (and its
  // username reservation) behind — the user would land on a blank Create
  // Account form but immediately get "username already taken" if they try
  // the same one again. So "back" here means abandon this registration
  // outright: delete the never-verified auth user, its profile doc, and
  // release the username, then go to a genuinely fresh Create Account
  // screen. The account is only ever this incomplete for the few seconds
  // between registering and verifying, so this is always safe to discard.
  Future<void> _handleBack() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final username = profileDoc.data()?['username'] as String?;
        if (username != null && username.trim().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usernames')
              .doc(username.trim().toLowerCase())
              .delete();
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        await user.delete();
      } catch (e) {
        debugPrint('OTP back: could not fully clean up, signing out: $e');
        await AuthService().signOut();
      }
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/registration', (route) => false);
  }

  Future<void> _handleEditPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: _phoneNumber ?? '');
    final newNumber = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
          ],
          decoration: const InputDecoration(
            hintText: 'e.g. 09171234567',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save & Resend'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newNumber == null || newNumber.isEmpty || newNumber == _phoneNumber) {
      return;
    }

    setState(() {
      _isEditingPhone = true;
      _otpError = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'phoneNumber': newNumber})
          .timeout(const Duration(seconds: 10));

      for (final c in _controllers) {
        c.clear();
      }
      _cooldownTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _phoneNumber = newNumber;
        _codeSent = false;
        _resendCooldown = 0;
      });
      await _sendOtp();
    } catch (e) {
      debugPrint('OTP edit phone number error: $e');
      if (mounted) {
        setState(() {
          _otpError = 'Could not update phone number. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isEditingPhone = false);
    }
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

    if (_isEmailMethod) {
      await _handleSubmitEmail(code);
      return;
    }

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

  Future<void> _handleSubmitEmail(String code) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyAccountVerificationOtp')
          .call({'code': code});
      if (!mounted) return;
      Navigator.pushNamed(context, '/terms');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final expiredOrExhausted =
          e.code == 'deadline-exceeded' || e.code == 'resource-exhausted';
      setState(() {
        _isLoading = false;
        _otpError = e.message ?? 'Verification failed. Please try again.';
        if (expiredOrExhausted) _codeSent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = 'Verification failed. Please try again.';
      });
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
    final isPhoneMethod = _isPhoneMethod;
    final hasCodeFlow = _isPhoneMethod || _isEmailMethod;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_back_ios, size: 18),
                    tooltip: 'Back',
                    onPressed: _isSigningOut ? null : _handleBack,
                  ),
                ],
              ),
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
                              : _isEmailMethod
                              ? _codeSent
                                    ? 'Enter the code sent '
                                          'to $_recoveryEmail'
                                    : _isLoading
                                    ? 'Sending a code to '
                                          '$_recoveryEmail...'
                                    : _otpError != null
                                    ? 'Tap Resend to try again.'
                                    : 'Preparing to send a code...'
                              : 'Preparing to verify your account...',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (isPhoneMethod && !_isEditingPhone)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _isLoading || _isResending
                                  ? null
                                  : _handleEditPhoneNumber,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Wrong number? Edit'),
                            ),
                          ),
                        if (_isEditingPhone)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Updating phone number...'),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        if (hasCodeFlow && _codeSent) ...[
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
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
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
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.red.shade700),
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
                              : hasCodeFlow
                              ? (_codeSent ? _handleSubmit : null)
                              : null,
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
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Resend button
              if (hasCodeFlow)
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
                            if (isPhoneMethod) {
                              await _sendOtp();
                            } else {
                              await _sendEmailOtp();
                            }
                            if (mounted) {
                              setState(() => _isResending = false);
                            }
                          },
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend code in '
                                '${_resendCooldown}s'
                          : "Didn't receive the code? "
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
