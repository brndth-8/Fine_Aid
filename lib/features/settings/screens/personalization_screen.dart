import 'package:flutter/material.dart';
import '../../../core/text_scale_controller.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Personalization',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Adjust Text Size',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: TextScaleController.instance,
                builder: (context, _) {
                  final scale = TextScaleController.instance.scale;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('A', style: theme.textTheme.bodySmall),
                          Expanded(
                            child: Slider(
                              value: scale,
                              min: TextScaleController.min,
                              max: TextScaleController.max,
                              divisions: 8,
                              label: '${(scale * 100).round()}%',
                              onChanged: (value) =>
                                  TextScaleController.instance.setScale(value),
                            ),
                          ),
                          Text('A', style: theme.textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Sample Text',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The quick brown fox jumps over the lazy dog. '
                              'Adjust to see the changes.\nABC',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              Text(
                'This applies across the whole app immediately and is '
                'remembered next time you open Fine Aid.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
