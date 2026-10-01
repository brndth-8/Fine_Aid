import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  late final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  late final Stream<QuerySnapshot> _journalEntriesStream = FirebaseFirestore
      .instance
      .collectionGroup('journalEntries')
      .snapshots();

  late final Stream<QuerySnapshot> _pendingEscalationsStream = FirebaseFirestore
      .instance
      .collectionGroup('journalEntries')
      .where('feelingBetter', isEqualTo: false)
      .snapshots();

  // Counts journal entries the AI Camera flow actually saved (it tags them
  // 'source': 'ai_camera' — see assessment_result_screen.dart). There's no
  // separate "scan attempted" event logged anywhere, so a saved assessment
  // is the closest real signal available for "AI scans".
  late final Stream<QuerySnapshot> _aiScansStream = FirebaseFirestore.instance
      .collectionGroup('journalEntries')
      .where('source', isEqualTo: 'ai_camera')
      .snapshots();

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
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _usersStream,
                        builder: (context, snap) => AdminStatCard(
                          label: 'Registered users',
                          value: snap.hasError
                              ? '—'
                              : '${snap.data?.docs.length ?? 0}',
                          change: snap.hasError ? 'Failed to load' : 'Growing',
                          changeColor: snap.hasError ? Colors.red : null,
                          icon: Icons.people_outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _aiScansStream,
                        builder: (context, snap) => AdminStatCard(
                          label: 'Total AI scans',
                          value: snap.hasError
                              ? '—'
                              : '${snap.data?.docs.length ?? 0}',
                          change: snap.hasError ? 'Failed to load' : null,
                          changeColor: snap.hasError ? Colors.red : null,
                          icon: Icons.camera_alt_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _journalEntriesStream,
                        builder: (context, snap) => AdminStatCard(
                          label: 'Journal entries',
                          value: snap.hasError
                              ? '—'
                              : '${snap.data?.docs.length ?? 0}',
                          change: snap.hasError ? 'Failed to load' : null,
                          changeColor: snap.hasError ? Colors.red : null,
                          icon: Icons.book_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _pendingEscalationsStream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const AdminStatCard(
                              label: 'Pending escalations',
                              value: '—',
                              change: 'Failed to load',
                              changeColor: Colors.red,
                              icon: Icons.warning_amber_outlined,
                            );
                          }
                          final count = snap.data?.docs.length ?? 0;
                          return AdminStatCard(
                            label: 'Pending escalations',
                            value: '$count',
                            change: count > 0 ? 'Needs attention' : 'All clear',
                            changeColor: count > 0 ? Colors.red : Colors.green,
                            icon: Icons.warning_amber_outlined,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildActivityFeed(theme)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildSystemStatus(theme)),
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

  Widget _buildSystemStatus(ThemeData theme) {
    final services = [
      ('API server', true),
      ('AI engine', true),
      ('Database', true),
      ('Email notifications', true),
      ('CDN / storage', false),
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
          Text('System status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...services.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.$1, style: theme.textTheme.bodySmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: s.$2
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.$2 ? 'Online' : 'Degraded',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: s.$2 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
