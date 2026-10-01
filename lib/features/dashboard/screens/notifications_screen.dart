import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/notification_inbox_store.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../core/network_error.dart';
import '../../journal/screens/entry_detail_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';

/// A short type label + icon shown per notification, so a user can tell a
/// healing reminder apart from an app update at a glance.
class _TypeInfo {
  final String label;
  final IconData icon;
  const _TypeInfo(this.label, this.icon);
}

_TypeInfo _typeInfo(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.healingMilestone:
      return const _TypeInfo('Healing Milestone', Icons.healing_outlined);
    case AppNotificationType.update:
      return const _TypeInfo('Update', Icons.campaign_outlined);
    case AppNotificationType.system:
      return const _TypeInfo('Announcement', Icons.campaign_outlined);
    case AppNotificationType.reminder:
      return const _TypeInfo('Reminder', Icons.notifications_outlined);
  }
}

/// "Today, 9:00 AM" / "Yesterday, 9:00 AM" / "Sep 12, 9:00 AM" — readable
/// text instead of a raw ISO timestamp, used everywhere a notification's
/// time is shown.
String friendlyNotificationTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final timeText = DateFormat('h:mm a').format(dt);

  if (day == today) return 'Today, $timeText';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $timeText';
  }
  return '${DateFormat('MMM d').format(dt)}, $timeText';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _personalSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _systemSub;
  bool _showOfflineNotice = false;

  @override
  void initState() {
    super.initState();
    NotificationInboxStore.instance.load();
    _listenPersonal();
    _listenSystem();
  }

  @override
  void dispose() {
    _personalSub?.cancel();
    _systemSub?.cancel();
    super.dispose();
  }

  // Both listeners exist purely to keep NotificationInboxStore in sync —
  // the UI below only ever reads from that local store (see its own doc
  // comment), so read state and list membership always come from one
  // place regardless of where an item originally came from.

  void _listenPersonal() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // guests have no personal Firestore doc
    _personalSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) async {
            if (mounted) setState(() => _showOfflineNotice = false);
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              if (createdAt == null) continue; // still pending server write
              await NotificationInboxStore.instance.upsertFromRemote(
                AppNotification(
                  id: 'personal_${doc.id}',
                  type: _typeFromString(data['type'] as String?),
                  title: data['title'] as String? ?? 'Notification',
                  body: data['body'] as String? ?? '',
                  createdAt: createdAt,
                  isRead: data['read'] == true,
                  entryId: data['entryId'] as String?,
                ),
              );
            }
          },
          onError: (_) {
            // The local store already has whatever synced before — just
            // flag that we're not fully up to date, never a raw error.
            if (mounted) setState(() => _showOfflineNotice = true);
          },
        );
  }

  void _listenSystem() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _systemSub = FirebaseFirestore.instance
        .collection('systemNotifications')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) async {
            if (mounted) setState(() => _showOfflineNotice = false);
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
              if (sentAt == null) continue;
              final readBy =
                  (data['readBy'] as List?)?.cast<String>() ?? const [];
              await NotificationInboxStore.instance.upsertFromRemote(
                AppNotification(
                  id: 'system_${doc.id}',
                  type: AppNotificationType.update,
                  title: data['title'] as String? ?? 'Fine Aid Update',
                  body: data['body'] as String? ?? '',
                  createdAt: sentAt,
                  isRead: uid != null && readBy.contains(uid),
                  actionUrl: data['actionUrl'] as String?,
                  actionLabel: data['actionLabel'] as String?,
                ),
              );
            }
          },
          onError: (_) {
            if (mounted) setState(() => _showOfflineNotice = true);
          },
        );
  }

  AppNotificationType _typeFromString(String? raw) {
    switch (raw) {
      case 'healingMilestone':
        return AppNotificationType.healingMilestone;
      case 'update':
        return AppNotificationType.update;
      case 'system':
        return AppNotificationType.system;
      default:
        return AppNotificationType.reminder;
    }
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead) return;
    await NotificationInboxStore.instance.markRead(item.id);

    final user = FirebaseAuth.instance.currentUser;
    if (item.id.startsWith('personal_') && user != null) {
      final docId = item.id.substring('personal_'.length);
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .update({'read': true})
          .catchError((_) {});
    } else if (item.id.startsWith('system_') && user != null) {
      final docId = item.id.substring('system_'.length);
      FirebaseFirestore.instance
          .collection('systemNotifications')
          .doc(docId)
          .update({
            'readBy': FieldValue.arrayUnion([user.uid]),
          })
          .catchError((_) {});
    }
  }

  Future<void> _markAllRead() async {
    final unread = NotificationInboxStore.instance.visibleItems
        .where((n) => !n.isRead)
        .toList();
    await NotificationInboxStore.instance.markAllRead();
    for (final item in unread) {
      final user = FirebaseAuth.instance.currentUser;
      if (item.id.startsWith('personal_') && user != null) {
        final docId = item.id.substring('personal_'.length);
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(docId)
            .update({'read': true})
            .catchError((_) {});
      } else if (item.id.startsWith('system_') && user != null) {
        final docId = item.id.substring('system_'.length);
        FirebaseFirestore.instance
            .collection('systemNotifications')
            .doc(docId)
            .update({
              'readBy': FieldValue.arrayUnion([user.uid]),
            })
            .catchError((_) {});
      }
    }
  }

  Future<void> _openDetail(AppNotification item) async {
    await _markRead(item);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _NotificationDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  ListenableBuilder(
                    listenable: NotificationInboxStore.instance,
                    builder: (context, _) {
                      final hasUnread =
                          NotificationInboxStore.instance.unreadCount > 0;
                      return SizedBox(
                        width: 48,
                        child: hasUnread
                            ? IconButton(
                                icon: const Icon(Icons.done_all, size: 20),
                                tooltip: 'Mark all as read',
                                onPressed: _markAllRead,
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_showOfflineNotice)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      noInternetMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: NotificationInboxStore.instance,
                builder: (context, _) {
                  final items = NotificationInboxStore.instance.visibleItems;
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
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
                    itemBuilder: (context, index) =>
                        _notificationTile(theme, items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(ThemeData theme, AppNotification item) {
    final type = _typeInfo(item.type);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => NotificationInboxStore.instance.delete(item.id),
      child: Container(
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
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!item.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 16),
                Icon(
                  type.icon,
                  size: 20,
                  color: item.isRead ? Colors.grey : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: item.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friendlyNotificationTime(item.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-context detail view for one notification — the message, time,
/// wound type when there is one, and type-specific actions (the 3-way
/// healing check-in, or an "Update now" button for an update with a
/// link).
class _NotificationDetailSheet extends StatefulWidget {
  final AppNotification item;
  const _NotificationDetailSheet({required this.item});

  @override
  State<_NotificationDetailSheet> createState() =>
      _NotificationDetailSheetState();
}

class _NotificationDetailSheetState extends State<_NotificationDetailSheet> {
  bool _showingReferral = false;
  bool _isResponding = false;

  Future<void> _respond(bool feelingBetter) async {
    final entryId = widget.item.entryId;
    if (entryId == null || _isResponding) return;
    setState(() => _isResponding = true);
    await NotificationService().recordHealingMilestoneResponse(
      entryId: entryId,
      feelingBetter: feelingBetter,
    );
    if (!mounted) return;
    if (feelingBetter) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isResponding = false;
        _showingReferral = true;
      });
    }
  }

  Future<void> _remindTomorrow() async {
    final entryId = widget.item.entryId;
    if (entryId == null || _isResponding) return;
    setState(() => _isResponding = true);
    await NotificationService().remindHealingCheckInTomorrow(
      entryId: entryId,
      classification: widget.item.woundTypeLabel ?? 'this issue',
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Okay — we\'ll check in again tomorrow.')),
    );
  }

  void _openEntry() {
    final entryId = widget.item.entryId;
    if (entryId == null) return;
    Navigator.pop(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('journalEntries')
        .doc(entryId)
        .get()
        .then((doc) {
          if (!doc.exists || !mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EntryDetailScreen(entryId: entryId, data: doc.data()!),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final type = _typeInfo(item.type);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(type.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              friendlyNotificationTime(item.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (item.woundTypeLabel != null &&
                item.woundTypeLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Wound type: ${item.woundTypeLabel}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(item.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),

            if (_showingReferral) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_hospital,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We recommend seeking professional consultation',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChatbotScreen(journalEntryId: item.entryId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Need More Help'),
              ),
            ] else if (item.type == AppNotificationType.healingMilestone &&
                item.entryId != null) ...[
              ElevatedButton(
                onPressed: _isResponding ? null : () => _respond(true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Yes, I\'m feeling better'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isResponding ? null : _remindTomorrow,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Not yet'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isResponding ? null : () => _respond(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('It\'s getting worse'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openEntry,
                child: const Text('Open journal entry'),
              ),
            ] else if (item.type == AppNotificationType.update &&
                item.actionUrl != null) ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(item.actionLabel ?? 'Update now'),
              ),
            ] else if (item.entryId != null) ...[
              OutlinedButton(
                onPressed: _openEntry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Open journal entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
