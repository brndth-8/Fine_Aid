import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/api/gemini_service.dart' show WoundCategories;
import 'admin_charts.dart';
import 'admin_shared_widgets.dart';

/// Scan totals across every signed-in account's counters (the app keeps them
/// at users/{uid}/aiScanStats/summary).
///
/// A scan counts as successful when it was processed without a technical
/// failure and wasn't marked wrong by the user. "No wound found" is a
/// correct result, so it counts as successful too. Every percentage here is
/// (part / total) x 100, kept between 0 and 100, and 0% (never NaN) when there
/// is nothing to divide by.
class ScanTotals {
  const ScanTotals(
    this.total,
    this.failed,
    this.erroneous,
    this.asOf, {
    this.satisfied = 0,
  });
  final int total;
  final int failed;

  /// Scans the user marked as a wrong result ("Not satisfied").
  final int erroneous;
  final DateTime asOf;

  /// Scans the user marked as a good result ("Satisfied").
  final int satisfied;

  /// Scans the user answered the satisfaction question for.
  int get rated => satisfied + erroneous;

  /// (satisfied / rated scans) x 100; null until a scan has been rated (never
  /// 0% or NaN for "no answers yet").
  double? get satisfactionRate => rated <= 0 ? null : percent(satisfied, rated);

  int get successful =>
      (total - failed - erroneous).clamp(0, total < 0 ? 0 : total);

  /// (part / total) x 100, always within 0-100 (counters that disagree can't
  /// push it negative or past 100), and 0 when [total] is zero or less.
  static double percent(num part, num total) =>
      total <= 0 ? 0 : (part / total * 100).clamp(0.0, 100.0).toDouble();

  /// (successful scans / total scans) x 100; 0% when there are none yet.
  double get performance => percent(successful, total);

  /// (scans that failed to process / total scans) x 100; 0% when none yet.
  double get failureRate => percent(failed, total);
}

/// Four single-field server-side sums (a multi-field sum would need a
/// combined index); no documents are downloaded. Only signed-in users'
/// scans are counted, since a signed-out scan is only tracked on that device.
Future<ScanTotals> loadScanTotals() async {
  final group = FirebaseFirestore.instance.collectionGroup('aiScanStats');
  final results = await Future.wait([
    group.aggregate(sum('total')).get(),
    group.aggregate(sum('failed')).get(),
    group.aggregate(sum('ratedWrong')).get(),
    group.aggregate(sum('ratedCorrect')).get(),
  ]);
  return ScanTotals(
    results[0].getSum('total')?.round() ?? 0,
    results[1].getSum('failed')?.round() ?? 0,
    results[2].getSum('ratedWrong')?.round() ?? 0,
    DateTime.now(),
    satisfied: results[3].getSum('ratedCorrect')?.round() ?? 0,
  );
}

/// How many scans of one wound type were rated satisfied / not satisfied.
class CategorySatisfaction {
  const CategorySatisfaction(this.category, this.satisfied, this.notSatisfied);
  final String category;
  final int satisfied;
  final int notSatisfied;

  int get rated => satisfied + notSatisfied;

  /// null when nothing of this type has been rated.
  double? get rate => rated <= 0 ? null : satisfied / rated * 100;
}

/// Satisfaction per wound type, from the AI scans saved to a journal (a scan
/// rated but never saved only shows in the overall figure). Two server-side
/// counts per type; nothing is downloaded, no names or text. Types nobody has
/// rated are left out.
Future<List<CategorySatisfaction>> loadSatisfactionByCategory(
  List<String> categories,
) async {
  final scans = FirebaseFirestore.instance
      .collectionGroup('journalEntries')
      .where('source', isEqualTo: 'ai_camera');
  Future<int> count(String category, bool satisfied) => scans
      .where('classification', isEqualTo: category)
      .where('resultSatisfied', isEqualTo: satisfied)
      .count()
      .get()
      .then((s) => s.count ?? 0);
  final rows = await Future.wait([
    for (final c in categories)
      Future.wait([
        count(c, true),
        count(c, false),
      ]).then((v) => CategorySatisfaction(c, v[0], v[1])),
  ]);
  return [
    for (final r in rows)
      if (r.rated > 0) r,
  ];
}

