import 'dart:io';
import 'package:flutter/material.dart';
import '../../../i18n/screen_text_strings.dart';
import 'assessment_result_screen.dart';

class _DetectedWound {
  final String label;
  final Rect region; // normalized 0-1 coordinates

  const _DetectedWound({required this.label, required this.region});
}

// Regions smaller than this (as a fraction of the image) are expanded so
// every wound stays comfortably tappable on a phone screen, even when the
// AI-detected box is small or the wounds are close together.
const double _minRegionWidth = 0.22;
const double _minRegionHeight = 0.16;

class MultiInjuryScreen extends StatefulWidget {
  final String imagePath;
  final List<String> woundDescriptions;
  final List<Rect?> woundBoxes;

  const MultiInjuryScreen({
    super.key,
    required this.imagePath,
    required this.woundDescriptions,
    this.woundBoxes = const [],
  });

  @override
  State<MultiInjuryScreen> createState() => _MultiInjuryScreenState();
}

class _MultiInjuryScreenState extends State<MultiInjuryScreen> {
  int? _selectedIndex;

  late final List<_DetectedWound> _wounds;

  Rect _fallbackRegion(int index) {
    final col = index % 2;
    final row = index ~/ 2;
    return Rect.fromLTWH(
      col == 0 ? 0.05 : 0.52,
      0.25 + (row * 0.35),
      0.38,
      0.30,
    );
  }

  Rect _ensureMinSize(Rect rect) {
    var width = rect.width < _minRegionWidth ? _minRegionWidth : rect.width;
    var height = rect.height < _minRegionHeight
        ? _minRegionHeight
        : rect.height;
    width = width.clamp(0.0, 1.0);
    height = height.clamp(0.0, 1.0);

    var left = rect.center.dx - width / 2;
    var top = rect.center.dy - height / 2;
    left = left.clamp(0.0, 1.0 - width);
    top = top.clamp(0.0, 1.0 - height);

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void initState() {
    super.initState();
    // Use the AI's own detected bounding box for each wound so the tap
    // region actually corresponds to where the wound is in the photo.
    // Fall back to a generated grid position only for a wound the model
    // didn't return a usable box for.
    _wounds = List.generate(widget.woundDescriptions.length, (index) {
      final aiBox = index < widget.woundBoxes.length
          ? widget.woundBoxes[index]
          : null;
      final region = _ensureMinSize(aiBox ?? _fallbackRegion(index));
      return _DetectedWound(label: 'Wound ${index + 1}', region: region);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'AI Vision Camera',
          style: TextStyle(fontWeight: FontWeight.normal),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF700505),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ScreenText.of(context).multipleInjuries,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ScreenText.of(context).multiTip,
                      style: theme.textTheme.bodyMedium?.copyWith(
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
                      borderRadius: BorderRadius.circular(20),
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
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _selectedIndex = index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF700505),
                                      width: isSelected ? 4 : 2,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    color: isSelected
                                        ? const Color(
                                            0xFF700505,
                                          ).withValues(alpha: 0.15)
                                        : null,
                                  ),
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF700505),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      ScreenText.of(context).woundN
                                          .replaceFirst('{n}', '${index + 1}'),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: Colors.white),
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
                  ScreenText.of(context).selectedWound.replaceFirst(
                    '{label}',
                    ScreenText.of(
                      context,
                    ).woundN.replaceFirst('{n}', '${_selectedIndex! + 1}'),
                  ),
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
                              woundHints: [
                                widget.woundDescriptions[_selectedIndex!],
                              ],
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(
                  _selectedIndex == null
                      ? ScreenText.of(context).selectWound
                      : ScreenText.of(context).assessSelected,
                ),
              ),
            ),
            // None of the detected conditions is the one to assess: nothing is
            // assessed and the person goes back to scan again.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final note = ScreenText.of(context).noneChosenNote;
                  Navigator.pop(context);
                  messenger.showSnackBar(SnackBar(content: Text(note)));
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(ScreenText.of(context).noneOfThese),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
