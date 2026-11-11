import 'dart:math' as math;

import '../../../../core/widgets/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_shared_widgets.dart';

// ---- Philippine time and form rules (public so they can be tested) ----------

/// Schedules are entered and shown in Philippine time (UTC+8, no daylight
/// saving), whatever the admin's own computer is set to.
const String kScheduleTimezone = 'Asia/Manila';
const String kScheduleTimezoneLabel = 'Asia/Manila (PHT, UTC+8)';
const Duration kManilaOffset = Duration(hours: 8);

/// A scheduled time must be at least this far ahead (the server checks too).
const Duration kMinScheduleLead = Duration(minutes: 1);

/// The most users one notification can be sent to (the server checks too).
const int kMaxNotificationUsers = 500;

/// Where a tap on the notification opens the app (a fixed list, not a URL).
const List<(String, String)> kNotificationLinks = [
  ('Notifications', 'fineaid://notifications'),
  ('Journal', 'fineaid://journal'),
];

/// The real moment for a [date] and [time] the admin entered as Manila time.
DateTime manilaInstant(DateTime date, TimeOfDay time) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
).subtract(kManilaOffset);

/// The Manila clock reading of [instant], as a DateTime whose fields ARE the
/// Manila date and time (flagged UTC so nothing is shifted again).
DateTime manilaWallClock(DateTime instant) =>
    instant.toUtc().add(kManilaOffset);

/// "Nov 12, 2026 3:30 PM PHT" for a moment in time.
String formatManila(DateTime instant) =>
    '${DateFormat('MMM d, y h:mm a').format(manilaWallClock(instant))} PHT';

/// What is wrong with the form (null when it can go): a title is needed, a
/// notification for chosen users needs at least one user (and at most
/// [kMaxNotificationUsers]), and a scheduled one needs a date and time that
/// are still in the future (Manila time).
String? notificationFormProblem({
  required String title,
  required bool toSelectedUsers,
  required int userCount,
  required bool schedule,
  DateTime? date,
  TimeOfDay? time,
  DateTime? now,
}) {
  if (title.trim().isEmpty) return 'Enter a title first.';
  if (toSelectedUsers && userCount == 0) return 'Pick at least one user.';
  if (toSelectedUsers && userCount > kMaxNotificationUsers) {
    return 'Pick at most $kMaxNotificationUsers users at a time.';
  }
  if (schedule) {
    if (date == null || time == null) {
      return 'Pick a date and time to schedule it.';
    }
    final when = manilaInstant(date, time);
    if (!when.isAfter((now ?? DateTime.now()).add(kMinScheduleLead))) {
      return 'Pick a time in the future (Philippine time).';
    }
  }
  return null;
}

/// "juan, maria +3 more" for the recipients line of a scheduled row.
String recipientsSummary(List<String> usernames, {int show = 2}) {
  if (usernames.isEmpty) return 'No users';
  final head = usernames.take(show).join(', ');
  final more = usernames.length - show;
  return more > 0 ? '$head +$more more' : head;
}

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});

  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

/// One pending / finished scheduled notification, from either list: the
/// all-users announcements (systemNotifications) or the ones for selected
/// users (scheduledNotifications).
class _Scheduled {
  const _Scheduled(this.id, this.collection, this.data);

  final String id;
  final String collection;
  final Map<String, dynamic> data;

  bool get forSelectedUsers => collection == 'scheduledNotifications';
  String get status => data['status'] as String? ?? 'scheduled';
  String get title => data['title'] as String? ?? '';
  DateTime? get when => (data['scheduledFor'] as Timestamp?)?.toDate();
  List<String> get usernames => [
    for (final u in (data['targetUsernames'] as List? ?? const [])) '$u',
  ];
}

