import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});

  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _audience = 'All users';
  String _priority = 'Normal';
  bool _isSending = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recentSentStream =
      FirebaseFirestore.instance
          .collection('systemNotifications')
          .orderBy('sentAt', descending: true)
          .limit(5)
          .snapshots();

  // Pending ones plus the history of cancelled / failed ones: a cancelled
  // notification is kept (never deleted) and shown here with its status.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scheduledStream =
      FirebaseFirestore.instance
          .collection('systemNotifications')
          .where(
            'status',
            whereIn: ['scheduled', 'sending', 'cancelled', 'failed'],
          )
          .snapshots();

  /// Notifications with a cancel request in flight (stops double taps).
  final Set<String> _cancelling = {};

  /// Cancelling goes through a Cloud Function that checks the status inside a
  /// transaction, so a notification that has just been sent can't be
  /// cancelled, and a cancelled one is never sent.
  Future<void> _cancelNotification(String id, String title) async {
    if (_cancelling.contains(id)) return;
    final ok = await adminConfirm(
      context,
      title: 'Cancel this scheduled notification?',
      message:
          '"$title" will not be sent. It stays in the list as cancelled, '
          "and you can schedule a new one if you change your mind.",
      confirmLabel: 'Cancel notification',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling.add(id));
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelScheduledNotification')
          .call<Map<Object?, Object?>>({'notificationId': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification cancelled.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: ${e.message ?? e.code}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach the server. Nothing was changed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(id));
    }
  }

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
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
      logAdminAction(
        'Sent notification "${_titleController.text.trim()}"',
        type: 'CREATE',
      );
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

  // Writes with a future `scheduledFor` and no `sentAt` yet, so it's
  // invisible to the "sentAt"-ordered queries the user app and the Recent
  // Sends list both use. The sendScheduledSystemNotifications Cloud
  // Function (functions/index.js, runs every 5 minutes) claims these once
  // due, sends the push and stamps `sentAt`.
  Future<void> _schedule() async {
    if (_titleController.text.trim().isEmpty) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;

    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (scheduledFor.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('systemNotifications').add({
        'title': _titleController.text.trim(),
        'body': _messageController.text.trim(),
        'audience': _audience,
        'priority': _priority,
        'status': 'scheduled',
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'createdAt': FieldValue.serverTimestamp(),
      });
      logAdminAction(
        'Scheduled notification "${_titleController.text.trim()}"',
        type: 'CREATE',
      );
      _titleController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scheduled for ${DateFormat('MMM d, h:mm a').format(scheduledFor)}.',
            ),
          ),
        );
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
        const AdminHeader(
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Title',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black,
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
                        Text(
                          'Message',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black,
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
                                  Text(
                                    'Target audience',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: Colors.black),
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
                                  Text(
                                    'Priority',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: Colors.black),
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
                              onPressed: _isSending ? null : _schedule,
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                              ),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _recentSentStream,
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
                              'Scheduled',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _scheduledStream,
                              builder: (context, snap) {
                                if (!snap.hasData || snap.data!.docs.isEmpty) {
                                  return Text(
                                    'Nothing scheduled.',
                                    style: theme.textTheme.bodySmall,
                                  );
                                }
                                // Pending (scheduled / sending) first, then the
                                // cancelled and failed history; by time within.
                                int rank(Map<String, dynamic> d) =>
                                    d['status'] == 'scheduled' ||
                                        d['status'] == 'sending'
                                    ? 0
                                    : 1;
                                final docs = snap.data!.docs.toList()
                                  ..sort((a, b) {
                                    final byRank = rank(
                                      a.data(),
                                    ).compareTo(rank(b.data()));
                                    if (byRank != 0) return byRank;
                                    final aTs =
                                        a.data()['scheduledFor'] as Timestamp?;
                                    final bTs =
                                        b.data()['scheduledFor'] as Timestamp?;
                                    if (aTs == null || bTs == null) return 0;
                                    return aTs.compareTo(bTs);
                                  });
                                return Column(
                                  children: docs.map((doc) {
                                    final data = doc.data();
                                    final scheduledFor =
                                        data['scheduledFor'] as Timestamp?;
                                    final timeText = scheduledFor != null
                                        ? DateFormat(
                                            'MMM d, h:mm a',
                                          ).format(scheduledFor.toDate())
                                        : '';
                                    final status =
                                        data['status'] as String? ??
                                        'scheduled';
                                    final title =
                                        data['title'] as String? ?? '';
                                    final (label, color) = switch (status) {
                                      'cancelled' => ('Cancelled', Colors.grey),
                                      'failed' => ('Failed', Colors.red),
                                      'sending' => ('Sending…', Colors.blue),
                                      _ => ('Scheduled', Colors.green),
                                    };
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    decoration:
                                                        status == 'cancelled'
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeText,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              label,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: color,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                            ),
                                          ),
                                          // Only pending ones can be cancelled.
                                          if (status == 'scheduled')
                                            TextButton(
                                              onPressed:
                                                  _cancelling.contains(doc.id)
                                                  ? null
                                                  : () => _cancelNotification(
                                                      doc.id,
                                                      title,
                                                    ),
                                              child: Text(
                                                'Cancel',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .error,
                                                    ),
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
