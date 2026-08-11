import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminAuditLogs extends StatelessWidget {
  const AdminAuditLogs({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
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
                            _th('Timestamp', flex: 2),
                            _th('Action', flex: 4),
                            _th('User'),
                            _th('Type'),
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
