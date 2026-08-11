import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminMainDashboard extends StatelessWidget {
  final ThemeData theme;
  const AdminMainDashboard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '$greeting, Admin',
                  style: GoogleFonts.inter(
                    textStyle: theme.textTheme.titleLarge,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snap) => AdminStatCard(
                          label: 'Registered users',
                          value: '${snap.data?.docs.length ?? 0}',
                          change: 'Growing',
                          icon: Icons.people_outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: AdminStatCard(
                        label: 'Total AI scans',
                        value: '—',
                        change: 'Requires AI integration',
                        changeColor: Colors.orange,
                        icon: Icons.camera_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collectionGroup('journalEntries')
                            .snapshots(),
                        builder: (context, snap) => AdminStatCard(
                          label: 'Journal entries',
                          value: '${snap.data?.docs.length ?? 0}',
                          icon: Icons.book_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collectionGroup('journalEntries')
                            .where('feelingBetter', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snap) {
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
              Text(
                'Recent activity feed',
                style: GoogleFonts.inter(
                  textStyle: theme.textTheme.titleMedium,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('View all', style: GoogleFonts.inter()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('auditLogs')
                .orderBy('timestamp', descending: true)
                .limit(6)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No recent activity. Admin actions will appear here.',
                    style: GoogleFonts.inter(
                      textStyle: theme.textTheme.bodySmall,
                      color: Colors.grey,
                    ),
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
                            style: GoogleFonts.inter(
                              textStyle: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Text(
                          timeText,
                          style: GoogleFonts.inter(
                            textStyle: theme.textTheme.bodySmall,
                            color: Colors.grey,
                          ),
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
          Text(
            'System status',
            style: GoogleFonts.inter(
              textStyle: theme.textTheme.titleMedium,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...services.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.$1,
                    style: GoogleFonts.inter(
                      textStyle: theme.textTheme.bodySmall,
                    ),
                  ),
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
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: s.$2 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
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
