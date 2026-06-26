import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase/auth_service.dart';
import 'user_management_screen.dart';
import 'content_management_screen.dart';
import 'notification_management_screen.dart';
import 'feedback_management_screen.dart';
import 'audit_log_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.primary,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fine Aid Admin',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Developer Dashboard',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async => await AuthService().signOut(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text('Overview', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _buildStatsRow(theme),
                    const SizedBox(height: 24),
                    Text('Management', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _buildManagementGrid(context, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            theme,
            'Total Users',
            Icons.people_outline,
            collection: 'users',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            theme,
            'Journal Entries',
            Icons.book_outlined,
            subcollection: 'journalEntries',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            theme,
            'Feedbacks',
            Icons.feedback_outlined,
            collection: 'feedback',
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    ThemeData theme,
    String label,
    IconData icon, {
    String? collection,
    String? subcollection,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: collection != null
                ? FirebaseFirestore.instance.collection(collection).snapshots()
                : FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context, ThemeData theme) {
    final items = [
      (
        'User Management',
        Icons.manage_accounts_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserManagementScreen()),
        ),
      ),
      (
        'Content Management',
        Icons.article_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContentManagementScreen()),
        ),
      ),
      (
        'Notifications',
        Icons.notifications_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationManagementScreen(),
          ),
        ),
      ),
      (
        'Feedback',
        Icons.feedback_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FeedbackManagementScreen()),
        ),
      ),
      (
        'Audit Logs',
        Icons.history_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuditLogScreen()),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: item.$3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.$2, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
