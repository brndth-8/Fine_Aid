import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('User Login Screen'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/registration'),
              child: const Text('Register'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/onboarding'),
              child: const Text('Continue as Guest'),
            ),
          ],
        ),
      ),
    );
  }
}
