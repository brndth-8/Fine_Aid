import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminReportsAnalytics extends StatefulWidget {
  const AdminReportsAnalytics({super.key});

  @override
  State<AdminReportsAnalytics> createState() => _AdminReportsAnalyticsState();
}

class _AdminReportsAnalyticsState extends State<AdminReportsAnalytics> {
  late final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  late final Stream<QuerySnapshot> _autoReferralsStream = FirebaseFirestore
      .instance
      .collectionGroup('journalEntries')
      .where('feelingBetter', isEqualTo: false)
      .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _journalEntriesStream =
      FirebaseFirestore.instance.collectionGroup('journalEntries').snapshots();

  String _reportType = 'App usage summary';
  String _outputFormat = 'CSV';
  bool _generating = false;

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      if (_outputFormat != 'CSV' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF/Excel export isn\'t available yet — exporting as CSV instead.',
            ),
          ),
        );
      }

      switch (_reportType) {
        case 'User activity':
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .get();
          await exportAdminCsv(
            filename: 'fine_aid_user_activity.csv',
            headers: const ['Username', 'Email', 'Joined', 'Status'],
            rows: snapshot.docs.map((doc) {
              final data = doc.data();
              final ts = data['createdAt'] as Timestamp?;
              return [
                data['username'] ?? '',
                data['email'] ?? '',
                ts?.toDate().toIso8601String() ?? '',
                data['deactivated'] == true ? 'Inactive' : 'Active',
              ];
            }).toList(),
          );
        case 'Journal log':
          final snapshot = await FirebaseFirestore.instance
              .collectionGroup('journalEntries')
              .get();
          await exportAdminCsv(
            filename: 'fine_aid_journal_log.csv',
            headers: const [
              'Title',
              'Classification',
              'Created',
              'Feeling better',
            ],
            rows: snapshot.docs.map((doc) {
              final data = doc.data();
              final ts = data['createdAt'] as Timestamp?;
              return [
                data['title'] ?? '',
                data['classification'] ?? '',
                ts?.toDate().toIso8601String() ?? '',
                data['feelingBetter']?.toString() ?? '',
              ];
            }).toList(),
          );
        case 'Auto-referral report':
          final snapshot = await FirebaseFirestore.instance
              .collectionGroup('journalEntries')
              .where('feelingBetter', isEqualTo: false)
              .get();
          await exportAdminCsv(
            filename: 'fine_aid_auto_referrals.csv',
            headers: const ['Title', 'Classification', 'Created'],
            rows: snapshot.docs.map((doc) {
              final data = doc.data();
              final ts = data['createdAt'] as Timestamp?;
              return [
                data['title'] ?? '',
                data['classification'] ?? '',
                ts?.toDate().toIso8601String() ?? '',
              ];
            }).toList(),
          );
        default: // 'App usage summary'
          final results = await Future.wait([
            FirebaseFirestore.instance.collection('users').count().get(),
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
          await exportAdminCsv(
            filename: 'fine_aid_app_usage_summary.csv',
            headers: const ['Metric', 'Value'],
            rows: [
              ['Total users', results[0].count ?? 0],
              ['Total journal entries', results[1].count ?? 0],
              ['Pending escalations', results[2].count ?? 0],
              ['Generated', DateTime.now().toIso8601String()],
            ],
          );
      }
      logAdminAction('Generated report "$_reportType"');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report generation failed: $e')));
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _usersStream,
                        builder: (context, snap) => AdminAnalyticsCard(
                          label: 'Total users',
                          value: snap.hasError
                              ? '—'
                              : '${snap.data?.docs.length ?? 0}',
                          change: snap.hasError
                              ? 'Failed to load'
                              : '↑ Growing',
                          changeColor: snap.hasError
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: AdminAnalyticsCard(
                        label: 'Total AI scans',
                        value: '—',
                        change: 'Requires AI integration',
                        changeColor: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _autoReferralsStream,
                        builder: (context, snap) => AdminAnalyticsCard(
                          label: 'Auto-referrals',
                          value: snap.hasError
                              ? '—'
                              : '${snap.data?.docs.length ?? 0}',
                          change: snap.hasError ? 'Failed to load' : null,
                          changeColor: snap.hasError ? Colors.red : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: AdminAnalyticsCard(
                        label: 'AI accuracy',
                        value: '—',
                        change: 'Requires AI integration',
                        changeColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildClassBreakdown(theme)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildGenerateReport(context, theme),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassBreakdown(ThemeData theme) {
    final classifications = [
      'Injury (Wounds/laceration/Abrasion)',
      'Burns',
      'Skin Issues',
      'Animal Bite/Scratch',
    ];

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
          Text(
            'Injury scan types',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _journalEntriesStream,
            builder: (context, snapshot) {
              final fallback = adminSnapshotFallback(snapshot);
              if (fallback != null) return fallback;

              final docs = snapshot.data!.docs;
              final Map<String, int> counts = {
                for (var c in classifications) c: 0,
              };
              for (final doc in docs) {
                final c = doc.data()['classification'] as String?;
                if (c != null && counts.containsKey(c)) {
                  counts[c] = counts[c]! + 1;
                }
              }
              final total = counts.values.fold(0, (a, b) => a + b);

              return Column(
                children: counts.entries.map((e) {
                  final pct = total > 0 ? e.value / total : 0.0;
                  final label = e.key.split('(').first.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(label, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          flex: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toInt()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
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
          const SizedBox(height: 12),
          Text(
            'Output format',
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _outputFormat,
            items: [
              'CSV',
              'PDF report',
              'Excel',
            ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _outputFormat = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
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
                      : const Text('Generate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Scheduled report runs aren't set up yet — this "
                          'needs a backend job runner. Use Generate for an '
                          'on-demand export instead.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
