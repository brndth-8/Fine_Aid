import 'dart:io';
import 'package:flutter/material.dart';
import 'assessment_result_screen.dart';

class _DetectedWound {
  final String label;
  final Rect region; // normalized 0-1 coordinates

  const _DetectedWound({required this.label, required this.region});
}

class MultiInjuryScreen extends StatefulWidget {
  final String imagePath;

  const MultiInjuryScreen({super.key, required this.imagePath});

  @override
  State<MultiInjuryScreen> createState() => _MultiInjuryScreenState();
}

class _MultiInjuryScreenState extends State<MultiInjuryScreen> {
  int? _selectedIndex;

  final List<_DetectedWound> _wounds = const [
    _DetectedWound(
      label: 'Wound 1 — Minor Cut',
      region: Rect.fromLTWH(0.05, 0.35, 0.38, 0.35),
    ),
    _DetectedWound(
      label: 'Wound 2 — Skin Irritation',
      region: Rect.fromLTWH(0.52, 0.28, 0.42, 0.42),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('AI Vision Camera', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multiple injuries detected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the wound you want to focus on for assessment.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(widget.imagePath), fit: BoxFit.cover),
                          ..._wounds.asMap().entries.map((entry) {
                            final index = entry.key;
                            final wound = entry.value;
                            final isSelected = _selectedIndex == index;

                            return Positioned(
                              left: wound.region.left * constraints.maxWidth,
                              top: wound.region.top * constraints.maxHeight,
                              width: wound.region.width * constraints.maxWidth,
                              height:
                                  wound.region.height * constraints.maxHeight,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedIndex = index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.white70,
                                      width: isSelected ? 3 : 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.black54,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(6),
                                        bottomRight: Radius.circular(6),
                                      ),
                                    ),
                                    child: Text(
                                      'Wound ${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_selectedIndex != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Selected: ${_wounds[_selectedIndex!].label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedIndex == null
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssessmentResultScreen(
                              imagePath: widget.imagePath,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(
                  _selectedIndex == null
                      ? 'Select a wound to continue'
                      : 'Assess Selected Wound',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
