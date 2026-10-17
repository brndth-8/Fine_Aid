import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_shared_widgets.dart';

class _Perf {
  const _Perf(this.total, this.failed, this.asOf);
  final int total;
  final int failed;
  final DateTime asOf;

  double? get failureRate => total <= 0 ? null : failed / total * 100;
}

/// Dashboard performance indicator: how many AI scans did not complete.
///
/// Real data, one query: the per-account counters the app already keeps at
/// users/{uid}/aiScanStats/summary are summed server-side with a single
/// aggregation over the `aiScanStats` collection group (no documents are
/// downloaded). Only signed-in users' scans are counted; a scan made while
/// signed out is only tracked on that device. "As of" is when the numbers
/// were read, and the refresh button reads them again.
class AdminPerformanceCard extends StatefulWidget {
  const AdminPerformanceCard({super.key});

  @override
  State<AdminPerformanceCard> createState() => _AdminPerformanceCardState();
}

class _AdminPerformanceCardState extends State<AdminPerformanceCard> {
  late Future<_Perf> _future = _load();

  Future<_Perf> _load() async {
    final snap = await FirebaseFirestore.instance
        .collectionGroup('aiScanStats')
        .aggregate(sum('total'), sum('failed'))
        .get();
    return _Perf(
      snap.getSum('total')?.round() ?? 0,
      snap.getSum('failed')?.round() ?? 0,
      DateTime.now(),
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI scan performance',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<_Perf>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminErrorMessage(snap.error),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                );
              }
              final perf = snap.data!;
              final rate = perf.failureRate;
              final asOf = DateFormat('MMM d, h:mm a').format(perf.asOf);
              if (rate == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No data yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan counts appear once users have run scans.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'As of $asOf',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of scans did not complete',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${perf.failed} of ${perf.total} scans (signed-in users)',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As of $asOf',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
