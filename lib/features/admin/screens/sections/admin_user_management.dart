import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminUserManagement extends StatelessWidget {
  const AdminUserManagement({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
          title: 'User management',
          subtitle:
              'View, modify, or deactivate user accounts as needed for security or policy compliance.',
          action: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add user'),
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black,
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
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          email,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          joined,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: Colors.black87),
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
                                                  ? Colors.grey.shade700
                                                  : Colors.green.shade800,
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
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black,
                                                ),
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
                                                      ? Colors.green.shade800
                                                      : Colors.red.shade700,
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
          color: Colors.black,
        ),
      ),
    );
  }
}