class _AdminNotificationsState extends State<AdminNotifications> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  // Who gets it. The app gives announcements to signed-in accounts only (a
  // guest has no inbox and doesn't join the announcement topic), so the real
  // choices are every registered user, or specific users picked by username.
  static const _everyone = 'All registered users';
  static const _selectedUsers = 'Specific users';
  String _audience = _everyone;
  final List<String> _picked = [];

  /// Every existing username, for the search (loaded once).
  List<String> _usernames = const [];
  String? _usernamesError;

  // When to send, entered in Manila time.
  DateTime? _date;
  TimeOfDay? _time;
  String _link = kNotificationLinks.first.$2;

  @override
  void initState() {
    super.initState();
    _loadUsernames();
  }

  Future<void> _loadUsernames() async {
    try {
      // The public usernames index (document id = username, no personal data).
      final snap = await FirebaseFirestore.instance
          .collection('usernames')
          .limit(2000)
          .get();
      final names = <String>{
        for (final d in snap.docs)
          ((d.data()['usernameExact'] as String?)?.trim().isNotEmpty == true
              ? d.data()['usernameExact'] as String
              : d.id),
      }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() {
          _usernames = names;
          _usernamesError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _usernamesError = "Couldn't load the usernames.");
      }
    }
  }

  String _priority = 'Normal';
  bool _isSending = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recentSentStream =
      FirebaseFirestore.instance
          .collection('systemNotifications')
          .orderBy('sentAt', descending: true)
          .limit(5)
          .snapshots();

  // Scheduled notifications for chosen users that have gone out (orderBy
  // sentAt only lists documents that have a sentAt, so no extra index).
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recentUsersStream =
      FirebaseFirestore.instance
          .collection('scheduledNotifications')
          .orderBy('sentAt', descending: true)
          .limit(5)
          .snapshots();

  // Pending ones plus the history of cancelled / failed ones: a cancelled
  // notification is kept (never deleted) and shown here with its status.
  static const _listedStatuses = [
    'scheduled',
    'sending',
    'cancelled',
    'failed',
  ];
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scheduledStream =
      FirebaseFirestore.instance
          .collection('systemNotifications')
          .where('status', whereIn: _listedStatuses)
          .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scheduledUsersStream =
      FirebaseFirestore.instance
          .collection('scheduledNotifications')
          .where('status', whereIn: _listedStatuses)
          .snapshots();

  /// Notifications with a cancel request in flight (stops double taps).
  final Set<String> _cancelling = {};

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Cancelling goes through a Cloud Function that checks the status inside a
  /// transaction, so a notification that has just been sent can't be
  /// cancelled, and a cancelled one is never sent.
  Future<void> _cancelNotification(_Scheduled item) async {
    if (_cancelling.contains(item.id)) return;
    final ok = await adminConfirm(
      context,
      title: 'Cancel this scheduled notification?',
      message:
          '"${item.title}" will not be sent. It stays in the list as '
          'cancelled, and you can schedule a new one if you change your mind.',
      confirmLabel: 'Cancel notification',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling.add(item.id));
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelScheduledNotification')
          .call<Map<Object?, Object?>>({
            'notificationId': item.id,
            'collection': item.collection,
          });
      _say('Notification cancelled.');
    } on FirebaseFunctionsException catch (e) {
      _say('Could not cancel: ${e.message ?? e.code}');
    } catch (_) {
      _say('Could not reach the server. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _cancelling.remove(item.id));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _messageController.clear();
    _picked.clear();
    _date = null;
    _time = null;
  }

  bool get _toSelected => _audience == _selectedUsers;

  /// Sends right now, to everyone or to the users picked. Specific users get
  /// a push to their phones and a notice in their own private inbox (nobody
  /// else can see it); the server reports back only once it is saved.
  Future<void> _send() async {
    final problem = notificationFormProblem(
      title: _titleController.text,
      toSelectedUsers: _toSelected,
      userCount: _picked.length,
      schedule: false,
    );
    if (problem != null) return _say(problem);

    setState(() => _isSending = true);
    try {
      if (_toSelected) {
        final result = await FirebaseFunctions.instance
            .httpsCallable('sendNotificationToUser')
            .call<Map<Object?, Object?>>({
              'usernames': _picked,
              'title': _titleController.text.trim(),
              'body': _messageController.text.trim(),
              'link': _link,
            });
        final delivery = (result.data['delivery'] as Map?) ?? const {};
        final noDevice = (delivery['noDevice'] as num?)?.toInt() ?? 0;
        final count = (result.data['count'] as num?)?.toInt() ?? _picked.length;
        final pushFailed = result.data['pushFailed'] == true;
        _resetForm();
        _say(
          pushFailed
              ? 'Saved to their notifications, but the push could not be '
                    'sent. Try again later.'
              : noDevice > 0
              ? 'Sent to $count user${count == 1 ? '' : 's'}. $noDevice '
                    'have no registered phone yet and will see it in their '
                    'notifications list.'
              : 'Sent to $count user${count == 1 ? '' : 's'}.',
        );
      } else {
        // Everyone: the announcement document; its creation sends the push
        // to the all-users topic (sendSystemNotificationPush).
        await FirebaseFirestore.instance.collection('systemNotifications').add({
          'title': _titleController.text.trim(),
          'body': _messageController.text.trim(),
          'audience': _audience,
          'priority': _priority,
          'link': _link,
          'status': 'sent',
          'sentAt': FieldValue.serverTimestamp(),
        });
        logAdminAction(
          'Sent notification "${_titleController.text.trim()}"',
          type: 'CREATE',
        );
        _resetForm();
        _say('Notification sent.');
      }
    } on FirebaseFunctionsException catch (e) {
      _say(e.message ?? "Couldn't send (${e.code}).");
    } catch (_) {
      _say("Couldn't reach the server. Nothing was sent.");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Schedules it for the date and time chosen (Manila time). For everyone it
  /// is saved with a future `scheduledFor` and no `sentAt`; for specific
  /// users the server saves it in a private list. Either way the scheduler
  /// (every 5 minutes) sends the push once it is due.
  Future<void> _schedule() async {
    final problem = notificationFormProblem(
      title: _titleController.text,
      toSelectedUsers: _toSelected,
      userCount: _picked.length,
      schedule: true,
      date: _date,
      time: _time,
    );
    if (problem != null) return _say(problem);
    final when = manilaInstant(_date!, _time!);

    setState(() => _isSending = true);
    try {
      if (_toSelected) {
        await FirebaseFunctions.instance
            .httpsCallable('scheduleNotification')
            .call<Map<Object?, Object?>>({
              'title': _titleController.text.trim(),
              'body': _messageController.text.trim(),
              'usernames': _picked,
              'scheduledForMs': when.millisecondsSinceEpoch,
              'link': _link,
              'priority': _priority,
            });
      } else {
        await FirebaseFirestore.instance.collection('systemNotifications').add({
          'title': _titleController.text.trim(),
          'body': _messageController.text.trim(),
          'audience': _audience,
          'priority': _priority,
          'link': _link,
          'status': 'scheduled',
          'scheduledFor': Timestamp.fromDate(when),
          'timezone': kScheduleTimezone,
          'createdAt': FieldValue.serverTimestamp(),
        });
        logAdminAction(
          'Scheduled notification "${_titleController.text.trim()}"',
          type: 'CREATE',
        );
      }
      _resetForm();
      _say('Scheduled for ${formatManila(when)}.');
    } on FirebaseFunctionsException catch (e) {
      _say(e.message ?? "Couldn't schedule it (${e.code}).");
    } catch (_) {
      _say("Couldn't reach the server. Nothing was scheduled.");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickDate() async {
    final today = manilaWallClock(DateTime.now());
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showAppDatePicker(
      context,
      initial: _date != null && !_date!.isBefore(first) ? _date : first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final now = manilaWallClock(DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _edit(_Scheduled item) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditScheduledDialog(item: item, usernames: _usernames),
    );
    if (saved == true) _say('Changes saved.');
  }

  /// A pending or finished scheduled notification: what, to whom, when (Manila
  /// time), its status, and for a pending one Edit and Cancel.
  Widget _scheduledRow(ThemeData theme, _Scheduled item) {
    final when = item.when;
    final status = item.status;
    final (label, color) = switch (status) {
      'cancelled' => ('Cancelled', Colors.grey),
      'failed' => ('Failed', Colors.red),
      'sending' => ('Sendingâ€¦', Colors.blue),
      'sent' => ('Sent', Colors.green),
      _ => ('Scheduled', Colors.green),
    };
    final to = item.forSelectedUsers
        ? recipientsSummary(item.usernames)
        : 'All registered users';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: status == 'cancelled'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'To: $to'
          '${when == null ? '' : '  Â·  ${formatManila(when)}'}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        // Only pending ones can be edited or cancelled.
        if (status == 'scheduled')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  style: _linkStyle,
                  onPressed: () => _edit(item),
                  child: Text('Edit', style: theme.textTheme.bodySmall),
                ),
                TextButton(
                  style: _linkStyle,
                  onPressed: _cancelling.contains(item.id)
                      ? null
                      : () => _cancelNotification(item),
                  child: Text(
                    'Cancel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static final _linkStyle = TextButton.styleFrom(
    visualDensity: VisualDensity.compact,
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  Widget _label(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.labelMedium?.copyWith(color: Colors.black),
  );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final composeBody = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Compose notification',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label(theme, 'Title'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Notification title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label(theme, 'Message'),
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
                            _label(theme, 'Target audience'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _audience,
                              items: [_everyone, _selectedUsers]
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _audience = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(theme, 'Priority'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _priority,
                              items: ['Normal', 'High', 'Urgent']
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _priority = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_toSelected) ...[
                    const SizedBox(height: 12),
                    _label(theme, 'Users'),
                    const SizedBox(height: 6),
                    AdminUserPicker(
                      allUsernames: _usernames,
                      selected: _picked,
                      errorText: _usernamesError,
                      onChanged: (list) => setState(() {
                        _picked
                          ..clear()
                          ..addAll(list);
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _label(theme, 'When tapped, opens'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _link,
                    items: [
                      for (final (name, link) in kNotificationLinks)
                        DropdownMenuItem(value: link, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() => _link = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _label(theme, 'Send at (optional)'),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Date and time are in Philippine time',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            kScheduleTimezoneLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSending ? null : _pickDate,
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          _date == null
                              ? 'Pick a date'
                              : DateFormat('MMM d, y').format(_date!),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSending ? null : _pickTime,
                        icon: const Icon(Icons.schedule, size: 16),
                        label: Text(
                          _time == null
                              ? 'Pick a time'
                              : _time!.format(context),
                        ),
                      ),
                      if (_date != null || _time != null)
                        TextButton(
                          onPressed: _isSending
                              ? null
                              : () => setState(() {
                                  _date = null;
                                  _time = null;
                                }),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _toSelected
                        ? 'Specific users get a push on their phones and a '
                              'notice in their own Notifications list; nobody '
                              'else can see it.'
                        : 'Everyone signed in gets a push, and it appears in '
                              'their Notifications list.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _isSending ? null : _send,
                        child: const Text('Send now'),
                      ),
                      OutlinedButton(
                        onPressed: _isSending ? null : _schedule,
                        child: const Text('Schedule'),
                      ),
                    ],
                  ),
                ],
              );
              final compose = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                // On the wide layout the card has a set height, so a long form
                // scrolls inside it instead of overflowing.
                child: narrow
                    ? composeBody
                    : SingleChildScrollView(child: composeBody),
              );
              // The three cards on the right are built by one helper, so they
              // share the same size, padding, heading and row style, and each
              // fills the full width of the column.
              Widget card(String title, Widget body, {bool expand = false}) {
                final box = Container(
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
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // A growing card scrolls its list if it is ever longer
                      // than the space it was given.
                      if (expand && !narrow)
                        Expanded(child: SingleChildScrollView(child: body))
                      else
                        body,
                    ],
                  ),
                );
                // On the wide layout the Recent sends and Scheduled cards grow
                // to share the column's height, so the column has no blank
                // space under it.
                return expand && !narrow ? Expanded(child: box) : box;
              }

              // A list of rows with a thin rule between them.
              Widget rows(List<Widget> items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: items[i],
                    ),
                  ],
                ],
              );
              final recent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  card(
                    'Push notification preview',
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
                  ),
                  const SizedBox(height: 16),
                  card(
                    'Recent sends',
                    expand: true,
                    // Everyone's announcements and the ones that went to chosen
                    // users, newest first (5 of each, merged).
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _recentSentStream,
                      builder: (context, everyone) =>
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _recentUsersStream,
                            builder: (context, chosen) {
                              final sent = <(DateTime?, String, String)>[
                                for (final d in everyone.data?.docs ?? const [])
                                  (
                                    (d.data()['sentAt'] as Timestamp?)
                                        ?.toDate(),
                                    '${d.data()['title'] ?? ''}',
                                    '${d.data()['priority'] ?? ''}',
                                  ),
                                for (final d in chosen.data?.docs ?? const [])
                                  (
                                    (d.data()['sentAt'] as Timestamp?)
                                        ?.toDate(),
                                    '${d.data()['title'] ?? ''}',
                                    recipientsSummary(
                                      _Scheduled(
                                        d.id,
                                        'scheduledNotifications',
                                        d.data(),
                                      ).usernames,
                                    ),
                                  ),
                              ];
                              if (sent.isEmpty) {
                                return Text(
                                  'No notifications sent yet.',
                                  style: theme.textTheme.bodySmall,
                                );
                              }
                              sent.sort(
                                (a, b) => (b.$1 ?? DateTime(0)).compareTo(
                                  a.$1 ?? DateTime(0),
                                ),
                              );
                              return rows([
                                for (final (_, title, detail) in sent.take(5))
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          detail,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                              ]);
                            },
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  card(
                    'Scheduled',
                    expand: true,
                    // Both lists in one: everyone's, and the ones for chosen
                    // users (a failed read of one never hides the other).
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _scheduledStream,
                      builder: (context, everyone) =>
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _scheduledUsersStream,
                            builder: (context, chosen) {
                              final items = <_Scheduled>[
                                for (final d in everyone.data?.docs ?? const [])
                                  _Scheduled(
                                    d.id,
                                    'systemNotifications',
                                    d.data(),
                                  ),
                                for (final d in chosen.data?.docs ?? const [])
                                  _Scheduled(
                                    d.id,
                                    'scheduledNotifications',
                                    d.data(),
                                  ),
                              ];
                              if (items.isEmpty) {
                                return Text(
                                  'Nothing scheduled.',
                                  style: theme.textTheme.bodySmall,
                                );
                              }
                              // Pending (scheduled / sending) first, then the
                              // cancelled and failed history; by time within.
                              int rank(_Scheduled s) =>
                                  s.status == 'scheduled' ||
                                      s.status == 'sending'
                                  ? 0
                                  : 1;
                              items.sort((a, b) {
                                final byRank = rank(a).compareTo(rank(b));
                                if (byRank != 0) return byRank;
                                final aw = a.when;
                                final bw = b.when;
                                if (aw == null || bw == null) return 0;
                                return aw.compareTo(bw);
                              });
                              return rows([
                                for (final item in items)
                                  _scheduledRow(theme, item),
                              ]);
                            },
                          ),
                    ),
                  ),
                ],
              );
              // Side by side on a wide window; stacked on a narrow one.
              return narrow
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [compose, const SizedBox(height: 16), recent],
                      ),
                    )
                  // Both columns are as tall as the page, so the cards fill
                  // the screen with no empty space underneath. (On a short
                  // window they keep a minimum height and the page scrolls.)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        height: math.max(constraints.maxHeight - 48, 760),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: compose),
                            const SizedBox(width: 24),
                            Expanded(child: recent),
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
}

