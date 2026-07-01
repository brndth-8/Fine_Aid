import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase/auth_service.dart';

enum AdminSection {
  dashboard,
  userManagement,
  contentManagement,
  notifications,
  journalLogReview,
  feedback,
  reportsAnalytics,
  auditLogs,
  systemSecurity,
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminSection _currentSection = AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Row(
        children: [
          _buildSidebar(theme),
          Expanded(child: _buildMainContent(theme)),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/FINE_AID_Logo.png',
                  width: 46,
                  height: 40,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Portal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color.fromARGB(255, 39, 39, 39),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFEEEEEE)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sidebarSection('OVERVIEW'),
                _sidebarItem(
                  AdminSection.dashboard,
                  Icons.dashboard_outlined,
                  'Dashboard',
                ),
                _sidebarSection('MANAGEMENT'),
                _sidebarItem(
                  AdminSection.userManagement,
                  Icons.manage_accounts_outlined,
                  'User Management',
                ),
                _sidebarItem(
                  AdminSection.contentManagement,
                  Icons.article_outlined,
                  'Content Management',
                ),
                _sidebarItem(
                  AdminSection.notifications,
                  Icons.notifications_outlined,
                  'Notifications',
                ),
                _sidebarSection('MONITORING'),
                _sidebarItem(
                  AdminSection.journalLogReview,
                  Icons.book_outlined,
                  'Journal Log Review',
                ),
                _sidebarItem(
                  AdminSection.feedback,
                  Icons.feedback_outlined,
                  'Feedback',
                ),
                _sidebarItem(
                  AdminSection.reportsAnalytics,
                  Icons.bar_chart_outlined,
                  'Reports & Analytics',
                ),
                _sidebarSection('SYSTEM'),
                _sidebarItem(
                  AdminSection.auditLogs,
                  Icons.history_outlined,
                  'Audit Logs',
                ),
                _sidebarItem(
                  AdminSection.systemSecurity,
                  Icons.security_outlined,
                  'System Security',
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFEEEEEE)),
          // Admin info at bottom
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
              child: Icon(
                Icons.person,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            title: const Text(
              'Admin',
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
            subtitle: const Text(
              'Administrator',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.logout, color: Colors.grey, size: 18),
              onPressed: () async => await AuthService().signOut(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sidebarItem(AdminSection section, IconData icon, String label) {
    final isSelected = _currentSection == section;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade600,
          size: 18,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade700,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _currentSection = section),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return _AdminMainDashboard(theme: theme);
      case AdminSection.userManagement:
        return const _AdminUserManagement();
      case AdminSection.contentManagement:
        return const _AdminContentManagement();
      case AdminSection.notifications:
        return const _AdminNotifications();
      case AdminSection.journalLogReview:
        return const _AdminJournalLogReview();
      case AdminSection.feedback:
        return const _AdminFeedback();
      case AdminSection.reportsAnalytics:
        return const _AdminReportsAnalytics();
      case AdminSection.auditLogs:
        return const _AdminAuditLogs();
      case AdminSection.systemSecurity:
        return const _AdminSystemSecurity();
    }
  }
}

class _AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _AdminHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.change,
    this.changeColor,
  });

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Icon(icon, color: theme.colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminMainDashboard extends StatelessWidget {
  final ThemeData theme;
  const _AdminMainDashboard({required this.theme});

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
        _AdminHeader(
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
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
                        builder: (context, snap) => _StatCard(
                          label: 'Registered users',
                          value: '${snap.data?.docs.length ?? 0}',
                          change: '↑ Growing',
                          icon: Icons.people_outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _StatCard(
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
                        builder: (context, snap) => _StatCard(
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
                          return _StatCard(
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
              TextButton(onPressed: () {}, child: const Text('View all')),
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
                    style: theme.textTheme.bodySmall?.copyWith(
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
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
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
                      style: TextStyle(
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

class _AdminUserManagement extends StatelessWidget {
  const _AdminUserManagement();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _AdminHeader(
          title: 'User management',
          subtitle:
              'View, modify, or deactivate user accounts as needed for security or policy compliance.',
          action: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Add user'),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'All users (${docs.length} total)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                _tableHeader('User', flex: 2),
                                _tableHeader('Email', flex: 3),
                                _tableHeader('Joined'),
                                _tableHeader('Status'),
                                _tableHeader('Actions'),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...docs.map((doc) {
                            final data = doc.data();
                            final username =
                                data['username'] as String? ?? 'Unknown';
                            final email = data['email'] as String? ?? '';
                            final ts = data['createdAt'] as Timestamp?;
                            final joined = ts != null
                                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                                : '';
                            final isDeactivated = data['deactivated'] == true;

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              child: Text(
                                                username.isNotEmpty
                                                    ? username[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              username,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          email,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          joined,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDeactivated
                                                ? Colors.grey.shade100
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isDeactivated
                                                ? 'Inactive'
                                                : 'Active',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDeactivated
                                                  ? Colors.grey
                                                  : Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            TextButton(
                                              onPressed: () {},
                                              child: const Text(
                                                'Edit',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(doc.id)
                                                    .update({
                                                      'deactivated':
                                                          !isDeactivated,
                                                    });
                                              },
                                              child: Text(
                                                isDeactivated
                                                    ? 'Activate'
                                                    : 'Deactivate',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDeactivated
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _AdminContentManagement extends StatefulWidget {
  const _AdminContentManagement();

  @override
  State<_AdminContentManagement> createState() =>
      _AdminContentManagementState();
}

class _AdminContentManagementState extends State<_AdminContentManagement> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'Emergency';
  bool _offlineAvailable = true;
  String? _editingId;

  final List<String> _categories = [
    'Emergency',
    'Injuries',
    'Wounds',
    'Skin',
    'Burns',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _category,
      'offlineAvailable': _offlineAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_editingId != null) {
      await FirebaseFirestore.instance
          .collection('firstAidContent')
          .doc(_editingId)
          .update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['status'] = 'Live';
      await FirebaseFirestore.instance.collection('firstAidContent').add(data);
    }
    _titleController.clear();
    _contentController.clear();
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _AdminHeader(
          title: 'Content management',
          subtitle:
              'Update first aid instructions, add new emergency procedures, and modify health information to ensure accuracy.',
          action: ElevatedButton.icon(
            onPressed: () {
              _titleController.clear();
              _contentController.clear();
              setState(() => _editingId = null);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ New article'),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content library table
              Expanded(
                flex: 3,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('firstAidContent')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: Colors.grey.shade50,
                              child: Row(
                                children: [
                                  _th('Title', flex: 3),
                                  _th('Category'),
                                  _th('Updated'),
                                  _th('Status'),
                                  _th('Action'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (docs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No content yet.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ...docs.map((doc) {
                              final data = doc.data();
                              final ts = data['updatedAt'] as Timestamp?;
                              final updated = ts != null
                                  ? 'Mar ${ts.toDate().day}'
                                  : '';
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            data['title'] ?? '',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            data['category'] ?? '',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            updated,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Live',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () {
                                              _titleController.text =
                                                  data['title'] ?? '';
                                              _contentController.text =
                                                  data['content'] ?? '';
                                              setState(() {
                                                _editingId = doc.id;
                                                _category =
                                                    data['category'] ??
                                                    'Emergency';
                                              });
                                            },
                                            child: const Text(
                                              'Edit',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Edit panel
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
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
                          _editingId != null ? 'Edit article' : 'New article',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Category',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _category,
                                    items: _categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Offline available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Switch(
                                  value: _offlineAvailable,
                                  onChanged: (v) =>
                                      setState(() => _offlineAvailable = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Content body',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contentController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Enter content',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: const Text('Save changes'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {},
                                child: const Text('Preview'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _AdminNotifications extends StatefulWidget {
  const _AdminNotifications();

  @override
  State<_AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<_AdminNotifications> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _audience = 'All users';
  String _priority = 'Normal';
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('systemNotifications').add({
        'title': _titleController.text.trim(),
        'body': _messageController.text.trim(),
        'audience': _audience,
        'priority': _priority,
        'sentAt': FieldValue.serverTimestamp(),
      });
      _titleController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification sent.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const _AdminHeader(
          title: 'Notification management',
          subtitle:
              'Send system notifications, health alerts, or important updates to users.',
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compose
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
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
                          'Compose notification',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Notification title',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Message',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _messageController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Enter message',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Target audience',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _audience,
                                    items:
                                        [
                                              'All users',
                                              'Registered only',
                                              'Premium',
                                            ]
                                            .map(
                                              (a) => DropdownMenuItem(
                                                value: a,
                                                child: Text(a),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) =>
                                        setState(() => _audience = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Priority',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: _priority,
                                    items: ['Normal', 'High', 'Urgent']
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _priority = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _isSending ? null : _send,
                              child: const Text('Send now'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {},
                              child: const Text('Schedule'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Recent sends
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
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
                              'Push notification preview',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _titleController.text.isEmpty
                                    ? 'Preview will appear here...'
                                    : _titleController.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                              'Recent sends',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('systemNotifications')
                                  .orderBy('sentAt', descending: true)
                                  .limit(5)
                                  .snapshots(),
                              builder: (context, snap) {
                                if (!snap.hasData || snap.data!.docs.isEmpty) {
                                  return Text(
                                    'No notifications sent yet.',
                                    style: theme.textTheme.bodySmall,
                                  );
                                }
                                return Column(
                                  children: snap.data!.docs.map((doc) {
                                    final data = doc.data();
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              data['title'] ?? '',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                          Text(
                                            data['priority'] ?? '',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: Colors.grey),
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminJournalLogReview extends StatelessWidget {
  const _AdminJournalLogReview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const _AdminHeader(
          title: 'Journal Log Review',
          subtitle:
              'Review user health journal entries and monitor healing progress.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('journalEntries')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No journal entries yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Colors.grey.shade50,
                        child: Row(
                          children: [
                            _th2('Title', flex: 2),
                            _th2('Classification', flex: 2),
                            _th2('Monitored'),
                            _th2('Referred'),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final title = data['title'] as String? ?? 'Untitled';
                        final classification =
                            data['classification'] as String? ?? '—';
                        final ts = data['createdAt'] as Timestamp?;
                        final days = ts != null
                            ? DateTime.now().difference(ts.toDate()).inDays
                            : 0;
                        final referred = data['feelingBetter'] == false;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      title,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      classification,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$days days',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: referred
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        referred ? 'Referred' : 'Recovering',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: referred
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _th2(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _AdminFeedback extends StatelessWidget {
  const _AdminFeedback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const _AdminHeader(
          title: 'Feedback management',
          subtitle:
              'View, manage, and respond to feedback or bug reports to identify issues and continuously improve the application.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('feedback')
                .orderBy('submittedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              final open = docs
                  .where((d) => d.data()['status'] != 'resolved')
                  .length;
              final resolved = docs
                  .where((d) => d.data()['status'] == 'resolved')
                  .length;
              final ratings = docs
                  .where((d) => d.data()['rating'] != null)
                  .map((d) => (d.data()['rating'] as num).toDouble())
                  .toList();
              final avgRating = ratings.isEmpty
                  ? 0.0
                  : ratings.reduce((a, b) => a + b) / ratings.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _feedbackStat(
                          theme,
                          'Open feedback',
                          '$open',
                          Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Resolved all time',
                          '$resolved',
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Average rating',
                          avgRating > 0
                              ? '${avgRating.toStringAsFixed(1)} ★'
                              : '—',
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: Colors.grey.shade50,
                            child: Row(
                              children: [
                                _th3('User', flex: 2),
                                _th3('Message', flex: 3),
                                _th3('Rating'),
                                _th3('Status'),
                                _th3('Action'),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (docs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No feedback yet.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ...docs.map((doc) {
                            final data = doc.data();
                            final isResolved = data['status'] == 'resolved';
                            final rating = data['rating'] as int?;

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          data['userId']?.toString().substring(
                                                0,
                                                8,
                                              ) ??
                                              'Unknown',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          data['message'] ?? '',
                                          style: theme.textTheme.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        child: rating != null
                                            ? Row(
                                                children: List.generate(
                                                  rating,
                                                  (_) => const Icon(
                                                    Icons.star,
                                                    size: 12,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              )
                                            : const Text('—'),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isResolved
                                                ? Colors.green.shade50
                                                : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isResolved ? 'Resolved' : 'Open',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isResolved
                                                  ? Colors.green
                                                  : Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () {
                                            FirebaseFirestore.instance
                                                .collection('feedback')
                                                .doc(doc.id)
                                                .update({
                                                  'status': isResolved
                                                      ? 'open'
                                                      : 'resolved',
                                                });
                                          },
                                          child: Text(
                                            isResolved ? 'Reopen' : 'Resolve',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _feedbackStat(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th3(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _AdminReportsAnalytics extends StatelessWidget {
  const _AdminReportsAnalytics();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const _AdminHeader(
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
                        builder: (context, snap) => _analyticsCard(
                          theme,
                          'Total users',
                          '${snap.data?.docs.length ?? 0}',
                          '↑ Growing',
                          Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _AnalyticsCard(
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
                        builder: (context, snap) => _analyticsCard(
                          theme,
                          'Auto-referrals',
                          '${snap.data?.docs.length ?? 0}',
                          null,
                          null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _AnalyticsCard(
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

  Widget _analyticsCard(
    ThemeData theme,
    String label,
    String value,
    String? change,
    Color? changeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change,
              style: TextStyle(
                fontSize: 11,
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
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
          Text('Injury scan types', style: theme.textTheme.titleMedium),
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
                if (c != null && counts.containsKey(c))
                  counts[c] = counts[c]! + 1;
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
          Text('Generate report', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          const Text(
            'Report type',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

class _AnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;

  const _AnalyticsCard({
    required this.label,
    required this.value,
    this.change,
    this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: TextStyle(
                fontSize: 11,
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminAuditLogs extends StatelessWidget {
  const _AdminAuditLogs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _AdminHeader(
          title: 'Audit logs',
          subtitle:
              'Complete record of all admin activities — from account changes to notifications — for accountability and security.',
          action: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export logs'),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('auditLogs')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Colors.grey.shade50,
                        child: Row(
                          children: [
                            _th4('Timestamp', flex: 2),
                            _th4('Action', flex: 4),
                            _th4('User'),
                            _th4('Type'),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No audit logs yet. Admin actions will appear here automatically.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final ts = data['timestamp'] as Timestamp?;
                        final timeText = ts != null
                            ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                            : '';
                        final actionType = data['type'] as String? ?? 'UPDATE';
                        final typeColor =
                            {
                              'CREATE': Colors.green,
                              'UPDATE': Colors.blue,
                              'DELETE': Colors.red,
                              'LOGIN': Colors.purple,
                            }[actionType] ??
                            Colors.grey;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      timeText,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      data['action'] ?? '',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      (data['userId'] ?? 'System')
                                          .toString()
                                          .substring(0, 8),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        actionType,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: typeColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _th4(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _AdminSystemSecurity extends StatefulWidget {
  const _AdminSystemSecurity();

  @override
  State<_AdminSystemSecurity> createState() => _AdminSystemSecurityState();
}

class _AdminSystemSecurityState extends State<_AdminSystemSecurity> {
  bool _encryption = true;
  bool _tls = true;
  bool _twoFa = true;
  bool _sessionTimeout = true;
  bool _loginLockout = true;
  bool _auditRetention = true;
  final _sessionTimeoutController = TextEditingController(text: '30');
  final _maxSessionsController = TextEditingController(text: '1');

  @override
  void dispose() {
    _sessionTimeoutController.dispose();
    _maxSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const _AdminHeader(
          title: 'System security management',
          subtitle:
              'Overview core security settings including data encryption protocols and session management.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Security Status: Good. All critical protocols are active.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
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
                              'Security protocols',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _securityToggle(
                              theme,
                              'Data encryption (AES-256)',
                              'Encrypts all personal and health-related data at rest',
                              _encryption,
                              (v) => setState(() => _encryption = v),
                            ),
                            _securityToggle(
                              theme,
                              'TLS / HTTPS in transit',
                              'Secures all data transmitted between app and server',
                              _tls,
                              (v) => setState(() => _tls = v),
                            ),
                            _securityToggle(
                              theme,
                              'Two-factor authentication (2FA)',
                              'Required for all admin portal logins',
                              _twoFa,
                              (v) => setState(() => _twoFa = v),
                            ),
                            _securityToggle(
                              theme,
                              'Auto session timeout',
                              'Logs out inactive users to prevent unauthorized access',
                              _sessionTimeout,
                              (v) => setState(() => _sessionTimeout = v),
                            ),
                            _securityToggle(
                              theme,
                              'Failed login lockout',
                              'Locks account after 5 consecutive failed attempts',
                              _loginLockout,
                              (v) => setState(() => _loginLockout = v),
                            ),
                            _securityToggle(
                              theme,
                              'Audit log retention (12 months)',
                              'Maintains complete records of all system activities',
                              _auditRetention,
                              (v) => setState(() => _auditRetention = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
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
                                  'Session management',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Session timeout (minutes)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _sessionTimeoutController,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Max concurrent sessions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _maxSessionsController,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Settings saved.'),
                                      ),
                                    );
                                  },
                                  child: const Text('Save settings'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
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
                                  'Security summary',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                _summaryRow('Last login', 'Today'),
                                _summaryRow('Active sessions', '1 / 1'),
                                _summaryRow('Failed logins today', '0'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await AuthService().signOut();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Force logout all sessions',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _securityToggle(
    ThemeData theme,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
