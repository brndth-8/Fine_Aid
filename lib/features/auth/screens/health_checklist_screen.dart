import 'package:flutter/material.dart';

class HealthChecklistScreen extends StatelessWidget {
  const HealthChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Checklist')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Health Status Checklist Screen'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/onboarding'),
              child: const Text('Onboarding'),
            ),
          ],
        ),
      ),
    );
  }
}
