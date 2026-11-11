import 'package:flutter/material.dart';
import '../../data/health_profile_cautions.dart';
import '../../data/health_profile_summary.dart';
import '../../i18n/assessment_strings.dart';
import '../../i18n/checklist_strings.dart';

/// The blue "Based on Your Health Profile" box shown above first aid steps
/// (the AI scan result and the First Aid Kit): the health conditions the
/// person has (from the Health Profile, or what a guest said), the medication
/// they take, and a short caution for each. Every condition is named, also one
/// the person typed because it was not in the list.
///
/// Nothing is drawn when there is nothing to say.
class HealthProfileBox extends StatelessWidget {
  const HealthProfileBox({
    super.key,
    required this.profile,
    this.medications = const [],
    required this.tagalog,
    this.bottomPadding = 12,
  });

  /// The Health Profile's map (or a guest's answers in the same shape).
  final Map<String, dynamic>? profile;
  final List<String> medications;
  final bool tagalog;
  final double bottomPadding;

  /// The lines the box shows (empty = the box is hidden).
  static List<String> linesFor({
    required Map<String, dynamic>? profile,
    required List<String> medications,
    required bool tagalog,
  }) {
    final a = tagalog ? AssessmentStrings.tl : AssessmentStrings.en;
    final c = tagalog ? ChecklistStrings.tl : ChecklistStrings.en;
    final conditions = profileConditionLabels(profile, c);
    return [
      if (conditions.isNotEmpty)
        a.profileConditionsLine.replaceFirst(
          '{list}',
          joinWithAnd(conditions, a.listAnd),
        ),
      if (medications.isNotEmpty)
        a.ackTake.replaceFirst('{list}', joinWithAnd(medications, a.listAnd)),
      ...healthProfileCautions(profile, tagalog: tagalog),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = linesFor(
      profile: profile,
      medications: medications,
      tagalog: tagalog,
    );
    if (lines.isEmpty) return const SizedBox.shrink();
    final a = tagalog ? AssessmentStrings.tl : AssessmentStrings.en;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.profileBoxTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
