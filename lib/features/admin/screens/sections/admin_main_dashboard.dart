import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_performance_card.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminMainDashboard extends StatefulWidget {
  final ThemeData theme;
  final VoidCallback? onViewAllActivity;
  const AdminMainDashboard({
    super.key,
    required this.theme,
    this.onViewAllActivity,
  });

  @override
  State<AdminMainDashboard> createState() => _AdminMainDashboardState();
}

class _AdminMainDashboardState extends State<AdminMainDashboard> {
  // Server-side count() aggregates: the cards used to stream every document
  // of these collections just to read `.length`.
  late final Future<int?> _usersCount = _count(
    FirebaseFirestore.instance.collection('users'),
  );

  late final Future<int?> _journalEntriesCount = _count(
    FirebaseFirestore.instance.collectionGroup('journalEntries'),
  );

  late final Future<int?> _pendingEscalationsCount = _count(
    FirebaseFirestore.instance
        .collectionGroup('journalEntries')
        .where('feelingBetter', isEqualTo: false),
  );

  // Counts journal entries the AI Camera flow actually saved (it tags them
  // 'source': 'ai_camera' — see assessment_result_screen.dart). There's no
  // separate "scan attempted" event logged anywhere, so a saved assessment
  // is the closest real signal available for "AI scans".
  late final Future<int?> _aiScansCount = _count(
    FirebaseFirestore.instance
        .collectionGroup('journalEntries')
        .where('source', isEqualTo: 'ai_camera'),
  );

  late final Future<int?> _usersThisMonth = _count(
    FirebaseFirestore.instance
        .collection('users')
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

  /// Card value while loading ("…") or after a failed count ("—").
  String _countText(AsyncSnapshot<int?> snap) {
    if (snap.connectionState != ConnectionState.done) return '…';
    return snap.data?.toString() ?? '—';
  }

  bool _countFailed(AsyncSnapshot<int?> snap) =>
      snap.connectionState == ConnectionState.done && snap.data == null;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activityStream =
      FirebaseFirestore.instance
          .collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .limit(6)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Column(
      children: [
        AdminHeader(
          title: 'Dashboard',
          subtitle:
              'Fine Aid system overview — ${now.day}/${now.month}/${now.year}',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting, Admin', style: theme.textTheme.titleLarge),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _usersCount,
                        builder: (context, snap) => FutureBuilder<int?>(
                          future: _usersThisMonth,
                          builder: (context, monthSnap) {
                            final month = monthSnap.data;
                            return AdminStatCard(
                              label: 'Registered users',
                              value: _countText(snap),
                              change: _countFailed(snap)
                                  ? 'Failed to load'
                                  : month == null
                                  ? null
                                  : month == 0
                                  ? 'No new users this month'
                                  : '+$month this month',
                              changeColor: _countFailed(snap)
                                  ? Colors.red
                                  : month == 0
                                  ? Colors.grey
                                  : null,
                              icon: Icons.people_outline,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _aiScansCount,
                        builder: (context, snap) => AdminStatCard(
                          label: 'Total AI scans',
                          value: _countText(snap),
                          change: _countFailed(snap) ? 'Failed to load' : null,
                          changeColor: _countFailed(snap) ? Colors.red : null,
                          icon: Icons.camera_alt_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _journalEntriesCount,
                        builder: (context, snap) => AdminStatCard(
                          label: 'Journal entries',
                          value: _countText(snap),
                          change: _countFailed(snap) ? 'Failed to load' : null,
                          changeColor: _countFailed(snap) ? Colors.red : null,
                          icon: Icons.book_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _pendingEscalationsCount,
                        builder: (context, snap) {
                          if (_countFailed(snap)) {
                            return const AdminStatCard(
                              label: 'Pending escalations',
                              value: '—',
                              change: 'Failed to load',
                              changeColor: Colors.red,
                              icon: Icons.warning_amber_outlined,
                            );
                          }
                          final count = snap.data ?? 0;
                          final loaded =
                              snap.connectionState == ConnectionState.done;
                          return AdminStatCard(
                            label: 'Pending escalations',
                            value: _countText(snap),
                            change: !loaded
                                ? null
                                : count > 0
                                ? 'Needs attention'
                                : 'All clear',
                            changeColor: count > 0 ? Colors.red : Colors.green,
                            icon: Icons.warning_amber_outlined,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const AdminTrendCard(
                  title: 'Activity over time',
                  caption: 'New users, journal entries and AI scans.',
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildActivityFeed(theme)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildSystemStatus(theme),
                          const SizedBox(height: 16),
                          const AdminPerformanceCard(),
                        ],
                      ),
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

  Widget _buildActivityFeed(ThemeData theme) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent activity feed', style: theme.textTheme.titleMedium),
              TextButton(
                onPressed: widget.onViewAllActivity,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _activityStream,
            builder: (context, snapshot) {
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No recent activity. Admin actions will appear here.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data();
                  final ts = data['timestamp'] as Timestamp?;
                  final timeText = ts != null ? _timeAgo(ts.toDate()) : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['action'] ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(timeText, style: theme.textTheme.bodySmall),
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

  /// Only reports what this page can actually observe. The rows used to be a
  /// hardcoded list (API server, AI engine, CDN … with "Degraded" invented
  /// for one), which showed health that nothing was measuring.
  Widget _buildSystemStatus(ThemeData theme) {
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
          Text('System status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder<int?>(
            future: _usersCount,
            builder: (context, snap) {
              final loading = snap.connectionState != ConnectionState.done;
              final ok = snap.data != null;
              final color = loading
                  ? Colors.grey
                  : ok
                  ? Colors.green
                  : Colors.red;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Database', style: theme.textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loading
                            ? 'Checking…'
                            : ok
                            ? 'Online'
                            : 'Unreachable',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Based on whether this page could read the database just now. '
            'Other services are not monitored here.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
