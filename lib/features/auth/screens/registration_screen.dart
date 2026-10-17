import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../core/password_requirements.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../core/ph_phone_validator.dart';

/// Phone digits the user types after the fixed "+63" prefix.
const int kPhoneDigitCount = 10;

/// Keeps the phone field to digits only (letters, spaces, +, -, ( ) etc. are
/// dropped — including from pasted text), removes a leading 0 so a local-format
/// number (09123456789) becomes 9123456789, removes a pasted "63"/"+63"
/// country code, and caps the length at [kPhoneDigitCount].
class PhPhoneDigitsFormatter extends TextInputFormatter {
  const PhPhoneDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset.clamp(0, text.length);
    final nonDigit = RegExp(r'[^0-9]');

    var digits = text.replaceAll(nonDigit, '');
    var digitsBeforeCursor = text.substring(0, cursor).replaceAll(nonDigit, '');

    // A pasted "+639123456789" (country code) -> keep just the 10 digits.
    if (digits.length > kPhoneDigitCount && digits.startsWith('63')) {
      digits = digits.substring(2);
      digitsBeforeCursor = digitsBeforeCursor.length >= 2
          ? digitsBeforeCursor.substring(2)
          : '';
    }

    // Leading zero(s): the "+63" prefix already replaces the trunk 0.
    final stripped =
        digits.length - digits.replaceFirst(RegExp(r'^0+'), '').length;
    if (stripped > 0) {
      digits = digits.substring(stripped);
      final cut = stripped < digitsBeforeCursor.length
          ? stripped
          : digitsBeforeCursor.length;
      digitsBeforeCursor = digitsBeforeCursor.substring(cut);
    }

    if (digits.length > kPhoneDigitCount) {
      digits = digits.substring(0, kPhoneDigitCount);
    }
    final offset = digitsBeforeCursor.length > digits.length
        ? digits.length
        : digitsBeforeCursor.length;

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

enum _VerificationMethod { sms, email }

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  // One key + focus node per field so its error can appear as soon as the
  // user leaves it (typing triggers it too, via autovalidateMode below) —
  // but never before they've interacted with it.
  final _usernameKey = GlobalKey<FormFieldState<String>>();
  final _phoneKey = GlobalKey<FormFieldState<String>>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _passwordKey = GlobalKey<FormFieldState<String>>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();
  final _usernameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _emailTouched = false;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _VerificationMethod _verificationMethod = _VerificationMethod.sms;

  @override
  void initState() {
    super.initState();
    _validateOnBlur(_usernameFocus, _usernameKey);
    _validateOnBlur(_phoneFocus, _phoneKey);
    _validateOnBlur(_emailFocus, _emailKey, onBlur: () => _emailTouched = true);
    _validateOnBlur(_passwordFocus, _passwordKey);
    _validateOnBlur(_confirmFocus, _confirmKey);
  }

