import 'package:flutter/material.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  double _textScale = 1.0; // 1.0 = default; range 0.8 - 1.6

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
              Row(
                children: [
                  Text('A', style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Slider(
                      value: _textScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      onChanged: (value) => setState(() => _textScale = value),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize:
                            (theme.textTheme.titleMedium?.fontSize ?? 16) *
                            _textScale,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The quick brown fox jumps over the lazy dog. '
                      'Adjust to see the changes.\nABC',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize:
                            (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                            _textScale,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Note: this preview is local for now. App-wide text scaling '
                'will be wired up in a later update.',
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
