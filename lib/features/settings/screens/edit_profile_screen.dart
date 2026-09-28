import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/local_profile_photo.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../core/password_requirements.dart';
import '../../../core/widgets/password_requirements_checklist.dart';

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
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedPhoto;

  @override
  void initState() {
    super.initState();
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
        _recoveryEmailController.text =
            doc.data()?['recoveryEmail'] as String? ?? '';
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
    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current password first.')),
      );
      return;
    }

    setState(() => _isVerifyingCurrentPassword = true);
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
      final message =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'Incorrect current password.'
          : 'Could not verify your password. Please try again.';
      if (!mounted) return;
      setState(() => _currentPasswordVerified = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return null; // optional on edit
    return validatePasswordStrength(value);
  }

  String? _validateConfirmPassword(String? value) {
    if (_passwordController.text.isEmpty) return null;
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
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

      // Usernames are case-insensitive app-wide (see AuthService), so the
      // uniqueness check and the `usernames/{lowercased}` index update
      // here follow the exact same normalized-lowercase scheme
      // registration uses — otherwise a rename here would leave the old
      // index doc stale (still pointing logins at the old username) and
      // wouldn't reliably catch a case-variant collision with someone
      // else's account.
      final oldKey = _originalUsername.trim().toLowerCase();
      final newKey = newUsername.toLowerCase();
      if (newKey != oldKey) {
        final existing = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(newKey)
            .get();
        if (existing.exists) {
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
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(
          FirebaseFirestore.instance.collection('usernames').doc(oldKey),
        );
        batch.set(
          FirebaseFirestore.instance.collection('usernames').doc(newKey),
          {'email': user.email, 'uid': user.uid, 'usernameExact': newUsername},
        );
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
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
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
                                      if (_currentPasswordVerified) {
                                        setState(
                                          () =>
                                              _currentPasswordVerified = false,
                                        );
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter Current Password',
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
                              'Password',
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
                              onChanged: (_) => setState(() {}),
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
                              PasswordRequirementsChecklist(
                                password: _passwordController.text,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Confirm Password',
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
                              onPressed: _isSaving ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
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
