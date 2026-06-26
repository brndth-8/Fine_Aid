import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_app_bar.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            adminAppBar(context, theme, 'User Management'),
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
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No users yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final uid = docs[index].id;
                      final username = data['username'] as String? ?? 'Unknown';
                      final email = data['email'] as String? ?? '';
                      final timestamp = data['createdAt'] as Timestamp?;
                      final dateText = timestamp != null
                          ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
                          : '';
                      final isDeactivated = data['deactivated'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDeactivated
                              ? Colors.grey[100]
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isDeactivated
                                  ? Colors.grey
                                  : theme.colorScheme.primary,
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(email, style: theme.textTheme.bodySmall),
                                  Text(
                                    'Joined: $dateText',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isDeactivated
                                    ? Icons.check_circle_outline
                                    : Icons.block_outlined,
                                color: isDeactivated
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              tooltip: isDeactivated
                                  ? 'Activate'
                                  : 'Deactivate',
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({'deactivated': !isDeactivated});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
