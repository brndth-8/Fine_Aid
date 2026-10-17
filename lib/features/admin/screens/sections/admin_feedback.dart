import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminFeedback extends StatefulWidget {
  const AdminFeedback({super.key});

  @override
  State<AdminFeedback> createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedback> {
  final _collection = FirebaseFirestore.instance.collection('feedback');

  late final AdminPageController _pager = AdminPageController(
    _collection.orderBy('submittedAt', descending: true),
  );

  // Feedback authors are regular app users.
  final _names = AdminNameLookup(
    collection: 'users',
    nameOf: (data) => data['username'] as String?,
  );

  int? _open;
  int? _resolved;
  double? _avgRating;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_loadNamesForPage);
    _loadStats();
  }

  @override
  void dispose() {
    _pager.removeListener(_loadNamesForPage);
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadNamesForPage() async {
    final changed = await _names.ensure(
      _pager.docs.map((d) => d.data()['userId'] as String?),
    );
    if (changed && mounted) setState(() {});
  }

  /// Server-side aggregates instead of downloading every feedback document
  /// to count it. "Open" is total − resolved because feedback submitted from
  /// the app has no `status` field at all (so it can't be queried directly).
  Future<void> _loadStats() async {
    try {
      final results = await Future.wait<AggregateQuerySnapshot>([
        _collection.count().get(),
        _collection.where('status', isEqualTo: 'resolved').count().get(),
        _collection.aggregate(average('rating')).get(),
      ]);
      final total = results[0].count ?? 0;
      final resolved = results[1].count ?? 0;
      if (!mounted) return;
      setState(() {
        _resolved = resolved;
        _open = total - resolved;
        _avgRating = results[2].getAverage('rating');
      });
    } catch (_) {
      // Leave the cards on "—" rather than blocking the list.
    }
  }

  void _toggleStatus(AdminDoc doc, bool isResolved) {
    _collection.doc(doc.id).update({
      'status': isResolved ? 'open' : 'resolved',
    });
    logAdminAction(
      isResolved
          ? 'Reopened feedback ${doc.id}'
          : 'Resolved feedback ${doc.id}',
    );
    _loadStats();
  }

  /// Longest response an admin can save (also enforced in Firestore rules).
  static const int maxResponseLength = 1000;

  /// Response dialog. With no response yet it offers a text box and a Save
  /// button; once saved, the response is shown read-only (it can't be edited).
  /// It is stored on the feedback document for admin records only: it is not
  /// emailed and the app has no screen where users see it.
  Future<void> _openResponse(AdminDoc doc) async {
    final data = doc.data();
    final theme = Theme.of(context);
    final existing = (data['response'] as String?)?.trim();
    final hasResponse = existing != null && existing.isNotEmpty;
    final author = _names.nameFor(data['userId'] as String?);
    final rating = (data['rating'] as num?)?.toInt();
    final controller = TextEditingController();
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            final text = controller.text.trim();
            if (text.isEmpty) {
              setDialogState(() => error = 'Write a response before saving.');
              return;
            }
            if (text.length > maxResponseLength) {
              setDialogState(
                () => error =
                    'Responses can be at most $maxResponseLength characters '
                    '(now ${text.length}).',
              );
              return;
            }
            if (saving) return;
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final user = FirebaseAuth.instance.currentUser!;
              final adminData =
                  (await FirebaseFirestore.instance
                          .collection('admins')
                          .doc(user.uid)
                          .get())
                      .data() ??
                  const <String, dynamic>{};
              final name =
                  (adminData['displayName'] as String?)?.trim().isNotEmpty ==
                      true
                  ? adminData['displayName'] as String
                  : adminData['email'] as String? ?? user.email;
              final ref = _collection.doc(doc.id);
              // Checked inside a transaction so two admins (or a double
              // click) can't both save: the first response wins.
              await FirebaseFirestore.instance.runTransaction((tx) async {
                final snap = await tx.get(ref);
                if ((snap.data()?['response'] as String?)?.isNotEmpty == true) {
                  throw StateError('already-responded');
                }
                tx.update(ref, {
                  'response': text,
                  'respondedBy': user.uid,
                  'respondedByName': name,
                  'respondedAt': FieldValue.serverTimestamp(),
                });
              });
              // Never put the response text in the audit log.
              logAdminAction(
                'Responded to feedback',
                targetType: 'feedback',
                targetId: doc.id,
                targetName: author == '…' ? null : author,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Response saved.')),
                );
              }
            } on StateError {
              setDialogState(() {
                saving = false;
                error = 'This feedback already has a response.';
              });
            } catch (e) {
              setDialogState(() {
                saving = false;
                error = "Couldn't save the response: ${adminErrorMessage(e)}";
              });
            }
          }

          final respondedAt = (data['respondedAt'] as Timestamp?)?.toDate();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(hasResponse ? 'Response' : 'Respond to feedback'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From $author'
                      '${rating != null ? ' · $rating ★' : ''}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      data['message'] as String? ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Divider(height: 28),
                    if (hasResponse) ...[
                      SelectableText(existing),
                      const SizedBox(height: 10),
                      Text(
                        'Saved by ${data['respondedByName'] ?? 'an admin'}'
                        '${respondedAt != null ? ' on ${DateFormat('MMM d, y h:mm a').format(respondedAt)}' : ''}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: controller,
                        enabled: !saving,
                        maxLines: 5,
                        minLines: 3,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Write your response',
                          errorText: error,
                          helperText:
                              'Saved to the feedback record only. It is not '
                              'sent to the user.',
                          helperMaxLines: 2,
                        ),
                        onChanged: (_) {
                          if (error != null) setDialogState(() => error = null);
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final length = value.text.trim().length;
                            return Text(
                              '$length / $maxResponseLength',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: length > maxResponseLength
                                    ? theme.colorScheme.error
                                    : Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(hasResponse ? 'Close' : 'Cancel'),
              ),
              if (!hasResponse)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => ElevatedButton(
                    onPressed: saving || value.text.trim().isEmpty
                        ? null
                        : save,
                    child: Text(saving ? 'Saving…' : 'Save response'),
                  ),
                ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'Feedback management',
          subtitle:
              'View, manage, and respond to feedback or bug reports to identify issues and continuously improve the application.',
        ),
        Expanded(
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _feedbackStat(
                          theme,
                          'Open feedback',
                          _open?.toString() ?? '—',
                          Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Resolved issues',
                          _resolved?.toString() ?? '—',
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Average rating',
                          _avgRating != null && _avgRating! > 0
                              ? '${_avgRating!.toStringAsFixed(1)} ★'
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
                                _th(context, '#', flex: 1),
                                _th(context, 'User', flex: 2),
                                _th(context, 'Message', flex: 4),
                                _th(context, 'Rating', flex: 2),
                                _th(context, 'Status', flex: 1),
                                _th(context, 'Action', flex: 2),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (docs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No feedback yet.',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ...docs.indexed.map((entry) {
                            final index = entry.$1;
                            final doc = entry.$2;
                            final data = doc.data();
                            final isResolved = data['status'] == 'resolved';
                            final rating = (data['rating'] as num?)?.toInt();
                            final hasResponse =
                                (data['response'] as String?)?.isNotEmpty ==
                                true;

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
                                        flex: 1,
                                        child: Text(
                                          '${_pager.rangeStart + index}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _names.nameFor(
                                            data['userId'] as String?,
                                          ),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['message'] ?? '',
                                              style: theme.textTheme.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (hasResponse)
                                              Text(
                                                'Responded',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: rating != null
                                            ? Row(
                                                children: List.generate(
                                                  5,
                                                  (i) => Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: i < rating
                                                        ? Colors.orange
                                                        : Colors.grey.shade300,
                                                  ),
                                                ),
                                              )
                                            : const Text('—'),
                                      ),
                                      Expanded(
                                        flex: 1,
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
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.normal,
                                                  color: isResolved
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Wrap(
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  _openResponse(doc),
                                              child: Text(
                                                hasResponse
                                                    ? 'View response'
                                                    : 'Respond',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _toggleStatus(
                                                doc,
                                                isResolved,
                                              ),
                                              child: Text(
                                                isResolved
                                                    ? 'Reopen'
                                                    : 'Resolve',
                                                style:
                                                    theme.textTheme.bodySmall,
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
                          AdminPager(controller: _pager),
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

  Widget _th(BuildContext context, String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}
