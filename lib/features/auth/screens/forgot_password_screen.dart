import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/password_requirements.dart';

enum _ResetStep { username, otp, newPassword, done }

enum _RecoveryMethod { sms, email }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.username;
  _RecoveryMethod _method = _RecoveryMethod.sms;
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (!_usernameFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final functionName = _method == _RecoveryMethod.sms
          ? 'sendPasswordResetOtp'
          : 'sendPasswordResetOtpEmail';
      await FirebaseFunctions.instance.httpsCallable(functionName).call({
        'username': _usernameController.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        _step = _ResetStep.otp;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            e.message ?? 'Could not send the reset code. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not send the reset code. Please try again.';
      });
    }
  }

  Future<void> _handleResetPassword() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyPasswordResetOtp')
          .call({
            'username': _usernameController.text.trim(),
            'code': _codeController.text.trim(),
            'newPassword': _passwordController.text,
          });

      if (!mounted) return;
      setState(() {
        _step = _ResetStep.done;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            e.message ?? 'Could not reset your password. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not reset your password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _ResetStep.username => _buildUsernameStep(),
            _ResetStep.otp || _ResetStep.newPassword => _buildResetStep(),
            _ResetStep.done => _buildDoneStep(),
          },
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    final theme = Theme.of(context);
    return Form(
      key: _usernameFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your username and choose how to receive your 6-digit '
            'verification code.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Send code via', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<_RecoveryMethod>(
            segments: const [
              ButtonSegment(
                value: _RecoveryMethod.sms,
                label: Text('SMS'),
                icon: Icon(Icons.sms_outlined),
              ),
              ButtonSegment(
                value: _RecoveryMethod.email,
                label: Text('Email'),
                icon: Icon(Icons.email_outlined),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (selection) =>
                setState(() => _method = selection.first),
          ),
          const SizedBox(height: 4),
          Text(
            _method == _RecoveryMethod.sms
                ? 'Sent to the phone number on your account.'
                : 'Sent to the recovery email on your account, if you '
                      'added one. If not, use SMS instead.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text('Username', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(hintText: 'Enter your username'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Username is required'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSendCode,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send Reset Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _method == _RecoveryMethod.sms
                  ? 'Enter the 6-digit code sent to the phone number on '
                        'your account, then choose a new password.'
                  : 'Enter the 6-digit code sent to the recovery email on '
                        'your account, then choose a new password.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Verification Code', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(hintText: '6-digit code'),
            ),
            const SizedBox(height: 12),
            Text('New Password', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Create a new password',
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
            const SizedBox(height: 12),
            Text('Confirm New Password', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Repeat new password',
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
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Reset Password'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _step = _ResetStep.username;
                      _error = null;
                    }),
              child: const Text('Start over'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneStep() {
    final theme = Theme.of(context);
    // Center + a content-sized Column (not a bare Column with
    // mainAxisAlignment.center — that has no effect unless the Column
    // itself is stretched to fill the available height first) so this
    // stays centered both ways regardless of screen size, text scale, or
    // safe-area insets.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Password reset!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can now log in with your new password.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
