import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSignedIn = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = 'Incorrect username or password.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Center(
                  child: Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 160,
                    height: 160,
                  ),
                ),

                const SizedBox(height: 48),

                Text('Username', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(hintText: 'Enter Username'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Username is required'
                      : null,
                ),
                const SizedBox(height: 16),

                Text('Password', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter Password',
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
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Password is required'
                      : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Checkbox(
                      value: _keepSignedIn,
                      onChanged: (value) =>
                          setState(() => _keepSignedIn = value ?? false),
                    ),
                    const Text('Keep me signed in'),
                  ],
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Forgot password?'),
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
