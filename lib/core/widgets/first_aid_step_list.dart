import 'package:flutter/material.dart';
import '../../data/first_aid_guides.dart' show GuidePhase;
import '../../data/first_aid_step_images.dart';
import 'first_aid_step_image.dart';

/// One First Aid step ready to show: which phase it belongs to, its text, an
/// optional reason and the kind of picture that goes with it.
class PhasedStep {
  final GuidePhase? phase;
  final String text;
  final String? why;
  final String? imageKey;

  const PhasedStep({this.phase, required this.text, this.why, this.imageKey});
}

final RegExp _phaseLabel = RegExp(
  r'^\s*(Before|During|After|Bago|Habang(?: nag-aalaga)?|Pagkatapos)\s*:\s*',
  caseSensitive: false,
);

GuidePhase? _phaseOf(String step) {
  final m = RegExp(
    r'^\s*(Before|During|After)\s*:',
    caseSensitive: false,
  ).firstMatch(step);
  return switch (m?.group(1)?.toLowerCase()) {
    'before' => GuidePhase.before,
    'during' => GuidePhase.during,
    'after' => GuidePhase.after,
    _ => null,
  };
}

/// Turns the AI's steps ("Before: step — why") into [PhasedStep]s. The phase
/// and the picture come from the English step; the words shown come from
/// [shown] (the Tagalog translation, same order) when it is given, with any
/// "Before:" style label taken off.
List<PhasedStep> phasedStepsFromAi(
  List<String> english, {
  List<String>? shown,
}) {
  return [
    for (var i = 0; i < english.length; i++)
      () {
        final line = (shown != null && i < shown.length)
            ? shown[i]
            : english[i];
        final body = line.replaceFirst(_phaseLabel, '').trim();
        final cut = body.indexOf(' — ');
        return PhasedStep(
          phase: _phaseOf(english[i]),
          text: cut > 0 ? body.substring(0, cut).trim() : body,
          why: cut > 0 ? body.substring(cut + 3).trim() : null,
          imageKey: firstAidStepImageKey(english[i]),
        );
      }(),
  ];
}

/// First Aid steps grouped as Before / During / After, each as a bullet (or,
/// when [numbered], a number that carries on from one phase to the next) with
/// its picture (when it has one) and an optional "why" line. Steps without a
/// phase (older saved entries) are listed first, under no heading.
class FirstAidStepList extends StatelessWidget {
  final List<PhasedStep> steps;
  final String Function(GuidePhase phase) phaseLabel;
  final String whyLabel;
  final bool numbered;

  /// Number each step in a small maroon circle (white number) instead of "1."
  /// text; only when [numbered].
  final bool circleNumbers;

  /// The look of the Before / During / After headings (the primary colour,
  /// bold, by default).
  final TextStyle? phaseStyle;

  const FirstAidStepList({
    super.key,
    required this.steps,
    required this.phaseLabel,
    required this.whyLabel,
    this.numbered = false,
    this.circleNumbers = false,
    this.phaseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <GuidePhase?>[null, ...GuidePhase.values];
    final children = <Widget>[];
    var number = 0;

    for (final phase in groups) {
      final inPhase = steps.where((s) => s.phase == phase).toList();
      if (inPhase.isEmpty) continue;
      if (phase != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              phaseLabel(phase),
              style:
                  phaseStyle ??
                  theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      }
      for (final step in inPhase) {
        number++;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered && circleNumbers)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 2),
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$number',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    numbered ? '$number.  ' : '•  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                FirstAidStepImage(imageKey: step.imageKey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.text, style: theme.textTheme.bodyMedium),
                      if (step.why != null && step.why!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$whyLabel ${step.why}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