  void _validateOnBlur(
    FocusNode node,
    GlobalKey<FormFieldState<String>> key, {
    VoidCallback? onBlur,
  }) {
    node.addListener(() {
      if (!node.hasFocus) {
        onBlur?.call();
        key.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers, _ and . allowed';
    }
    return null;
  }

  // [value] is only the digits after the fixed "+63" prefix.
  String? _validatePhone(String? value) {
    final digits = value ?? '';
    if (digits.isEmpty) {
      return 'Phone number is required';
    }
    if (digits.length != kPhoneDigitCount) {
      return 'Phone number must be exactly 10 digits';
    }
    // Exactly 10 digits isn't enough: keep the app's existing checks (must
    // be a mobile number on a real carrier prefix, not a fake pattern).
    if (normalizePhMobileNumber('+63$digits') == null) {
      return phPhoneErrorMessage;
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      // Only required when it's actually the verification channel —
      // otherwise it's just an optional recovery address.
      return _verificationMethod == _VerificationMethod.email
          ? 'Email address is required'
          : null;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// True only when every field is filled and passes its own validator —
  /// this is what enables the Sign Up button.
  bool get _isFormValid =>
      _validateUsername(_usernameController.text) == null &&
      _validatePhone(_phoneController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      validatePasswordStrength(_passwordController.text) == null &&
      _validateConfirmPassword(_confirmPasswordController.text) == null;

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final normalizedPhone = normalizePhMobileNumber(
      '+63${_phoneController.text}',
    );
    if (normalizedPhone == null) {
      // The form validator already checks this, but guard here too since
      // this value is about to be persisted as the account's phone number.
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final isEmailMethod = _verificationMethod == _VerificationMethod.email;
      await _authService.registerWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        phoneNumber: normalizedPhone,
        recoveryEmail: email.isEmpty ? null : email,
        verificationMethod: isEmailMethod ? 'email' : 'phone',
      );

      if (!mounted) return;

      // Show OTP notice
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEmailMethod ? 'Verify your email' : 'Verify your phone number',
          ),
          content: Text(
            isEmailMethod
                ? 'A verification code will be sent to:\n$email\n\n'
                      'Please check your inbox.'
                : 'A verification code will be sent to:\n'
                      '$normalizedPhone\n\n'
                      'Please have your phone ready.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK, proceed'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';
      if (e.code == 'username-already-in-use') {
        message = 'This username is already taken.';
      } else if (e.code == 'email-already-in-use') {
        message = 'This username is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            // Re-evaluate the Sign Up button (and the password checklist)
            // on every keystroke in any field.
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Create Account', style: theme.textTheme.titleSmall),

                const SizedBox(height: 24),
                // Username
                Text('Username', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: _usernameKey,
                  focusNode: _usernameFocus,
                  controller: _usernameController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    hintText: 'Enter a username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _validateUsername,
                ),
                const SizedBox(height: 16),

                // Verification method
                Text(
                  'Verify my account via',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                SegmentedButton<_VerificationMethod>(
                  segments: const [
                    ButtonSegment(
                      value: _VerificationMethod.sms,
                      label: Text('SMS'),
                      icon: Icon(Icons.sms_outlined),
                    ),
                    ButtonSegment(
                      value: _VerificationMethod.email,
                      label: Text('Email'),
                      icon: Icon(Icons.email_outlined),
                    ),
                  ],
                  selected: {_verificationMethod},
                  onSelectionChanged: (selection) {
                    setState(() => _verificationMethod = selection.first);
                    // Re-run the email field's validation so its
                    // required-or-not state updates immediately — but only
                    // if the user has already interacted with it.
                    if (_emailTouched || _emailController.text.isNotEmpty) {
                      _emailKey.currentState?.validate();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Phone number
                Text('Phone Number', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: _phoneKey,
                  focusNode: _phoneFocus,
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  maxLength: kPhoneDigitCount,
                  inputFormatters: const [PhPhoneDigitsFormatter()],
                  decoration: const InputDecoration(
                    hintText: '9123456789',
                    counterText: '',
                    // Fixed, non-editable country code shown before the
                    // digits the user types.
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 12),
                        Icon(Icons.phone_outlined),
                        SizedBox(width: 8),
                        Text(
                          '+63',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 6),
                      ],
                    ),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),

                // Email — required when Email verification is chosen above,
                // otherwise optional (still usable for password recovery).
                Text('Email', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: _emailKey,
                  focusNode: _emailFocus,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => _emailTouched = true,
                  decoration: const InputDecoration(
                    hintText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                // Password
                Text('Password', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: _passwordKey,
                  focusNode: _passwordFocus,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) {
                    // Keep "Passwords do not match" in step with a changed
                    // password once the user has started confirming it.
                    if (_confirmPasswordController.text.isNotEmpty) {
                      _confirmKey.currentState?.validate();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Create password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: validatePasswordStrength,
                ),
                const SizedBox(height: 8),

                // Live checklist: each requirement turns green as it's met.
                PasswordChecklist(password: _passwordController.text),
                const SizedBox(height: 16),

                // Confirm Password
                Text('Confirm Password', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: _confirmKey,
                  focusNode: _confirmFocus,
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    hintText: 'Repeat password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 32),

                // Sign Up button
                // Disabled (gray, not tappable) until every field is filled
                // and valid.
                ElevatedButton(
                  onPressed: (_isFormValid && !_isLoading)
                      ? _handleSignUp
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    // While loading keep the existing look; otherwise the
                    // disabled state is gray.
                    disabledBackgroundColor: _isLoading
                        ? null
                        : Colors.grey.shade300,
                    disabledForegroundColor: _isLoading
                        ? null
                        : Colors.grey.shade600,
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
                      : const Text('Sign Up'),
                ),
                const SizedBox(height: 16),

                // Login link
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/login-form'),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login here',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
