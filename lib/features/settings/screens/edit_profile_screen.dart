import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/local_profile_photo.dart';
import '../../../services/firebase/email_reservation.dart';
import '../../../services/firebase/phone_reservation.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../core/password_requirements.dart';
import '../../../core/age_utils.dart';
import '../../../core/network_error.dart';
import '../../../core/ph_phone_validator.dart';
import '../../../core/widgets/phone_otp_dialog.dart';
import '../../../core/widgets/underage_notice.dart';
import '../../../services/connectivity_service.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../auth/screens/registration_screen.dart'
    show PhPhoneDigitsFormatter, kPhoneDigitCount;
import '../../../i18n/profile_strings.dart';
import '../../../i18n/registration_strings.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../i18n/screen_text_strings.dart';

/// Password-change rules for Edit Profile, kept as plain functions so they
/// can be tested without Firebase. The strength rules themselves are the
/// shared ones from core/password_requirements.dart (same as Sign Up).
String? currentPasswordRequiredError(String current) =>
    current.isEmpty ? 'Current password is required' : null;

String? newPasswordError({required String current, required String newPw}) {
  if (newPw.isEmpty) return 'New password is required';
  final strength = validatePasswordStrength(newPw);
  if (strength != null) return strength;
  if (newPw == current) {
    return 'New password must be different from your current password';
  }
  return null;
}

