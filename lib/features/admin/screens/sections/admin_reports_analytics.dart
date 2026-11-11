import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_activity_report.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_file_download_stub.dart'
    if (dart.library.js_interop) '../widgets/admin_file_download_web.dart';
import '../widgets/admin_performance_card.dart' show ScanTotals, loadScanTotals;
import '../widgets/admin_report_pdf.dart';
import '../widgets/admin_shared_widgets.dart';

/// Every category name the app saves in a journal entry's `classification`,
/// grouped into the lines of the "Injury scan types" chart. The AI scan saves
/// the WoundCategories names (Laceration, Minor Cut, Scratch, Abrasion,
/// Puncture Wound, Burn, Bruise, Swelling, Rash, Other Skin Issue, Unable to
/// Classify); the manual journal form saves its own (Injury (Wounds/laceration/
/// Abrasion), Burns, Skin Issues, Scratch, Animal Scratch). The chart used to
/// count only four of the manual names, so almost every AI scan was missing.
/// Each name is in exactly one group; anything not listed (an unknown name, an
/// older version's category, "Unable to Classify", or no category at all) is
/// caught by the last line, so the lines always add up to every entry.
const List<(String, List<String>)> kInjuryGroups = [
  (
    'Cuts, scrapes & punctures',
    [
      'Laceration',
      'Minor Cut',
      'Puncture Wound',
      'Abrasion',
      'Scratch',
      'Injury (Wounds/laceration/Abrasion)',
    ],
  ),
  ('Burns', ['Burn', 'Burns']),
  ('Bruises & swelling', ['Bruise', 'Swelling']),
  ('Skin issues', ['Rash', 'Other Skin Issue', 'Skin Issues']),
  ('Animal bites & scratches', ['Animal Scratch', 'Animal Bite/Scratch']),
];

/// The catch-all line's name.
const String kInjuryOtherLabel = 'Unable to classify / other';

/// The chart's lines: one per group, then the catch-all. Each differs in
/// colour, marker AND line style, so they read without colour. Counted
/// server-side per day or month (the journalEntries classification +
/// createdAt index; `whereIn` is served by the same index).
List<TrendSeries> _injurySeries(ColorScheme scheme) {
  final entries = FirebaseFirestore.instance.collectionGroup('journalEntries');
  final looks = <(Color, TrendMarker, TrendDash)>[
    (scheme.primary, TrendMarker.circle, TrendDash.solid),
    (Colors.deepOrange.shade700, TrendMarker.triangle, TrendDash.dotted),
    (Colors.indigo.shade400, TrendMarker.diamond, TrendDash.dashed),
    (Colors.teal.shade700, TrendMarker.square, TrendDash.solid),
    (Colors.purple.shade400, TrendMarker.circle, TrendDash.dashed),
  ];
  return [
    for (var i = 0; i < kInjuryGroups.length; i++)
      TrendSeries(
        name: kInjuryGroups[i].$1,
        query: entries.where('classification', whereIn: kInjuryGroups[i].$2),
        color: looks[i].$1,
        marker: looks[i].$2,
        dash: looks[i].$3,
      ),
    TrendSeries(
      name: kInjuryOtherLabel,
      query: entries, // everything; the lines above are taken off it
      color: Colors.grey.shade600,
      marker: TrendMarker.square,
      dash: TrendDash.dotted,
      remainder: true,
    ),
  ];
}

class AdminReportsAnalytics extends StatefulWidget {
  const AdminReportsAnalytics({
    super.key,
    this.onOpenUsers,
    this.onOpenAiScans,
    this.onOpenAutoReferrals,
    this.onOpenPerformance,
  });

  /// Where each summary card leads (null leaves a card as plain display).
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenAiScans;
  final VoidCallback? onOpenAutoReferrals;
  final VoidCallback? onOpenPerformance;

  @override
  State<AdminReportsAnalytics> createState() => _AdminReportsAnalyticsState();
}

class _AdminReportsAnalyticsState extends State<AdminReportsAnalytics> {
  // The three stat cards use server-side count() aggregates instead of
  // streaming every document just to read `.length`.
  late final Future<int?> _usersCount = _count(
    FirebaseFirestore.instance
        .collection('users')
        .where('registrationComplete', isEqualTo: true),
  );

  late final Future<int?> _autoReferralsCount = _count(
    FirebaseFirestore.instance
        .collectionGroup('journalEntries')
        .where('feelingBetter', isEqualTo: false),
  );

