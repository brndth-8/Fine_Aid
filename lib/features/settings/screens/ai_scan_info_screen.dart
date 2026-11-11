import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../i18n/ai_scan_stats_strings.dart';
import '../../../services/ai_scan_stats_service.dart';

const Color _maroon = Color(0xFF780000);
const Color _pink = Color(0xFFFDF0EE);
const Color _ringBlue = Color(0xFF0A6CFF);
const Color _ringTrack = Color(0xFFB7D3F7);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(s.screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
    );
  }

  Widget _content(
    ThemeData theme,
    AiScanStatsStrings s,
    AiScanStats stats,
    bool isGuest,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text(
          s.intro,
          style: theme.textTheme.bodyMedium?.copyWith(color: _maroon),
        ),
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
        const SizedBox(height: 14),
        _reliabilityCard(theme, s, stats),
        const SizedBox(height: 14),
        _ratesCard(theme, s, stats),
        const SizedBox(height: 14),
        _listCard(theme, Icons.bar_chart, s.scanSummary, [
          (Icons.document_scanner_outlined, s.totalScans, '${stats.total}'),
          (Icons.check_circle_outline, s.completed, '${stats.success}'),
          (Icons.cancel_outlined, s.failed, '${stats.failed}'),
          (Icons.back_hand_outlined, s.noWoundFound, '${stats.noWound}'),
          (
            Icons.thumb_up_alt_outlined,
            s.ratedCorrect,
            '${stats.ratedCorrect}',
          ),
          (
            Icons.thumb_down_alt_outlined,
            s.ratedNotCorrect,
            '${stats.ratedWrong}',
          ),
        ]),
        if (stats.failedByReason.isNotEmpty) ...[
          const SizedBox(height: 14),
          _listCard(theme, Icons.warning_amber_rounded, s.whyFailed, [
            for (final e in stats.failedByReason.entries)
              (null, s.reasons[e.key] ?? e.key.name, '${e.value}'),
          ]),
        ],
      ],
    );
  }

  /// The maroon card: the reliability ring, its name and what it means.
  Widget _reliabilityCard(
    ThemeData theme,
    AiScanStatsStrings s,
    AiScanStats stats,
  ) {
    final value = stats.reliability;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _maroon,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: ((value ?? 0) / 100).clamp(0.0, 1.0),
                    strokeWidth: 12,
                    color: _ringBlue,
                    backgroundColor: _ringTrack,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: FittedBox(
                    child: Text(
                      s.percent(value),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.reliability,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.reliabilityNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Success rate | Failure rate | Satisfaction, side by side.
  Widget _ratesCard(ThemeData theme, AiScanStatsStrings s, AiScanStats stats) {
    Widget cell(
      IconData icon,
      String label,
      String value, {
      bool small = false,
    }) => Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _maroon,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style:
                (small
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(color: _maroon),
          ),
        ],
      ),
    );
    Widget divider() =>
        Container(width: 1, height: 64, color: _maroon.withValues(alpha: 0.5));
    final satisfaction = stats.accuracyRate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: _maroon.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(Icons.check, s.successRate, s.percent(stats.successRate)),
            divider(),
            cell(Icons.close, s.failureRate, s.percent(stats.failureRate)),
            divider(),
            cell(
              Icons.star,
              s.accuracyRate,
              s.percent(satisfaction, missing: s.noFeedbackYet),
              small: satisfaction == null,
            ),
          ],
        ),
      ),
    );
  }

  /// A bordered card: a pink title strip, then rows (icon, label, count).
  Widget _listCard(
    ThemeData theme,
    IconData headerIcon,
    String title,
    List<(IconData?, String, String)> rows,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _maroon.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: _maroon, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: _maroon),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade400),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: rows[i].$1 == null
                        ? null
                        : Icon(rows[i].$1, color: _maroon, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(rows[i].$2, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _pink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      rows[i].$3,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _maroon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