String? confirmPasswordError({
  required String newPw,
  required String confirm,
}) => confirm == newPw ? null : 'Passwords do not match';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  // Only the 10 digits after the fixed +63.
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _originalUsername = '';
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalPhoneDigits = '';
  DateTime? _originalDob;
  DateTime? _dob;
  String? _originalGender;
  String? _gender; // 'male' | 'female' | 'other'
  String _originalRecoveryEmail = '';
  // Shown under the Current Password field (wrong / missing password).
  String? _currentPasswordError;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    // Keep the Save button's enabled state in step with every field.
    for (final c in [
      _firstNameController,
      _lastNameController,
      _phoneController,
      _dobController,
      _usernameController,
      _recoveryEmailController,
      _currentPasswordController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _loadCurrentProfile();
    final existingPath = LocalProfilePhoto().path;
    if (existingPath != null) {
      _pickedPhoto = XFile(existingPath);
    }
  }

  Future<void> _handlePickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _pickedPhoto = image;
        _isUploadingPhoto = true;
      });
      LocalProfilePhoto().path = image.path;

      try {
        final url = await StorageService().uploadProfilePhoto(image.path);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'profilePhotoUrl': url});
        LocalProfilePhoto().url = url;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo saved locally. Upload failed - will retry on save.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        final data = doc.data() ?? {};
        _originalUsername = data['username'] as String? ?? '';
        _usernameController.text = _originalUsername;
        _originalFirstName = (data['firstName'] as String? ?? '').trim();
        _firstNameController.text = _originalFirstName;
        _originalLastName = (data['lastName'] as String? ?? '').trim();
        _lastNameController.text = _originalLastName;
        _originalPhoneDigits = _phoneDigitsOf(data['phoneNumber'] as String?);
        _phoneController.text = _originalPhoneDigits;
        final dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
        _originalDob = dob == null ? null : DateUtils.dateOnly(dob);
        _dob = _originalDob;
        _dobController.text = _dob == null ? '' : formatDateInput(_dob!);
        _originalGender = data['gender'] as String?;
        _gender = _originalGender;
        _originalRecoveryEmail = doc.data()?['recoveryEmail'] as String? ?? '';
        _recoveryEmailController.text = _originalRecoveryEmail;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _usernameController.dispose();
    _recoveryEmailController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Whether the person is changing their password: any of the three
  /// password fields has something in it.
  bool get _wantsPasswordChange =>
      _currentPasswordController.text.isNotEmpty ||
      _passwordController.text.isNotEmpty ||
      _confirmPasswordController.text.isNotEmpty;

  /// Checks the current password against the account (when saving). False,
  /// with the error shown under the field, when it is wrong.
  Future<bool> _currentPasswordIsRight() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return false;
    try {
      await user!.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        ),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      final wrong =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      if (!mounted) return false;
      if (wrong) {
        setState(() {
          _currentPasswordError = ScreenText.of(
            context,
          ).incorrectCurrentPassword;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ScreenText.of(context).couldNotVerifyPassword),
          ),
        );
      }
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).couldNotVerifyPassword)),
      );
      return false;
    }
  }

  /// "+639123456789" (or an older format) -> the 10 digits after +63.
  static String _phoneDigitsOf(String? saved) {
    var digits = (saved ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  // A detail the account never had (an older account) may stay empty; one
  // that is there cannot be emptied. Whatever is entered must be valid.
  String? _validateName(String? value, {required bool first}) {
    final s = RegistrationStrings.of(context);
    final text = value?.trim() ?? '';
    final original = first ? _originalFirstName : _originalLastName;
    if (text.isEmpty) {
      if (original.isEmpty) return null;
      return first ? s.firstNameRequired : s.lastNameRequired;
    }
    if (!RegExp(r"^[\p{L}][\p{L} .'\-]*$", unicode: true).hasMatch(text)) {
      return s.nameInvalid;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = value ?? '';
    if (digits.isEmpty) {
      return _originalPhoneDigits.isEmpty ? null : 'Phone number is required';
    }
    if (digits.length != kPhoneDigitCount) {
      return 'Phone number must be exactly 10 digits';
    }
    if (normalizePhMobileNumber('+63$digits') == null) {
      return phPhoneErrorMessage;
    }
    return null;
  }

  String? _validateDob(String? value) {
    final s = RegistrationStrings.of(context);
    final dob = _dob;
    if (dob == null) {
      if (_originalDob == null && (value ?? '').isEmpty) return null;
      return (value ?? '').isEmpty ? s.dobRequired : s.dobInvalid;
    }
    if (dob.isAfter(DateUtils.dateOnly(DateTime.now()))) return s.dobFuture;
    if (dob.year < 1900) return s.dobInvalid;
    return null;
  }

  String? _validateGender(String? value) =>
      (_gender == null && _originalGender != null)
      ? RegistrationStrings.of(context).genderRequired
      : null;

  Future<void> _pickDob() async {
    final picked = await showAppDatePicker(
      context,
      initial: _dob,
      firstDate: DateTime(1900),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobController.text = formatDateInput(picked);
    });
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

  // The password fields go together: filling any of them means "I want to
  // change my password", and then all three are needed.
  String? _validateCurrentPassword(String? value) {
    if (!_wantsPasswordChange) return null;
    return currentPasswordRequiredError(value ?? '');
  }

  String? _validatePassword(String? value) {
    if (!_wantsPasswordChange) return null;
    return newPasswordError(
      current: _currentPasswordController.text,
      newPw: value ?? '',
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (!_wantsPasswordChange) return null;
    return confirmPasswordError(
      newPw: _passwordController.text,
      confirm: value ?? '',
    );
  }

  /// Save is enabled only when everything entered is valid AND something
  /// actually changed (username, email, or a completed password change).
  bool get _canSave {
    if (_isLoading || _isSaving) return false;
    if (_validateUsername(_usernameController.text) != null) return false;
    if (_validateName(_firstNameController.text, first: true) != null ||
        _validateName(_lastNameController.text, first: false) != null ||
        _validatePhone(_phoneController.text) != null ||
        _validateDob(_dobController.text) != null ||
        _validateGender(_gender) != null) {
      return false;
    }
    if (_validateRecoveryEmail(_recoveryEmailController.text) != null) {
      return false;
    }
    if (_validateCurrentPassword(_currentPasswordController.text) != null ||
        _validatePassword(_passwordController.text) != null ||
        _validateConfirmPassword(_confirmPasswordController.text) != null) {
      return false;
    }
    return _usernameController.text.trim() != _originalUsername.trim() ||
        _personalDetailsChanged ||
        _recoveryEmailController.text.trim() != _originalRecoveryEmail.trim() ||
        _wantsPasswordChange;
  }

  bool get _personalDetailsChanged =>
      _firstNameController.text.trim() != _originalFirstName ||
      _lastNameController.text.trim() != _originalLastName ||
      _phoneController.text != _originalPhoneDigits ||
      _dob != _originalDob ||
      _gender != _originalGender;

  String? _validateRecoveryEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final emailRegex = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Widget _label(ThemeData theme, String text, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: text,
        style: theme.textTheme.titleSmall,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
        ],
      ),
    );
  }

  /// The photo, with a camera badge to change it.
  Widget _avatar(ThemeData theme) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: Colors.white,
          backgroundImage: _pickedPhoto != null
              ? FileImage(File(_pickedPhoto!.path))
              : null,
          child: _pickedPhoto == null
              ? const Icon(Icons.person, size: 48, color: Colors.grey)
              : null,
        ),
        if (_isUploadingPhoto)
          const Positioned.fill(
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploadingPhoto ? null : _handlePickPhoto,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sends a code to the new number and asks for it. False when there is no
  /// connection or the person cancelled (nothing is saved then).
  Future<bool> _verifyNewPhone() async {
    if (!await ConnectivityService().isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(noInternetMessage)));
      }
      return false;
    }
    if (!mounted) return false;
    return showPhoneOtpDialog(
      context,
      phoneNumber: '+63${_phoneController.text}',
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // The current password is checked now, before anything is saved.
    if (_wantsPasswordChange) {
      setState(() {
        _isSaving = true;
        _currentPasswordError = null;
      });
      final right = await _currentPasswordIsRight();
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (!right) return;
    }

    // A new birthday that makes the person under 18: the supervision notice
    // comes first, as at sign-up.
    final becameUnderage =
        _dob != null && _dob != _originalDob && calculateAge(_dob!) < kAdultAge;
    if (becameUnderage && !await showUnderageNotice(context)) return;
    if (!mounted) return;

    // A new phone number is only saved once a code sent to it was entered.
    final phoneChanged =
        _phoneController.text.isNotEmpty &&
        _phoneController.text != _originalPhoneDigits;
    if (phoneChanged && !await _verifyNewPhone()) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newUsername = _usernameController.text.trim();
      // Stored trimmed and lower-case; one account per email address.
      final recoveryEmail = normalizeEmail(_recoveryEmailController.text);
      final emailChanged =
          recoveryEmail != normalizeEmail(_originalRecoveryEmail);
      final firestore = FirebaseFirestore.instance;

      // Same for a changed phone number (one account per number).
      final newPhone = phoneChanged ? '+63${_phoneController.text}' : null;
      if (newPhone != null) {
        final reservation = await firestore
            .collection('phones')
            .doc(newPhone)
            .get();
        if (reservation.exists && reservation.data()?['uid'] != user.uid) {
          throw PhoneTakenException(newPhone);
        }
      }

      // Check the address first so a taken email doesn't leave a
      // half-applied username change behind (the save below re-checks it
      // atomically).
      if (emailChanged && recoveryEmail.isNotEmpty) {
        final reservation = await firestore
            .collection('emails')
            .doc(recoveryEmail)
            .get();
        if (reservation.exists && reservation.data()?['uid'] != user.uid) {
          throw EmailTakenException(recoveryEmail);
        }
      }

      // Usernames are case-sensitive app-wide (see AuthService) — the
      // reservation doc is keyed by the exact-case username itself. An
      // older account may still have its reservation under the legacy
      // lowercased doc ID; either way, this releases whichever doc
      // currently holds THIS account's reservation and creates the new
      // one under the exact-case scheme, so a rename never leaves a stale
      // index doc behind or lets a case-variant collide silently.
      final oldUsername = _originalUsername.trim();
      if (newUsername != oldUsername) {
        final oldLowerKey = oldUsername.toLowerCase();
        final usernamesRef = FirebaseFirestore.instance.collection('usernames');

        final existingExact = await usernamesRef.doc(newUsername).get();
        final existingLegacy = await usernamesRef
            .doc(newUsername.toLowerCase())
            .get();
        final legacyCollision =
            existingLegacy.exists &&
            existingLegacy.data()?['usernameExact'] == newUsername;

        if (existingExact.exists || legacyCollision) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ScreenText.of(context).usernameTaken)),
          );
          setState(() => _isSaving = false);
          return;
        }

        // The account's Firebase Auth email is always the generated
        // username@fineaid.app one (never the recovery email above), so
        // it's already right here on `user` — no extra read needed.
        final oldExactDoc = await usernamesRef.doc(oldUsername).get();
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(
          usernamesRef.doc(oldExactDoc.exists ? oldUsername : oldLowerKey),
        );
        batch.set(usernamesRef.doc(newUsername), {
          'email': user.email,
          'uid': user.uid,
          'usernameExact': newUsername,
        });
        await batch.commit();
      }

      // The profile and the email reservation change in one transaction.
      // An unchanged email isn't touched at all.
      final userRef = firestore.collection('users').doc(user.uid);
      await firestore
          .runTransaction((tx) async {
            final applyEmail = emailChanged
                ? await EmailReservation.prepare(
                    tx,
                    firestore,
                    uid: user.uid,
                    newEmail: recoveryEmail,
                    oldEmail: _originalRecoveryEmail,
                  )
                : () {};
            final applyPhone = newPhone != null
                ? await PhoneReservation.prepare(
                    tx,
                    firestore,
                    uid: user.uid,
                    newPhone: newPhone,
                    oldPhone: '+63$_originalPhoneDigits',
                  )
                : () {};
            tx.update(userRef, {
              'username': newUsername,
              if (_firstNameController.text.trim() != _originalFirstName)
                'firstName': _firstNameController.text.trim(),
              if (_lastNameController.text.trim() != _originalLastName)
                'lastName': _lastNameController.text.trim(),
              if (_phoneController.text != _originalPhoneDigits &&
                  _phoneController.text.isNotEmpty)
                'phoneNumber': '+63${_phoneController.text}',
              if (_dob != _originalDob && _dob != null)
                'dateOfBirth': Timestamp.fromDate(_dob!),
              if (_gender != _originalGender && _gender != null)
                'gender': _gender,
              if (becameUnderage) ...{
                'underageAcknowledged': true,
                'underageAcknowledgedAt': FieldValue.serverTimestamp(),
              },
              if (emailChanged && recoveryEmail.isNotEmpty)
                'recoveryEmail': recoveryEmail,
              if (emailChanged && recoveryEmail.isEmpty)
                'recoveryEmail': FieldValue.delete(),
            });
            applyEmail();
            applyPhone();
          })
          .timeout(Duration(seconds: 10));

      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).profileUpdated)),
      );
      Navigator.pop(context);
    } on EmailTakenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).emailTaken)),
      );
    } on PhoneTakenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).phoneTaken)),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Could not update profile.';
      if (e.code == 'requires-recent-login') {
        message =
            'Please log out and log back in before changing your password.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final r = RegistrationStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _avatar(theme)),
                      const SizedBox(height: 14),
                      Text(
                        ProfileStrings.of(context).accountDetails,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _label(
                        theme,
                        RegistrationStrings.of(context).firstNameLabel,
                        required: true,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          hintText: RegistrationStrings.of(
                            context,
                          ).firstNameHint,
                        ),
                        validator: (v) => _validateName(v, first: true),
                      ),
                      const SizedBox(height: 16),
                      _label(
                        theme,
                        RegistrationStrings.of(context).lastNameLabel,
                        required: true,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          hintText: RegistrationStrings.of(
                            context,
                          ).lastNameHint,
                        ),
                        validator: (v) => _validateName(v, first: false),
                      ),
                      const SizedBox(height: 16),
                      _label(
                        theme,
                        RegistrationStrings.of(context).dobLabel,
                        required: true,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDob,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          hintText: RegistrationStrings.of(context).dobHint,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                        validator: _validateDob,
                      ),
                      const SizedBox(height: 16),
                      Text(r.ageLabel, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      // Worked out from the birthday; never typed.
                      TextFormField(
                        key: ValueKey(_dob),
                        initialValue: _dob == null
                            ? ''
                            : '${calculateAge(_dob!)}',
                        readOnly: true,
                        canRequestFocus: false,
                        decoration: InputDecoration(
                          hintText: r.ageHint,
                          prefixIcon: const Icon(Icons.cake_outlined),
                          fillColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label(
                        theme,
                        RegistrationStrings.of(context).genderLabel,
                        required: true,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: RegistrationStrings.of(context).genderHint,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text(
                              RegistrationStrings.of(context).genderMale,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text(
                              RegistrationStrings.of(context).genderFemale,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text(
                              RegistrationStrings.of(context).genderOther,
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                        validator: _validateGender,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ScreenText.of(context).username,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter New Username',
                        ),
                        validator: _validateUsername,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ProfileStrings.of(context).phone,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        maxLength: kPhoneDigitCount,
                        inputFormatters: const [PhPhoneDigitsFormatter()],
                        decoration: const InputDecoration(
                          hintText: '9123456789',
                          counterText: '',
                          prefixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 12),
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
                      Text(
                        ScreenText.of(context).email,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lets you reset your password by email '
                        'instead of SMS.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _recoveryEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email Address',
                        ),
                        validator: _validateRecoveryEmail,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Current Password',
                        style: theme.textTheme.titleSmall,
                      ),

                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (_) {
                          if (_currentPasswordError != null) {
                            setState(() => _currentPasswordError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter Current Password',
                          errorText: _currentPasswordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureCurrentPassword =
                                  !_obscureCurrentPassword,
                            ),
                          ),
                        ),
                        validator: _validateCurrentPassword,
                      ),
                      const SizedBox(height: 16),
                      Text('New Password', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          hintText: 'Create New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        PasswordChecklist(password: _passwordController.text),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Confirm New Password',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          hintText: 'Repeat New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        validator: _validateConfirmPassword,
                      ),

                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _canSave ? _handleSave : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(ScreenText.of(context).save),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(ScreenText.of(context).cancel),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
