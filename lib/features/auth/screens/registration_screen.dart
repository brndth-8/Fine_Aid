import '../../../core/age_utils.dart';
import 'account_created_screen.dart';
import '../../../core/widgets/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../i18n/registration_strings.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/firebase/email_reservation.dart' show normalizeEmail;
import '../../../services/firebase/registration_flow.dart';
import '../../../core/password_requirements.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../core/ph_phone_validator.dart';
import '../../../i18n/screen_text_strings.dart';

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
  // Personal details.
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _dob;
  String? _gender; // 'male' | 'female' | 'other'
  final _firstNameKey = GlobalKey<FormFieldState<String>>();
  final _lastNameKey = GlobalKey<FormFieldState<String>>();
  final _dobKey = GlobalKey<FormFieldState<String>>();
  final _genderKey = GlobalKey<FormFieldState<String>>();
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

  /// An address the server just said belongs to another account. The field
  /// shows "already registered" until the person types a different one.
  String? _takenEmail;

  /// The same for a phone number (the 10 digits after +63).
  String? _takenPhone;

  // 0 = Basic information, 1 = Account details.
  int _page = 0;
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _VerificationMethod _verificationMethod = _VerificationMethod.sms;

  @override
  void initState() {
    super.initState();
    _validateOnBlur(_usernameFocus, _usernameKey);
    _validateOnBlur(_phoneFocus, _phoneKey);
    _validateOnBlur(_emailFocus, _emailKey);
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
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _ageController.dispose();
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

  String? _validateName(String? value, {required bool first}) {
    final s = RegistrationStrings.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return first ? s.firstNameRequired : s.lastNameRequired;
    if (text.length > kNameMaxLength) {
      return s.nameTooLong.replaceFirst('{max}', '$kNameMaxLength');
    }
    if (!RegExp(r"^[\p{L}][\p{L} .'\-]*$", unicode: true).hasMatch(text)) {
      return s.nameInvalid;
    }
    return null;
  }

  String? _validateDob(String? value) {
    final s = RegistrationStrings.of(context);
    final dob = _dob;
    if (dob == null) {
      return (value ?? '').isEmpty ? s.dobRequired : s.dobInvalid;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (dob.isAfter(today)) return s.dobFuture;
    if (dob.year < 1900) return s.dobInvalid;
    return null;
  }

  String? _validateGender(String? value) =>
      (_gender == null) ? RegistrationStrings.of(context).genderRequired : null;

  /// The longest username a new account can have.
  static const int kUsernameMaxLength = 32;

  /// The longest first name or last name.
  static const int kNameMaxLength = 32;

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.trim().length > kUsernameMaxLength) {
      return RegistrationStrings.of(
        context,
      ).usernameTooLong.replaceFirst('{max}', '$kUsernameMaxLength');
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
    if (_takenPhone != null && digits == _takenPhone) {
      return RegistrationStrings.of(context).phoneTaken;
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
    final emailRegex = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    if (_takenEmail != null && normalizeEmail(trimmed) == _takenEmail) {
      return RegistrationStrings.of(context).emailTaken;
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
      _validateName(_firstNameController.text, first: true) == null &&
      _validateName(_lastNameController.text, first: false) == null &&
      _validateDob(_dobController.text) == null &&
      _validateGender(_gender) == null &&
      _validateUsername(_usernameController.text) == null &&
      // Only the chosen method's field is on screen, so only it is checked.
      (_verificationMethod != _VerificationMethod.sms ||
          _validatePhone(_phoneController.text) == null) &&
      (_verificationMethod != _VerificationMethod.email ||
          _validateEmail(_emailController.text) == null) &&
      validatePasswordStrength(_passwordController.text) == null &&
      _validateConfirmPassword(_confirmPasswordController.text) == null;

  /// Page 1 is complete: its fields are the only ones the Next button needs.
  bool get _isBasicValid =>
      _validateName(_firstNameController.text, first: true) == null &&
      _validateName(_lastNameController.text, first: false) == null &&
      _validateDob(_dobController.text) == null &&
      _validateGender(_gender) == null;

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _handleNext() {
    // Only page 1's fields are on screen, so this validates just those.
    if (!_formKey.currentState!.validate()) return;
    _goToPage(1);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final picked = await showAppDatePicker(
      context,
      // Opens on the date already chosen, or on today.
      initial: _dob,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobController.text = formatDateInput(picked);
      _ageController.text = '${calculateAge(picked)}';
    });
    _dobKey.currentState?.validate();
    // Under 16: ask for a parent or guardian's help (they can carry on).
    if (calculateAge(picked) < kIndependentAge) await _showUnder16Notice();
  }

  /// "You must be 16 or older to use this app independently ...": shown when a
  /// birthdate under 16 is entered. Acknowledging it carries on; nothing is
  /// blocked (an adult can set things up with them).
  Future<void> _showUnder16Notice() async {
    final s = RegistrationStrings.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(s.under16Title),
          content: SingleChildScrollView(child: Text(s.under16Body)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.under16Button),
            ),
          ],
        ),
      ),
    );
  }

  /// Under 18: a notice that can only be closed with its one button.
  Future<bool> _confirmUnderage() async {
    final s = RegistrationStrings.of(context);
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(s.underageTitle),
          content: SingleChildScrollView(child: Text(s.underageBody)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.underageButton),
            ),
          ],
        ),
      ),
    );
    return acknowledged == true;
  }

  Future<void> _handleSignUp() async {
    // A second tap while the first sign-up is still running must not start
    // another one (the button is disabled too, this covers a fast double-tap
    // before the rebuild).
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final isEmailMethod = _verificationMethod == _VerificationMethod.email;
    // Phone or email, never both: only the chosen method's value is sent.
    final normalizedPhone = isEmailMethod
        ? null
        : normalizePhMobileNumber('+63${_phoneController.text}');
    if (!isEmailMethod && normalizedPhone == null) {
      // The form validator already checks this, but guard here too since
      // this value is about to be persisted as the account's phone number.
      setState(() {});
      return;
    }

    // Under 18: the supervision notice comes first; sign-up only carries on
    // once it has been acknowledged.
    final dob = _dob!;
    final isUnderage = calculateAge(dob) < kAdultAge;
    if (isUnderage && !await _confirmUnderage()) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await _authService.registerWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        phoneNumber: normalizedPhone,
        recoveryEmail: isEmailMethod && email.isNotEmpty ? email : null,
        verificationMethod: isEmailMethod ? 'email' : 'phone',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: dob,
        gender: _gender,
        underageAcknowledged: isUnderage,
      );

      if (!mounted) return;

      // Only reached when every step of the sign-up really succeeded. The
      // account is signed in and not verified yet. "Account created" comes
      // first (AuthGate is still held back); going back to the root after it
      // lets AuthGate take the user straight to the verification step (no
      // login in between).
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AccountCreatedScreen()));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on RegistrationException catch (e) {
      if (!mounted) return;
      final message = RegistrationStrings.of(context).messageFor(e.error);
      if (e.error == RegistrationError.emailTaken) {
        // Show it on the email field itself, not only in a snackbar.
        setState(() => _takenEmail = normalizeEmail(_emailController.text));
        _emailKey.currentState?.validate();
      }
      if (e.error == RegistrationError.phoneTaken) {
        setState(() => _takenPhone = _phoneController.text);
        _phoneKey.currentState?.validate();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RegistrationStrings.of(context).unknown)),
      );
    } finally {
      // Lets AuthGate carry on (it was held back while signing up).
      AuthService.releaseRegistrationHold();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// First name, last name, date of birth, the age worked out from it
  /// (read-only), and gender.
  List<Widget> _personalFields(ThemeData theme) {
    final s = RegistrationStrings.of(context);
    return [
      _label(theme, s.firstNameLabel),
      const SizedBox(height: 6),
      TextFormField(
        key: _firstNameKey,
        controller: _firstNameController,
        inputFormatters: [LengthLimitingTextInputFormatter(kNameMaxLength)],
        textCapitalization: TextCapitalization.words,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: s.firstNameHint,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        validator: (v) => _validateName(v, first: true),
      ),
      const SizedBox(height: 16),
      _label(theme, s.lastNameLabel),
      const SizedBox(height: 6),
      TextFormField(
        key: _lastNameKey,
        controller: _lastNameController,
        inputFormatters: [LengthLimitingTextInputFormatter(kNameMaxLength)],
        textCapitalization: TextCapitalization.words,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: s.lastNameHint,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        validator: (v) => _validateName(v, first: false),
      ),
      const SizedBox(height: 16),
      _label(theme, s.dobLabel),
      const SizedBox(height: 6),
      TextFormField(
        key: _dobKey,
        controller: _dobController,
        readOnly: true,
        onTap: _pickDob,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: s.dobHint,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        validator: _validateDob,
      ),
      const SizedBox(height: 16),
      // Worked out from the date of birth — never typed, so the two can't
      // disagree.
      _label(theme, s.ageLabel, required: false),
      const SizedBox(height: 6),
      TextFormField(
        controller: _ageController,
        readOnly: true,
        canRequestFocus: false,
        decoration: InputDecoration(
          hintText: s.ageHint,
          prefixIcon: const Icon(Icons.cake_outlined),
          fillColor: Colors.grey.shade200,
        ),
      ),
      const SizedBox(height: 16),
      _label(theme, s.genderLabel),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        key: _genderKey,
        initialValue: _gender,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: s.genderHint,
          prefixIcon: const Icon(Icons.wc_outlined),
        ),
        items: [
          DropdownMenuItem(value: 'male', child: Text(s.genderMale)),
          DropdownMenuItem(value: 'female', child: Text(s.genderFemale)),
          DropdownMenuItem(value: 'other', child: Text(s.genderOther)),
        ],
        onChanged: (v) => setState(() => _gender = v),
        validator: _validateGender,
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Username, how to verify, phone, email, password and its confirmation.
  List<Widget> _accountFields(ThemeData theme) {
    return [
      // Username
      _label(theme, 'Username'),
      const SizedBox(height: 6),
      TextFormField(
        key: _usernameKey,
        focusNode: _usernameFocus,
        controller: _usernameController,
        // Typing or pasting stops at the limit.
        inputFormatters: [LengthLimitingTextInputFormatter(kUsernameMaxLength)],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(
          hintText: 'Enter a username',
          prefixIcon: Icon(Icons.person_outline),
        ),
        validator: _validateUsername,
      ),
      const SizedBox(height: 16),

      // Verification method
      Text(ScreenText.of(context).verifyVia, style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      SegmentedButton<_VerificationMethod>(
        segments: const [
          ButtonSegment(
            value: _VerificationMethod.sms,
            label: Text('Phone number'),
            icon: Icon(Icons.phone_outlined),
          ),
          ButtonSegment(
            value: _VerificationMethod.email,
            label: Text('Email'),
            icon: Icon(Icons.mail_outline),
          ),
        ],
        selected: {_verificationMethod},
        onSelectionChanged: (selection) {
          setState(() {
            _verificationMethod = selection.first;
            // The other method's field is hidden: forget what was typed in
            // it (and any "already registered" mark), so stale data can't be
            // validated or submitted.
            if (_verificationMethod == _VerificationMethod.email) {
              _phoneController.clear();
              _takenPhone = null;
            } else {
              _emailController.clear();
              _takenEmail = null;
            }
          });
        },
      ),
      const SizedBox(height: 16),

      if (_verificationMethod == _VerificationMethod.sms) ...[
        // Phone number
        _label(theme, 'Phone Number'),
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
            // Smaller, lighter and light gray (placeholder only — the
            // typed digits and the +63 prefix are unchanged), so the
            // number never looks cramped beside the +63 prefix.
            hintStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: Color(0xFFBDBDBD),
            ),
            counterText: '',
            // Fixed, non-editable country code shown before the
            // digits the user types.
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 12),
                Icon(Icons.phone_outlined),
                SizedBox(width: 8),
                Text('+63', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
              ],
            ),
          ),
          validator: _validatePhone,
        ),
        const SizedBox(height: 16),
      ] else ...[
        // Email (shown, and required, when Email is the chosen method).
        _label(theme, 'Email'),
        const SizedBox(height: 6),
        TextFormField(
          key: _emailKey,
          focusNode: _emailFocus,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            hintText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: _validateEmail,
        ),
        const SizedBox(height: 16),
      ],

      // Password
      _label(theme, 'Password'),
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
      _label(theme, 'Confirm Password'),
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
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: _validateConfirmPassword,
      ),
    ];
  }

  /// Field label; a red * marks the required ones.
  Widget _label(ThemeData theme, String text, {bool required = true}) {
    return Text.rich(
      TextSpan(
        text: text,
        style: theme.textTheme.titleSmall,
        children: required
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = RegistrationStrings.of(context);

    // The system Back button steps back to page 1 before it leaves.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToPage(0);
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
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
                  Text(
                    ScreenText.of(context).createAccount,
                    style: theme.textTheme.titleSmall,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    '${s.stepOf.replaceFirst('{n}', '${_page + 1}').replaceFirst('{total}', '2')}'
                    ' · ${_page == 0 ? s.stepBasic : s.stepAccount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_page == 0)
                    ..._personalFields(theme)
                  else
                    ..._accountFields(theme),
                  const SizedBox(height: 32),

                  if (_page == 0)
                    ElevatedButton(
                      onPressed: _isBasicValid ? _handleNext : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: BorderSide(color: theme.colorScheme.outline),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                      ),
                      child: Text(s.nextButton),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => _goToPage(0),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: Text(s.backButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_isFormValid && !_isLoading)
                                ? _handleSignUp
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
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
                                : Text(ScreenText.of(context).signUp),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
