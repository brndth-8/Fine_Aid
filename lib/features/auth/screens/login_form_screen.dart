import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/api/gemini_service.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

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

  Future<String?> _checkLockout(String username) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('loginAttempts')
          .doc(username.toLowerCase())
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final attempts = data['attempts'] as int? ?? 0;
      final lockedUntil = data['lockedUntil'] as Timestamp?;

      if (lockedUntil != null) {
        final lockEnd = lockedUntil.toDate();
        if (DateTime.now().isBefore(lockEnd)) {
          final remaining = lockEnd.difference(DateTime.now()).inMinutes + 1;
          return 'Account temporarily locked. '
              'Try again in $remaining minute(s).';
        } else {
          await _clearFailedAttempts(username);
          return null;
        }
      }

      if (attempts >= 5) {
        await FirebaseFirestore.instance
            .collection('loginAttempts')
            .doc(username.toLowerCase())
            .update({
              'lockedUntil': Timestamp.fromDate(
                DateTime.now().add(const Duration(minutes: 15)),
              ),
            });
        return 'Too many failed attempts. '
            'Account locked for 15 minutes.';
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordFailedAttempt(String username) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('loginAttempts')
          .doc(username.toLowerCase());
      final doc = await ref.get();

      if (!doc.exists) {
        await ref.set({
          'attempts': 1,
          'lastAttempt': FieldValue.serverTimestamp(),
          'lockedUntil': null,
        });
      } else {
        await ref.update({
          'attempts': FieldValue.increment(1),
          'lastAttempt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _clearFailedAttempts(String username) async {
    try {
      await FirebaseFirestore.instance
          .collection('loginAttempts')
          .doc(username.toLowerCase())
          .set({'attempts': 0, 'lastAttempt': null, 'lockedUntil': null});
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();

      final lockoutMessage = await _checkLockout(username);
      if (lockoutMessage != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(lockoutMessage)));
        setState(() => _isLoading = false);
        return;
      }

      final credential = await _authService.signInWithUsername(
        username: username,
        password: _passwordController.text,
      );

      await _clearFailedAttempts(username);
      GeminiService().reset();

      if (!mounted) return;

      final uid = credential.user?.uid;
      if (uid == null) return;

      debugPrint('Login successful for uid: $uid');

      final admin = await AuthService().isAdmin(uid);
      debugPrint('isAdmin result: $admin');

      if (!mounted) return;

      if (admin) {
        debugPrint('Routing to AdminDashboardScreen');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          (route) => false,
        );
        return;
      }

      debugPrint('Routing to normal user flow');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      await _recordFailedAttempt(_usernameController.text.trim());

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
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 48),

                // Username
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

                // Password
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

                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),

                // Forgot password
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),

                // Register link
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/registration'),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Register here',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Back to landing
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
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
