import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../i18n/ai_scan_stats_strings.dart';
import '../../../services/ai_scan_stats_service.dart';

/// Settings > About the AI scan: how many scans were made, how many
/// completed or failed (and why), and the reliability value. Neutral wording
/// only — this describes how often the scan completes, not medical accuracy.
class AiScanInfoScreen extends StatefulWidget {
  /// For tests; defaults to the shared service.
  final AiScanStatsService? service;

  const AiScanInfoScreen({super.key, this.service});

  @override
  State<AiScanInfoScreen> createState() => _AiScanInfoScreenState();
}

class _AiScanInfoScreenState extends State<AiScanInfoScreen> {
  late final Future<AiScanStats> _stats =
      (widget.service ?? AiScanStatsService.instance).load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AiScanStatsStrings.of(context);
    final isGuest = FirebaseAuth.instance.currentUser == null;

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
                ],
              ),
              const SizedBox(height: 8),
              Text(s.screenTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<AiScanStats>(
                  future: _stats,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _content(
                      theme,
                      s,
                      snapshot.data ?? const AiScanStats(),
                      isGuest,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    ThemeData theme,
    AiScanStatsStrings s,
    AiScanStats stats,
    bool isGuest,
  ) {
    return ListView(
      children: [
        Text(s.intro, style: theme.textTheme.bodyMedium),
        if (isGuest) ...[
          const SizedBox(height: 8),
          Text(
            s.guestNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _card(theme, [
          _row(theme, s.reliability, s.percent(stats.reliability), bold: true),
          _row(theme, s.successRate, s.percent(stats.successRate)),
          _row(theme, s.failureRate, s.percent(stats.failureRate)),
          _row(
            theme,
            s.accuracyRate,
            s.percent(stats.accuracyRate, missing: s.noFeedbackYet),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          s.reliabilityNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 16),
        _card(theme, [
          _row(theme, s.totalScans, '${stats.total}'),
          _row(theme, s.completed, '${stats.success}'),
          _row(theme, s.failed, '${stats.failed}'),
          _row(theme, s.noWoundFound, '${stats.noWound}'),
          _row(theme, s.ratedCorrect, '${stats.ratedCorrect}'),
          _row(theme, s.ratedNotCorrect, '${stats.ratedWrong}'),
        ]),
        if (stats.failedByReason.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            s.whyFailed,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _card(theme, [
            for (final e in stats.failedByReason.entries)
              _row(theme, s.reasons[e.key] ?? e.key.name, '${e.value}'),
          ]),
        ],
      ],
    );
  }

  Widget _card(ThemeData theme, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(
    ThemeData theme,
    String label,
    String value, {
    bool bold = false,
  }) {
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          )
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
