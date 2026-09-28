import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api/gemini_service.dart';
import '../../../services/firebase/first_aid_content_service.dart';
import 'assessment_result_screen.dart';

/// Runs the multi-injury batch analysis on a photo already known (via the
/// wound-count pre-check) to contain more than one separate wound, then
/// shows one summary card per injury in treat-first-to-last order. Tapping a
/// card opens [AssessmentResultScreen] for that specific injury, reusing the
/// already-computed result rather than re-analyzing.
class MultiInjuryResultScreen extends StatefulWidget {
  final String imagePath;
  final List<String> woundDescriptions;

  const MultiInjuryResultScreen({
    super.key,
    required this.imagePath,
    this.woundDescriptions = const [],
  });

  @override
  State<MultiInjuryResultScreen> createState() =>
      _MultiInjuryResultScreenState();
}

class _MultiInjuryResultScreenState extends State<MultiInjuryResultScreen> {
  bool _isLoading = true;
  String? _error;
  MultiWoundAssessment? _result;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hintQuery = widget.woundDescriptions.isNotEmpty
          ? widget.woundDescriptions.join(' ')
          : 'wound skin injury first aid care';
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(hintQuery);

      final result = await GeminiService().analyzeMultipleWoundsV2(
        widget.imagePath,
        referenceContext: referenceContext,
      );

      if (!mounted) return;

      // The multi-injury call failed or found nothing usable — fall back to
      // the single-wound flow on this same photo rather than show a broken
      // multi-injury screen.
      if (result.hasError) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AssessmentResultScreen(
              imagePath: widget.imagePath,
              woundHints: widget.woundDescriptions,
            ),
          ),
        );
        return;
      }

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Analysis failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Color _triageColor(TriageLevel triage) {
    switch (triage) {
      case TriageLevel.emergency:
        return Colors.red;
      case TriageLevel.urgentCare:
        return Colors.orange;
      case TriageLevel.firstAid:
        return Colors.amber;
      case TriageLevel.selfCare:
        return Colors.green;
      case TriageLevel.unknown:
        return Colors.grey;
    }
  }

  String _triageLabel(TriageLevel triage) {
    switch (triage) {
      case TriageLevel.emergency:
        return 'Emergency';
      case TriageLevel.urgentCare:
        return 'Urgent Care';
      case TriageLevel.firstAid:
        return 'First Aid';
      case TriageLevel.selfCare:
        return 'Self-Care';
      case TriageLevel.unknown:
        return 'Unknown';
    }
  }

  void _openInjury(int index, int rank, int total) {
    final injuries = _result!.injuries;
    final injury = injuries[index];
    final location = injury.location;
    final label = 'Injury $rank of $total'
        '${location != null && location.trim().isNotEmpty ? ' — $location' : ''}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentResultScreen(
          imagePath: widget.imagePath,
          precomputedAssessment: injury,
          injuryContextLabel: label,
        ),
      ),
    );
  }

  Widget _buildInjuryCard(ThemeData theme, int rank, int index) {
    final injury = _result!.injuries[index];
    final color = _triageColor(injury.triage);
    final location = injury.location;
    final firstStep = injury.firstAidSteps.isNotEmpty
        ? injury.firstAidSteps.first
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openInjury(index, rank, _result!.injuries.length),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        location != null && location.trim().isNotEmpty
                            ? location
                            : injury.category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        _triageLabel(injury.triage),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        injury.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (firstStep != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    firstStep,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing each injury...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _runAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final order = result.priorityOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(widget.imagePath),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.injuries.length} injuries found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shown in the order they should be treated. Tap one for full '
            'first-aid steps.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < order.length; i++)
            _buildInjuryCard(theme, i + 1, order[i]),
        ],
      ),
    );
  }

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
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }
}
