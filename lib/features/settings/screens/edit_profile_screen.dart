import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/local_profile_photo.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../core/password_requirements.dart';
import '../../../core/widgets/password_checklist.dart';

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
  final _usernameController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isVerifyingCurrentPassword = false;
  bool _currentPasswordVerified = false;
  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _originalUsername = '';
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
        _originalUsername = doc.data()?['username'] as String? ?? '';
        _usernameController.text = _originalUsername;
        _originalRecoveryEmail = doc.data()?['recoveryEmail'] as String? ?? '';
        _recoveryEmailController.text = _originalRecoveryEmail;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _recoveryEmailController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCurrentPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final currentPassword = _currentPasswordController.text;
    final missing = currentPasswordRequiredError(currentPassword);
    if (missing != null) {
      setState(() => _currentPasswordError = missing);
      return;
    }

    setState(() {
      _isVerifyingCurrentPassword = true;
      _currentPasswordError = null;
    });
    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      if (!mounted) return;
      setState(() => _currentPasswordVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password verified. You can now set a new password.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      final wrong =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      if (!mounted) return;
      setState(() {
        _currentPasswordVerified = false;
        if (wrong) _currentPasswordError = 'Current password is incorrect';
      });
      if (!wrong) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify your password. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _currentPasswordVerified = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify your password. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingCurrentPassword = false);
    }
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

  // The password fields only matter once the current password is verified
  // (that is how a user says "I want to change my password").
  String? _validatePassword(String? value) {
    if (!_currentPasswordVerified) return null;
    return newPasswordError(
      current: _currentPasswordController.text,
      newPw: value ?? '',
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (!_currentPasswordVerified) return null;
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
    if (_validateRecoveryEmail(_recoveryEmailController.text) != null) {
      return false;
    }
    if (_currentPasswordVerified &&
        (_validatePassword(_passwordController.text) != null ||
            _validateConfirmPassword(_confirmPasswordController.text) !=
                null)) {
      return false;
    }
    return _usernameController.text.trim() != _originalUsername.trim() ||
        _recoveryEmailController.text.trim() != _originalRecoveryEmail.trim() ||
        _currentPasswordVerified;
  }

  String? _validateRecoveryEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.isNotEmpty && !_currentPasswordVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please verify your current password before setting a new one.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newUsername = _usernameController.text.trim();
      final recoveryEmail = _recoveryEmailController.text.trim();

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
            const SnackBar(content: Text('That username is already taken.')),
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'username': newUsername,
            if (recoveryEmail.isNotEmpty) 'recoveryEmail': recoveryEmail,
            if (recoveryEmail.isEmpty) 'recoveryEmail': FieldValue.delete(),
          })
          .timeout(const Duration(seconds: 10));

      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.pop(context);
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
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Edit Profile',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: _pickedPhoto != null
                            ? FileImage(File(_pickedPhoto!.path))
                            : null,
                        child: _pickedPhoto == null
                            ? const Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      if (_isUploadingPhoto)
                        const Positioned.fill(
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.black38,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto ? null : _handlePickPhoto,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary,
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Username', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter New Username',
                              ),
                              validator: _validateUsername,
                            ),
                            const SizedBox(height: 16),
                            Text('Email', style: theme.textTheme.titleSmall),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _currentPasswordController,
                                    obscureText: _obscureCurrentPassword,
                                    enabled: !_currentPasswordVerified,
                                    onChanged: (_) {
                                      if (_currentPasswordVerified ||
                                          _currentPasswordError != null) {
                                        setState(() {
                                          _currentPasswordVerified = false;
                                          _currentPasswordError = null;
                                        });
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed:
                                        (_isVerifyingCurrentPassword ||
                                            _currentPasswordVerified)
                                        ? null
                                        : _handleVerifyCurrentPassword,
                                    child: _isVerifyingCurrentPassword
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            _currentPasswordVerified
                                                ? Icons.check_circle
                                                : Icons.lock_open_outlined,
                                            color: _currentPasswordVerified
                                                ? Colors.green
                                                : null,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'New Password',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _currentPasswordVerified
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enabled: _currentPasswordVerified,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                hintText: _currentPasswordVerified
                                    ? 'Create New Password'
                                    : 'Verify current password first',
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
                            if (_currentPasswordVerified) ...[
                              const SizedBox(height: 8),
                              PasswordChecklist(
                                password: _passwordController.text,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Confirm New Password',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _currentPasswordVerified
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              enabled: _currentPasswordVerified,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                                  : const Text('Save'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
