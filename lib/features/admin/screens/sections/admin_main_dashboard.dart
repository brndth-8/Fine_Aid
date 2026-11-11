import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_performance_card.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminMainDashboard extends StatefulWidget {
  final ThemeData theme;
  final VoidCallback? onViewAllActivity;

  /// The three summary cards open their related pages.
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenAiScans;
  final VoidCallback? onOpenEscalations;

  const AdminMainDashboard({
    super.key,
    required this.theme,
    this.onViewAllActivity,
    this.onOpenUsers,
    this.onOpenAiScans,
    this.onOpenEscalations,
  });

  @override
  State<AdminMainDashboard> createState() => _AdminMainDashboardState();
}

class _AdminMainDashboardState extends State<AdminMainDashboard> {
  /// One size for the three summary cards, at every window width.
  static const double _statCardHeight = 136;

  /// One height for the three big panels (AI scan performance, activity over
  /// time, recent activity), all as wide as the page. Taller on a narrow
  /// window, where their headings and legends wrap.
  static const double _panelHeight = 500;
  static const double _panelHeightNarrow = 640;

  // Server-side count() aggregates: the cards used to stream every document
  // of these collections just to read `.length`.
  // Users counts include finished registrations only (`registrationComplete`).
  late final Future<int?> _usersCount = _count(
    FirebaseFirestore.instance
        .collection('users')
        .where('registrationComplete', isEqualTo: true),
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

  Widget _usersCard() => FutureBuilder<int?>(
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
          onTap: widget.onOpenUsers,
        );
      },
    ),
  );

  Widget _aiScansCard() => FutureBuilder<int?>(
    future: _aiScansCount,
    builder: (context, snap) => AdminStatCard(
      label: 'Total AI scans',
      value: _countText(snap),
      change: _countFailed(snap) ? 'Failed to load' : null,
      changeColor: _countFailed(snap) ? Colors.red : null,
      icon: Icons.camera_alt_outlined,
      onTap: widget.onOpenAiScans,
    ),
  );

  Widget _escalationsCard() => FutureBuilder<int?>(
    future: _pendingEscalationsCount,
    builder: (context, snap) {
      if (_countFailed(snap)) {
        return AdminStatCard(
          label: 'Pending escalations',
          value: '—',
          change: 'Failed to load',
          changeColor: Colors.red,
          icon: Icons.warning_amber_outlined,
          onTap: widget.onOpenEscalations,
        );
      }
      final count = snap.data ?? 0;
      final loaded = snap.connectionState == ConnectionState.done;
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
        onTap: widget.onOpenEscalations,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final now = DateTime.now();
    final pad = MediaQuery.sizeOf(context).width < 640 ? 16.0 : 24.0;

    return Column(
      children: [
        AdminHeader(
          title: 'Dashboard',
          subtitle:
              'Fine Aid system overview — ${now.day}/${now.month}/${now.year}',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                final panelHeight = stacked ? _panelHeightNarrow : _panelHeight;
                // The three summary cards: one row of equal cards, or a
                // column of equal cards on a narrow window — same width
                // and height either way.
                final cards = [
                  _usersCard(),
                  _aiScansCard(),
                  _escalationsCard(),
                ];
                final stats = stacked
                    ? Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 16),
                            SizedBox(
                              height: _statCardHeight,
                              width: double.infinity,
                              child: cards[i],
                            ),
                          ],
                        ],
                      )
                    : SizedBox(
                        height: _statCardHeight,
                        child: Row(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        ),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stats,
                    const SizedBox(height: 24),
                    // 1) AI scan performance, 2) activity over time, 3)
                    // recent activity: same width and height each.
                    SizedBox(
                      height: panelHeight,
                      child: const AdminPerformanceCard(fillHeight: true),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: panelHeight,
                      child: const AdminTrendCard(
                        title: 'Activity over time',
                        caption: 'New users, journal entries and AI scans.',
                        fillHeight: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Same width as the panels above, but only as tall as
                    // its entries (the feed shows at most six).
                    _buildActivityFeed(theme),
                  ],
                );
              },
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Recent activity feed',
                  style: theme.textTheme.titleMedium,
                ),
              ),
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
                        const SizedBox(width: 8),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