/// Scans that failed to process and scans marked wrong, per day.
class ScanErrorsByDay {
  const ScanErrorsByDay(
    this.days,
    this.failed,
    this.erroneous, {
    this.satisfied = const [],
  });
  final List<DateTime> days;
  final List<int> failed;
  final List<int> erroneous;

  /// "Satisfied" answers per day (empty when not read).
  final List<int> satisfied;

  bool get isEmpty =>
      failed.every((v) => v == 0) && erroneous.every((v) => v == 0);
}

/// The last [days] days of error events. The app writes a small document per
/// account per day only when a scan fails or is marked wrong, so this reads
/// a handful of documents, not one per scan.
Future<ScanErrorsByDay> loadScanErrorsByDay({int days = 30}) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final starts = [
    for (var i = days - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
  final snap = await FirebaseFirestore.instance
      .collectionGroup('aiScanDaily')
      .where('day', isGreaterThanOrEqualTo: Timestamp.fromDate(starts.first))
      .limit(5000)
      .get();
  final failed = List<int>.filled(days, 0);
  final erroneous = List<int>.filled(days, 0);
  final satisfied = List<int>.filled(days, 0);
  for (final doc in snap.docs) {
    final day = (doc.data()['day'] as Timestamp?)?.toDate();
    if (day == null) continue;
    final i = DateUtils.dateOnly(day).difference(starts.first).inDays;
    if (i < 0 || i >= days) continue;
    failed[i] += (doc.data()['failed'] as num?)?.toInt() ?? 0;
    erroneous[i] += (doc.data()['erroneous'] as num?)?.toInt() ?? 0;
    satisfied[i] += (doc.data()['satisfied'] as num?)?.toInt() ?? 0;
  }
  return ScanErrorsByDay(starts, failed, erroneous, satisfied: satisfied);
}

/// Scans performed per day over the last [days] days: the AI scans users saved
/// (journal entries from the AI Camera, the same figure as the Total AI scans
/// card). One server-side count() per day, nothing is downloaded.
Future<List<int>> loadScansPerDay(List<DateTime> days) {
  final entries = FirebaseFirestore.instance
      .collectionGroup('journalEntries')
      .where('source', isEqualTo: 'ai_camera');
  return Future.wait([
    for (final start in days)
      entries
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where(
            'createdAt',
            isLessThan: Timestamp.fromDate(
              DateTime(start.year, start.month, start.day + 1),
            ),
          )
          .count()
          .get()
          .then((snap) => snap.count ?? 0),
  ]);
}

/// Dashboard performance indicator: how many AI scans did not complete, with
/// a graph of the scans performed, failed and marked wrong per day. "As of" is
/// when the numbers were read, and the refresh button reads them again.
class AdminPerformanceCard extends StatefulWidget {
  const AdminPerformanceCard({super.key, this.fillHeight = false});

  /// Fill the height the parent gives (scrolling inside if it is short), so
  /// the card can sit in a panel of a set size.
  final bool fillHeight;

  @override
  State<AdminPerformanceCard> createState() => _AdminPerformanceCardState();
}

class _Loaded {
  const _Loaded(this.totals, this.daily, this.performed, this.byCategory);
  final ScanTotals totals;

  /// Satisfaction per wound type; null when it couldn't be read.
  final List<CategorySatisfaction>? byCategory;

  /// Null when the graph's data couldn't be read (the totals still show).
  final ScanErrorsByDay? daily;

  /// Scans performed per day, aligned with [daily]'s days; null if unreadable.
  final List<int>? performed;
}

class _AdminPerformanceCardState extends State<AdminPerformanceCard> {
  late Future<_Loaded> _future = _load();

  Future<_Loaded> _load() async {
    final totals = await loadScanTotals();
    ScanErrorsByDay? daily;
    List<int>? performed;
    List<CategorySatisfaction>? byCategory;
    try {
      daily = await loadScanErrorsByDay();
      performed = await loadScansPerDay(daily.days);
    } catch (_) {}
    try {
      byCategory = await loadSatisfactionByCategory(WoundCategories.all);
    } catch (_) {}
    return _Loaded(totals, daily, performed, byCategory);
  }

  void _refresh() => setState(() => _future = _load());

  Widget _figure(ThemeData theme, String label, int value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
      ),
    ],
  );

  List<TrendSeries> _series(ColorScheme scheme, {required bool withScans}) => [
    if (withScans)
      TrendSeries(
        name: 'Scans performed',
        color: Colors.blueGrey.shade700,
        marker: TrendMarker.triangle,
        dash: TrendDash.solid,
      ),
    TrendSeries(
      name: 'Failed to process',
      color: scheme.primary,
      marker: TrendMarker.circle,
      dash: TrendDash.solid,
    ),
    TrendSeries(
      name: 'Satisfied',
      color: Colors.green.shade700,
      marker: TrendMarker.diamond,
      dash: TrendDash.dotted,
    ),
    TrendSeries(
      name: 'Not satisfied',
      color: Colors.orange.shade800,
      marker: TrendMarker.square,
      dash: TrendDash.dashed,
    ),
  ];

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
          _body(
            FutureBuilder<_Loaded>(
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
                final perf = snap.data!.totals;
                final daily = snap.data!.daily;
                // The same figure as the Reports card: scans that succeeded.
                final rate = perf.performance;
                final asOf = DateFormat('MMM d, h:mm a').format(perf.asOf);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always shown, 0.0% to 100.0% (0.0% before any scans).
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'of scans succeeded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${perf.successful} of ${perf.total} scans '
                      '(signed-in users; failed or marked wrong are not '
                      'counted)',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 32,
                      runSpacing: 8,
                      children: [
                        _figure(theme, 'Scans (signed-in users)', perf.total),
                        _figure(theme, 'Failed to process', perf.failed),
                        _figure(theme, 'Satisfied', perf.satisfied),
                        _figure(theme, 'Not satisfied', perf.erroneous),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      perf.satisfactionRate == null
                          ? 'Satisfaction: no answers yet'
                          : 'Satisfaction: '
                                '${perf.satisfactionRate!.toStringAsFixed(1)}% '
                                'of ${perf.rated} rated scans',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scans per day (last 30 days)',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    if (daily == null)
                      Text(
                        "Couldn't load the graph.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                      )
                    else ...[
                      AdminLineChart(
                        days: daily.days,
                        series: _series(
                          theme.colorScheme,
                          withScans: snap.data!.performed != null,
                        ),
                        values: [
                          ?snap.data!.performed,
                          daily.failed,
                          daily.satisfied.isEmpty
                              ? List<int>.filled(daily.days.length, 0)
                              : daily.satisfied,
                          daily.erroneous,
                        ],
                      ),
                      if (daily.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'No scan errors recorded',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Satisfaction by wound type (saved scans)',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    if (snap.data!.byCategory == null)
                      Text(
                        "Couldn't load this.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                      )
                    else if (snap.data!.byCategory!.isEmpty)
                      Text(
                        'No answers yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      )
                    else
                      for (final c in snap.data!.byCategory!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${c.category}: ${c.rate!.toStringAsFixed(0)}% '
                            'satisfied (${c.satisfied} of ${c.rated})',
                            style: theme.textTheme.bodySmall,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  /// In a fixed-size panel the body scrolls inside the card instead of
  /// overflowing; otherwise it just takes the space it needs.
  Widget _body(Widget child) => widget.fillHeight
      ? Expanded(child: SingleChildScrollView(child: child))
      : child;
}
