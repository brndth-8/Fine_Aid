import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminReportsAnalytics extends StatelessWidget {
  const AdminReportsAnalytics({super.key});

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
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snap) => AdminAnalyticsCard(
                          label: 'Total users',
                          value: '${snap.data?.docs.length ?? 0}',
                          change: '↑ Growing',
                          changeColor: Colors.green,
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
                        stream: FirebaseFirestore.instance
                            .collectionGroup('journalEntries')
                            .where('feelingBetter', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snap) => AdminAnalyticsCard(
                          label: 'Auto-referrals',
                          value: '${snap.data?.docs.length ?? 0}',
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
            stream: FirebaseFirestore.instance
                .collectionGroup('journalEntries')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
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
          const Text(
            'Report type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: 'App usage summary',
            items: [
              'App usage summary',
              'User activity',
              'Journal log',
              'Auto-referral report',
            ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          const Text(
            'Output format',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: 'PDF report',
            items: [
              'PDF report',
              'CSV',
              'Excel',
            ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report generation coming soon.'),
                      ),
                    );
                  },
                  child: const Text('Generate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
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