/// Search for users and add them (several), shown as removable chips. Only
/// existing usernames can be added. Used by the compose form and the edit
/// dialog.
class AdminUserPicker extends StatefulWidget {
  const AdminUserPicker({
    super.key,
    required this.allUsernames,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final List<String> allUsernames;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;

  @override
  State<AdminUserPicker> createState() => _AdminUserPickerState();
}

class _AdminUserPickerState extends State<AdminUserPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(String user) {
    if (widget.selected.contains(user)) return;
    if (widget.selected.length >= kMaxNotificationUsers) return;
    widget.onChanged([...widget.selected, user]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = [
      for (final u in widget.allUsernames)
        if (!widget.selected.contains(u)) u,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) => DropdownMenu<String>(
            controller: _search,
            width: box.maxWidth,
            menuHeight: 260,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            hintText: 'Search users and add them',
            errorText: widget.errorText,
            dropdownMenuEntries: [
              for (final u in available) DropdownMenuEntry(value: u, label: u),
            ],
            onSelected: (u) {
              if (u == null) return;
              _add(u);
              _search.clear();
            },
          ),
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final u in widget.selected)
                InputChip(
                  label: Text(u),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => widget.onChanged([
                    for (final x in widget.selected)
                      if (x != u) x,
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${widget.selected.length} selected',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onChanged(const []),
                child: const Text('Clear all'),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No users picked yet.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

/// Edit a pending scheduled notification: text, date and time (Manila time),
/// where it opens and, for one sent to chosen users, who it is for.
class _EditScheduledDialog extends StatefulWidget {
  const _EditScheduledDialog({required this.item, required this.usernames});

  final _Scheduled item;
  final List<String> usernames;

  @override
  State<_EditScheduledDialog> createState() => _EditScheduledDialogState();
}

class _EditScheduledDialogState extends State<_EditScheduledDialog> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _body = TextEditingController(
    text: widget.item.data['body'] as String? ?? '',
  );
  late DateTime? _date;
  late TimeOfDay? _time;
  late String _link;
  late List<String> _users;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final when = widget.item.when;
    final wall = when == null ? null : manilaWallClock(when);
    _date = wall == null ? null : DateTime(wall.year, wall.month, wall.day);
    _time = wall == null
        ? null
        : TimeOfDay(hour: wall.hour, minute: wall.minute);
    final link = widget.item.data['link'] as String?;
    _link = kNotificationLinks.any((l) => l.$2 == link)
        ? link!
        : kNotificationLinks.first.$2;
    _users = List.of(widget.item.usernames);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = manilaWallClock(DateTime.now());
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showAppDatePicker(
      context,
      initial: _date != null && !_date!.isBefore(first) ? _date : first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = notificationFormProblem(
      title: _title.text,
      toSelectedUsers: widget.item.forSelectedUsers,
      userCount: _users.length,
      schedule: true,
      date: _date,
      time: _time,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instance
          .httpsCallable('updateScheduledNotification')
          .call<Map<Object?, Object?>>({
            'notificationId': widget.item.id,
            'collection': widget.item.collection,
            'title': _title.text.trim(),
            'body': _body.text.trim(),
            'scheduledForMs': manilaInstant(
              _date!,
              _time!,
            ).millisecondsSinceEpoch,
            'link': _link,
            if (widget.item.forSelectedUsers) 'usernames': _users,
          });
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? "Couldn't save (${e.code}).";
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = "Couldn't reach the server. Nothing was changed.";
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Edit scheduled notification'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              if (widget.item.forSelectedUsers) ...[
                const SizedBox(height: 12),
                Text('Users', style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                AdminUserPicker(
                  allUsernames: widget.usernames,
                  selected: _users,
                  onChanged: (list) => setState(() => _users = list),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _link,
                decoration: const InputDecoration(
                  labelText: 'When tapped, opens',
                ),
                items: [
                  for (final (name, link) in kNotificationLinks)
                    DropdownMenuItem(value: link, child: Text(name)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _link = v!),
              ),
              const SizedBox(height: 12),
              Text(
                'Send at  Â·  $kScheduleTimezoneLabel',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      _date == null
                          ? 'Pick a date'
                          : DateFormat('MMM d, y').format(_date!),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTime,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      _time == null ? 'Pick a time' : _time!.format(context),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Savingâ€¦' : 'Save changes'),
        ),
      ],
    );
  }
}
