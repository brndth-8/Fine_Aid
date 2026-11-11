import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';
import '../admin_access.dart';
import '../admin_two_step.dart';
import 'admin_dashboard_screen.dart';
import 'admin_two_step_setup_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  /// Neutral message shown above the form, e.g. after an idle sign-out.
  final String? notice;

  const AdminLoginScreen({super.key, this.notice});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Set when the password was right but this admin has an authenticator app:
  /// the screen then asks for the 6-digit code to finish signing in.
  MultiFactorResolver? _resolver;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const _accentColor = Color(0xFF8B0000);

  TextStyle? _labelStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: const Color(0xFF333333));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _finishSignIn(credential);
    } on FirebaseAuthMultiFactorException catch (e) {
      // Right password, and this admin has an authenticator app: ask for the
      // code before anything else.
      if (mounted) {
        setState(() {
          _resolver = e.resolver;
          _codeController.clear();
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      // Logged only if this email is an admin's (the server decides).
      recordAdminSignInFailure(_emailController.text, e.code);
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'Sign in failed. Please try again.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  /// Everything after a completed sign-in (password only, or password plus
  /// authenticator code): check admin access, log it, and go in.
  Future<void> _finishSignIn(UserCredential credential) async {
    // An admin is listed in `admins` AND carries the server-set admin
    // claim in their token (refreshed here so a freshly granted claim is
    // picked up).
    final user = credential.user!;
    final listed = await AuthService().isAdmin(user.uid);
    final claimed = listed && await hasAdminClaim(user);
    // The server logs the sign-in and decides success vs refused itself.
    await recordAdminSignIn();

    if (!claimed) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _errorMessage = listed
              ? "Admin access isn't active on this account yet. "
                    'Please contact the system owner.'
              : 'This account does not have admin access.';
          _isLoading = false;
        });
      }
      return;
    }

    // When admins must use an authenticator code and this sign-in had none
    // (an admin who hasn't set one up yet), the only way on is to set it up.
    if (!await twoStepSatisfied(user)) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminTwoStepSetupScreen()),
          (_) => false,
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        (_) => false,
      );
    }
  }

  /// Second step of sign-in: the 6-digit code from the authenticator app.
  Future<void> _verifyCode() async {
    final resolver = _resolver;
    if (resolver == null || _isLoading) return;
    final code = _codeController.text.replaceAll(RegExp(r'\s'), '');
    if (!isValidAuthenticatorCode(code)) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your app.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final hint = resolver.hints.firstWhere(
        (h) => h.factorId == 'totp',
        orElse: () => resolver.hints.first,
      );
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        hint.uid,
        code,
      );
      final credential = await resolver.resolveSignIn(assertion);
      await _finishSignIn(credential);
    } on FirebaseAuthException catch (e) {
      // Logged only if this email is an admin's (the server decides).
      recordAdminSignInFailure(_emailController.text, e.code);
      if (mounted) {
        setState(() {
          _errorMessage = describeTwoStepError(e);
          _isLoading = false;
          if (e.code != 'invalid-verification-code') {
            // The sign-in attempt itself has expired: start again.
            if (e.code == 'code-expired' ||
                e.code == 'session-expired' ||
                e.code == 'totp-challenge-timeout') {
              _resolver = null;
            }
          }
          _codeController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _cancelCode() {
    setState(() {
      _resolver = null;
      _errorMessage = null;
      _codeController.clear();
      _passwordController.clear();
    });
  }

  /// The form shown instead of email + password while the code is asked for.
  List<Widget> _codeStep(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Text(
        'Two-step verification',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF333333),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Enter the 6-digit code from your authenticator app.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
      ),
      const SizedBox(height: 18),
      AuthenticatorCodeField(
        controller: _codeController,
        enabled: !_isLoading,
        onSubmit: _verifyCode,
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _verifyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _isLoading ? null : _cancelCode,
        child: const Text('Back to sign in'),
      ),
    ];
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool isSending = false;
    String? dialogError;
    String? dialogSuccess;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter the admin account's email and we'll send a "
                      'link to reset the password.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: dialogSuccess == null,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter an email address.';
                        }
                        if (!v.contains('@')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    if (dialogSuccess != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogSuccess!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ] else if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(dialogSuccess == null ? 'Cancel' : 'Close'),
                ),
                if (dialogSuccess == null)
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() {
                              isSending = true;
                              dialogError = null;
                            });
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                    email: emailController.text.trim(),
                                  );
                              setDialogState(() {
                                isSending = false;
                                dialogSuccess =
                                    'Password reset email sent. Check the '
                                    'inbox for further instructions.';
                              });
                            } on FirebaseAuthException catch (e) {
                              setDialogState(() {
                                isSending = false;
                                dialogError = e.code == 'user-not-found'
                                    ? 'No account found with that email.'
                                    : 'Could not send reset email. Please '
                                          'try again.';
                              });
                            } catch (_) {
                              setDialogState(() {
                                isSending = false;
                                dialogError =
                                    'Something went wrong. Please try again.';
                              });
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send reset link'),
                  ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/admin_landing_background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/FINE_AID_Logo.png',
                          height: 56,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Admin Portal',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: _accentColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.notice != null && _errorMessage == null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF475569),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.notice!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF334155),
                                          height: 1.4,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.redAccent,
                                          height: 1.4,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_resolver != null)
                          ..._codeStep(context)
                        else ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email Address',
                              style: _labelStyle(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: _inputDecoration(
                              hint: 'Enter Admin Email',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your admin email.';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Password',
                              style: _labelStyle(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              hint: 'Enter Password',
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black38,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: _accentColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _accentColor
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Login',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFAAAAAA)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accentColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      errorStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.redAccent,
        fontWeight: FontWeight.normal,
      ),
    );
  }
}