  // Same 'source': 'ai_camera' marker used on the dashboard's AI scans card.
  late final Future<int?> _aiScansCount = _count(
    FirebaseFirestore.instance
        .collectionGroup('journalEntries')
        .where('source', isEqualTo: 'ai_camera'),
  );

  late final Future<ScanTotals> _scanTotals = loadScanTotals();

  late final Future<int?> _usersThisMonth = _count(
    FirebaseFirestore.instance
        .collection('users')
        .where('registrationComplete', isEqualTo: true)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(DateTime.now().year, DateTime.now().month),
          ),
        ),
  );

  Future<int?> _count(Query<Map<String, dynamic>> query) async {
    try {
      return (await query.count().get()).count;
    } catch (_) {
      return null;
    }
  }

  String _countText(AsyncSnapshot<int?> snap) {
    if (snap.connectionState != ConnectionState.done) return '…';
    return snap.data?.toString() ?? '—';
  }

  bool _countFailed(AsyncSnapshot<int?> snap) =>
      snap.connectionState == ConnectionState.done && snap.data == null;

  String _reportType = 'App usage summary';
  bool _generating = false;

  /// Most rows a report PDF holds (readable, and quick to build in the
  /// browser); a note on the PDF says when a report was cut off.
  static const int _rowLimit = 5000;

  static final _when = DateFormat('MMM d, y h:mm a');

  String _stamp(Object? ts) => ts is Timestamp ? _when.format(ts.toDate()) : '';

  /// Builds the chosen report as a PDF and downloads it.
  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      late final String filename;
      late final List<String> headers;
      late final List<List<String>> rows;
      late final List<int> flex;
      var cutOff = false;
      switch (_reportType) {
        case 'User activity':
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('registrationComplete', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(_rowLimit)
              .get();
          cutOff = snapshot.docs.length >= _rowLimit;
          filename = 'fine_aid_user_activity';
          headers = const ['Username', 'Email', 'Joined', 'Status'];
          flex = const [2, 3, 2, 1];
          rows = snapshot.docs.map((doc) {
            final data = doc.data();
            return [
              '${data['username'] ?? ''}',
              '${data['email'] ?? ''}',
              _stamp(data['createdAt']),
              data['deactivated'] == true ? 'Inactive' : 'Active',
            ];
          }).toList();
        case 'Journal log':
          final snapshot = await FirebaseFirestore.instance
              .collectionGroup('journalEntries')
              .limit(_rowLimit)
              .get();
          cutOff = snapshot.docs.length >= _rowLimit;
          filename = 'fine_aid_journal_log';
          headers = const [
            'Title',
            'Classification',
            'Created',
            'Feeling better',
          ];
          flex = const [3, 3, 2, 1];
          rows = snapshot.docs.map((doc) {
            final data = doc.data();
            return [
              '${data['title'] ?? ''}',
              '${data['classification'] ?? ''}',
              _stamp(data['createdAt']),
              switch (data['feelingBetter']) {
                true => 'Yes',
                false => 'No',
                _ => '',
              },
            ];
          }).toList();
        case 'Auto-referral report':
          final snapshot = await FirebaseFirestore.instance
              .collectionGroup('journalEntries')
              .where('feelingBetter', isEqualTo: false)
              .limit(_rowLimit)
              .get();
          cutOff = snapshot.docs.length >= _rowLimit;
          filename = 'fine_aid_auto_referrals';
          headers = const ['Title', 'Classification', 'Created'];
          flex = const [3, 3, 2];
          rows = snapshot.docs.map((doc) {
            final data = doc.data();
            return [
              '${data['title'] ?? ''}',
              '${data['classification'] ?? ''}',
              _stamp(data['createdAt']),
            ];
          }).toList();
        default: // 'App usage summary'
          final results = await Future.wait([
            FirebaseFirestore.instance
                .collection('users')
                .where('registrationComplete', isEqualTo: true)
                .count()
                .get(),
            FirebaseFirestore.instance
                .collectionGroup('journalEntries')
                .count()
                .get(),
            FirebaseFirestore.instance
                .collectionGroup('journalEntries')
                .where('feelingBetter', isEqualTo: false)
                .count()
                .get(),
          ]);
          filename = 'fine_aid_app_usage_summary';
          headers = const ['Metric', 'Value'];
          flex = const [3, 1];
          rows = [
            ['Total users', '${results[0].count ?? 0}'],
            ['Total journal entries', '${results[1].count ?? 0}'],
            ['Pending escalations', '${results[2].count ?? 0}'],
          ];
      }
      final now = DateTime.now();
      final bytes = await buildAdminReportPdf(
        title: _reportType,
        headers: headers,
        rows: rows,
        columnFlex: flex,
        generatedAt: now,
        generatedBy: FirebaseAuth.instance.currentUser?.email ?? 'an admin',
        note: cutOff ? 'first $_rowLimit entries only' : null,
      );
      final name = '${filename}_${DateFormat('yyyy-MM-dd').format(now)}.pdf';
      await downloadFile(
        filename: name,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      logAdminAction('Generated report "$_reportType"', reason: 'pdf_export');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded $name.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't create the PDF: ${adminErrorMessage(e)}"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'Reports & analytics',
          subtitle:
              'Generate reports on app usage, auto-referral triggers, and user activity for clinical and system oversight.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(adminIsNarrow(context) ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminResponsiveRow(
                  breakpoint: 880,
                  children: [
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _usersCount,
                        builder: (context, snap) => FutureBuilder<int?>(
                          future: _usersThisMonth,
                          builder: (context, monthSnap) {
                            final month = monthSnap.data;
                            return AdminAnalyticsCard(
                              onTap: widget.onOpenUsers,
                              label: 'Total users',
                              value: _countText(snap),
                              change: _countFailed(snap)
                                  ? 'Failed to load'
                                  : month == null
                                  ? null
                                  : month == 0
                                  ? 'No new users this month'
                                  : '↑ +$month this month',
                              changeColor: _countFailed(snap)
                                  ? Colors.red
                                  : month == 0
                                  ? Colors.grey
                                  : Colors.green,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _aiScansCount,
                        builder: (context, snap) => AdminAnalyticsCard(
                          onTap: widget.onOpenAiScans,
                          label: 'Total AI scans',
                          value: _countText(snap),
                          change: _countFailed(snap) ? 'Failed to load' : null,
                          changeColor: _countFailed(snap) ? Colors.red : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _autoReferralsCount,
                        builder: (context, snap) => AdminAnalyticsCard(
                          onTap: widget.onOpenAutoReferrals,
                          label: 'Auto-referrals',
                          value: _countText(snap),
                          change: _countFailed(snap) ? 'Failed to load' : null,
                          changeColor: _countFailed(snap) ? Colors.red : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<ScanTotals>(
                        future: _scanTotals,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return AdminAnalyticsCard(
                              onTap: widget.onOpenPerformance,
                              label: 'AI Scan Performance',
                              value: '…',
                            );
                          }
                          if (snap.hasError) {
                            return AdminAnalyticsCard(
                              onTap: widget.onOpenPerformance,
                              label: 'AI Scan Performance',
                              value: '—',
                              change: 'Failed to load',
                              changeColor: Colors.red,
                            );
                          }
                          // (successful scans / total scans) x 100, between 0%
                          // and 100%, and 0% when there are no scans yet.
                          final scans = snap.data!;
                          final pct = scans.performance;
                          return AdminAnalyticsCard(
                            onTap: widget.onOpenPerformance,
                            label: 'AI Scan Performance',
                            value: pct == pct.roundToDouble()
                                ? '${pct.round()}%'
                                : '${pct.toStringAsFixed(1)}%',
                            change: scans.total == 0
                                ? 'No scans yet'
                                : '${scans.successful} of ${scans.total} '
                                      'scans succeeded',
                            changeColor: Colors.green,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const AdminTrendCard(
                  title: 'Activity over time',
                  caption: 'New users, journal entries and AI scans.',
                ),
                const SizedBox(height: 20),
                AdminResponsiveRow(
                  breakpoint: 900,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: const AdminTrendCard(
                        title: 'Injury scan types',
                        caption:
                            'AI scans and manual entries saved to the journal, by type.',
                        seriesBuilder: _injurySeries,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildGenerateReport(context, theme),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const AdminActivityReport(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateReport(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generate report',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 16),
          Text(
            'Report type',
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _reportType,
            items: [
              'App usage summary',
              'User activity',
              'Journal log',
              'Auto-referral report',
            ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _reportType = v!),
          ),
          const SizedBox(height: 8),
          Text(
            'Downloads as a PDF file.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _generating ? null : _generateReport,
            child: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Generate PDF'),
          ),
        ],
      ),
    );
  }
}
