import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../journal/screens/entry_detail_screen.dart';

class _UnifiedNotification {
  final String id;
  final String title;
  final String body;
  final DateTime? timestamp;
  final bool isRead;
  final bool isSystem;
  final String? priority;
  final String? entryId;

  const _UnifiedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.isSystem,
    this.priority,
    this.entryId,
  });
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(child: Text('Not signed in'))
                  // System announcements from the admin panel are a shared
                  // collection (not per-user), so they're merged in here
                  // alongside each user's own personal notifications rather
                  // than duplicated into every user's subcollection.
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('notifications')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, personalSnapshot) {
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: FirebaseFirestore.instance
                              .collection('systemNotifications')
                              .orderBy('sentAt', descending: true)
                              .snapshots(),
                          builder: (context, systemSnapshot) {
                            if (!personalSnapshot.hasData &&
                                !systemSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final items = <_UnifiedNotification>[];
                            for (final doc
                                in personalSnapshot.data?.docs ?? const []) {
                              final data = doc.data();
                              items.add(
                                _UnifiedNotification(
                                  id: doc.id,
                                  title:
                                      data['title'] as String? ??
                                      'Notification',
                                  body: data['body'] as String? ?? '',
                                  timestamp: (data['createdAt'] as Timestamp?)
                                      ?.toDate(),
                                  isRead: data['read'] == true,
                                  isSystem: false,
                                  entryId: data['entryId'] as String?,
                                ),
                              );
                            }
                            for (final doc
                                in systemSnapshot.data?.docs ?? const []) {
                              final data = doc.data();
                              final readBy =
                                  (data['readBy'] as List?)?.cast<String>() ??
                                  const [];
                              items.add(
                                _UnifiedNotification(
                                  id: doc.id,
                                  title:
                                      data['title'] as String? ??
                                      'Fine Aid Update',
                                  body: data['body'] as String? ?? '',
                                  timestamp: (data['sentAt'] as Timestamp?)
                                      ?.toDate(),
                                  isRead: readBy.contains(user.uid),
                                  isSystem: true,
                                  priority: data['priority'] as String?,
                                ),
                              );
                            }
                            items.sort((a, b) {
                              if (a.timestamp == null) return 1;
                              if (b.timestamp == null) return -1;
                              return b.timestamp!.compareTo(a.timestamp!);
                            });

                            if (items.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No notifications yet. We\'ll let you '
                                    'know when it\'s time to check in on '
                                    'your recovery.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) => _notificationTile(
                                context,
                                theme,
                                items[index],
                                user.uid,
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

  Widget _notificationTile(
    BuildContext context,
    ThemeData theme,
    _UnifiedNotification item,
    String userId,
  ) {
    final timeText = item.timestamp != null
        ? DateFormat('MMM d, h:mm a').format(item.timestamp!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead ? null : theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: item.isRead ? 0.3 : 1,
          ),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(
          item.isSystem ? Icons.campaign : Icons.notifications,
          color: item.isRead ? Colors.grey : theme.colorScheme.primary,
        ),
        title: Text(
          item.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text('${item.body}\n$timeText'),
        isThreeLine: true,
        onTap: () async {
          if (item.isSystem) {
            FirebaseFirestore.instance
                .collection('systemNotifications')
                .doc(item.id)
                .update({
                  'readBy': FieldValue.arrayUnion([userId]),
                });
            return;
          }

          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .doc(item.id)
              .update({'read': true});

          final entryId = item.entryId;
          if (entryId == null) return;
          final entryDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('journalEntries')
              .doc(entryId)
              .get();
          if (!entryDoc.exists || !context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryDetailScreen(
                entryId: entryId,
                data: entryDoc.data()!,
              ),
            ),
          );
        },
      ),
    );
  }
}
