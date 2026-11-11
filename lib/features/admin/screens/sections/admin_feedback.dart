import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

/// The longest reply an admin can send (the server and the Firestore rules
/// enforce the same 1000). There is deliberately no minimum: a short answer is
/// fine. The 60-100 character rule belongs to the user's own feedback form
/// (lib/features/settings/screens/feedback_screen.dart), which has its own
/// constants.
const int adminFeedbackResponseMax = 1000;

/// The reply the response box starts with, so an admin can send a friendly
/// thank-you in one click and still edit or replace it. (Well under the
/// maximum length.)
const String kFeedbackReplyTemplate =
    'Thank you very much for taking the time to share your feedback! We truly '
    'appreciate it and are glad to hear from you.';

/// Null when [text] (already trimmed) can be sent; otherwise the message to
/// show the admin. A reply just can't be blank or over the maximum.
String? adminFeedbackResponseProblem(String text) {
  if (text.isEmpty) return 'Write a response before sending.';
  if (text.length > adminFeedbackResponseMax) {
    return 'Responses can be at most $adminFeedbackResponseMax characters '
        '(now ${text.length}).';
  }
  return null;
}

/// Who sent a feedback item: its account name, or "Guest" for one sent in
/// Guest Mode (no account).
String _who(
  AdminNameLookup names,
  Map<String, dynamic> data, {
  String fallback = 'Unknown user',
}) => data['source'] == 'guest'
    ? 'Guest'
    : names.nameFor(data['userId'] as String?, fallback: fallback);

/// Feedback and Ratings are two separate views, each with its own list,
/// filter and summary (tabs), so written feedback and star ratings are never
/// mixed in one table.
class AdminFeedback extends StatelessWidget {
  const AdminFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const AdminHeader(
            title: 'Feedback management',
            subtitle:
                'View, manage, and respond to feedback or bug reports, and review user ratings, to continuously improve the application.',
          ),
          Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'Feedback'),
                Tab(text: 'Ratings'),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(children: [_FeedbackTab(), _RatingsTab()]),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab>
    with AutomaticKeepAliveClientMixin {
  final _collection = FirebaseFirestore.instance.collection('feedback');

  @override
  bool get wantKeepAlive => true;

  /// null = all, otherwise 'open', 'responded' or 'resolved'. Done in the query, so the
  /// pages and totals follow the filter. (New feedback is stamped 'open' by
  /// the markFeedbackOpen function; older items by the one-off backfill;
  /// sending a response sets 'responded'.)
  String? _statusFilter;

  late AdminPageController _pager = _newPager();

  AdminPageController _newPager() {
    var q = _collection.orderBy('submittedAt', descending: true);
    if (_statusFilter != null) {
      q = _collection
          .where('status', isEqualTo: _statusFilter)
          .orderBy('submittedAt', descending: true);
    }
    final pager = AdminPageController(q);
    pager.addListener(_loadNamesForPage);
    return pager;
  }

  void _setFilter(String? status) {
    if (status == _statusFilter) return;
    final old = _pager;
    old.removeListener(_loadNamesForPage);
    setState(() {
      _statusFilter = status;
      _pager = _newPager();
    });
    old.dispose();
  }

  // Feedback authors are regular app users.
  final _names = AdminNameLookup(
    collection: 'users',
    nameOf: (data) => data['username'] as String?,
  );

  int? _open;
  int? _responded;
  int? _resolved;
  int? _total;

  @override
  void initState() {
    super.initState();
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
        _collection.where('status', isEqualTo: 'responded').count().get(),
      ]);
      final total = results[0].count ?? 0;
      final resolved = results[1].count ?? 0;
      final responded = results[2].count ?? 0;
      if (!mounted) return;
      setState(() {
        _resolved = resolved;
        _responded = responded;
        _open = total - resolved - responded;
        _total = total;
      });
    } catch (_) {
      // Leave the cards on "—" rather than blocking the list.
    }
  }

  void _toggleStatus(AdminDoc doc, bool isResolved) {
    final answered = (doc.data()['response'] as String?)?.isNotEmpty == true;
    _collection.doc(doc.id).update({
      'status': isResolved ? (answered ? 'responded' : 'open') : 'resolved',
    });
    logAdminAction(
      isResolved ? 'Reopened a feedback item' : 'Resolved a feedback item',
      targetType: 'feedback',
      targetId: doc.id,
      targetName: _who(_names, doc.data(), fallback: ''),
    );
    _loadStats();
  }

  static const int maxResponseLength = adminFeedbackResponseMax;

  /// What an admin has typed but not yet sent, per feedback id. If sending
  /// fails (or the dialog is closed) the text is still here when it is
  /// reopened, so nothing typed is lost.
  final Map<String, String> _drafts = {};

  static const String _resolvedNote =
      'This issue is resolved. Responses are disabled.';

  /// Response dialog. With no response yet it offers a text box and a Send
  /// button; once sent, the response is shown read-only (it can't be edited).
  /// Sending goes through the respondToFeedback function, which in one step
  /// saves the reply on the feedback, marks it "responded" and puts it in the
  /// user's in-app notifications. If that fails nothing is marked as sent: the
  /// error is shown and the text stays as a draft. The Send button is disabled
  /// while a send is in progress, so it can't go out twice.
  Future<void> _openResponse(AdminDoc doc) async {
    final data = doc.data();
    final theme = Theme.of(context);
    final existing = (data['response'] as String?)?.trim();
    final hasResponse = existing != null && existing.isNotEmpty;
    // A resolved item takes no new response (the rules enforce it too).
    final resolved = data['status'] == 'resolved';
    final author = _who(_names, data);
    final rating = (data['rating'] as num?)?.toInt();
    final controller = TextEditingController(
      text: _drafts[doc.id] ?? kFeedbackReplyTemplate,
    );
    controller.addListener(() => _drafts[doc.id] = controller.text);
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            if (saving) return;
            final text = controller.text.trim();
            final problem = adminFeedbackResponseProblem(text);
            if (problem != null) {
              setDialogState(() => error = problem);
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final result = await FirebaseFunctions.instance
                  .httpsCallable('respondToFeedback')
                  .call<Map<Object?, Object?>>({
                    'feedbackId': doc.id,
                    'response': text,
                  })
                  .timeout(const Duration(seconds: 30));
              final delivered = result.data['delivered'] == true;
              _drafts.remove(doc.id);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      delivered
                          ? 'Response sent to the user.'
                          : 'Response saved. This feedback was sent without '
                                'an account, so there is no one to notify.',
                    ),
                  ),
                );
                _loadStats();
              }
            } on FirebaseFunctionsException catch (e) {
              // The server's own messages are clear (already answered,
              // resolved, ...); anything else gets a generic one. Either way
              // the text stays as a draft and nothing is marked as sent.
              const clear = {
                'failed-precondition',
                'invalid-argument',
                'not-found',
                'permission-denied',
              };
              setDialogState(() {
                saving = false;
                error = clear.contains(e.code) && e.message != null
                    ? e.message
                    : "Couldn't send the response: ${adminErrorMessage(e)} "
                          'Your text is kept as a draft.';
              });
            } on TimeoutException {
              setDialogState(() {
                saving = false;
                error =
                    'No answer from the server. The response may not have '
                    'been sent: check the list before sending again. Your '
                    'text is kept as a draft.';
              });
            } catch (e) {
              setDialogState(() {
                saving = false;
                error =
                    "Couldn't send the response: ${adminErrorMessage(e)} "
                    'Your text is kept as a draft.';
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
                    if (resolved) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resolvedNote,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (hasResponse) ...[
                      SelectableText(existing),
                      const SizedBox(height: 10),
                      Text(
                        'Sent by ${data['respondedByName'] ?? 'an admin'}'
                        '${respondedAt != null ? ' on ${DateFormat('MMM d, y h:mm a').format(respondedAt)}' : ''}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ] else if (!resolved) ...[
                      TextField(
                        controller: controller,
                        enabled: !saving,
                        maxLines: 5,
                        minLines: 3,
                        autofocus: true,
                        // Typing or pasting stops at the maximum.
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(maxResponseLength),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Write your response',
                          errorText: error,
                          helperText:
                              'Sent to the user as a notification in their app, '
                              'and saved with this feedback.',
                          helperMaxLines: 2,
                        ),
                        onChanged: (_) {
                          if (error != null) setDialogState(() => error = null);
                        },
                      ),
                      Row(
                        children: [
                          // Puts the suggested thank-you back after editing.
                          TextButton(
                            onPressed: saving
                                ? null
                                : () =>
                                      controller.text = kFeedbackReplyTemplate,
                            child: const Text('Use suggested reply'),
                          ),
                          const Spacer(),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) => Text(
                              '${value.text.trim().length} / '
                              '$maxResponseLength',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
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
              if (!hasResponse && !resolved)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => ElevatedButton(
                    onPressed: saving || value.text.trim().isEmpty
                        ? null
                        : save,
                    child: Text(saving ? 'Sending…' : 'Send response'),
                  ),
                ),
            ],
          );
        },
      ),
    );
    // Not at once: the dialog is still sliding away and its text field uses
    // the controller until then.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final pad = adminIsNarrow(context) ? 16.0 : 24.0;
    final dateFmt = DateFormat('MMM d, y');

    return AdminPagedList(
      controller: _pager,
      builder: (context, docs) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statRow([
                _feedbackStat(
                  theme,
                  'Open feedback',
                  _open?.toString() ?? '—',
                  Colors.blue,
                ),
                _feedbackStat(
                  theme,
                  'Responded',
                  _responded?.toString() ?? '—',
                  Colors.teal,
                ),
                _feedbackStat(
                  theme,
                  'Resolved issues',
                  _resolved?.toString() ?? '—',
                  Colors.green,
                ),
                _feedbackStat(
                  theme,
                  'All feedback',
                  _total?.toString() ?? '—',
                  Colors.black87,
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Show:', style: theme.textTheme.labelMedium),
                  for (final (label, value) in const [
                    ('All', null),
                    ('Open', 'open'),
                    ('Responded', 'responded'),
                    ('Resolved', 'resolved'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _statusFilter == value,
                      onSelected: (_) => _setFilter(value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    AdminHScroll(
                      minWidth: 820,
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
                                _th(context, 'Date', flex: 2),
                                _th(context, 'Status', flex: 2),
                                _th(context, 'Action', flex: 3, indent: 12),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (docs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _statusFilter == null
                                    ? 'No feedback yet.'
                                    : 'No $_statusFilter feedback.',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ...docs.indexed.map((entry) {
                            final index = entry.$1;
                            final doc = entry.$2;
                            final data = doc.data();
                            final isResolved = data['status'] == 'resolved';
                            final submitted =
                                (data['submittedAt'] as Timestamp?)?.toDate();
                            final hasResponse =
                                (data['response'] as String?)?.isNotEmpty ==
                                true;
                            // A reply was sent (older replies may still say 'open').
                            final answered =
                                data['status'] == 'responded' || hasResponse;

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
                                          _who(_names, data),
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
                                              )
                                            else if (isResolved)
                                              Text(
                                                'Resolved · responses disabled',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          submitted == null
                                              ? '—'
                                              : dateFmt.format(submitted),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        // The pill keeps its own width and a
                                        // gap on the right, so it never
                                        // touches the Action column.
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 16,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isResolved
                                                    ? Colors.green.shade50
                                                    : answered
                                                    ? Colors.teal.shade50
                                                    : Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isResolved
                                                    ? 'Resolved'
                                                    : answered
                                                    ? 'Responded'
                                                    : 'Open',
                                                // One line, never "Respond/ed".
                                                maxLines: 1,
                                                softWrap: false,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: isResolved
                                                          ? Colors.green
                                                          : answered
                                                          ? Colors.teal
                                                          : Colors.blue,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        // Always side by side on one line;
                                        // shrinks a little rather than wrap.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                // A resolved item with no
                                                // response can't be answered;
                                                // a saved response stays
                                                // viewable.
                                                onPressed:
                                                    isResolved && !hasResponse
                                                    ? null
                                                    : () => _openResponse(doc),
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
                    AdminPager(controller: _pager),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The summary cards: side by side, or stacked on a narrow window.
  Widget _statRow(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: cards[i]),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _feedbackStat(
    ThemeData theme,
    String label,
    String value,
    Color color,
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
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// [indent] pushes the heading right, e.g. to sit over the text of a button
  /// (a text button has 12px of padding before its label).
  Widget _th(
    BuildContext context,
    String label, {
    int flex = 1,
    double indent = 0,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: indent),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.grey),
        ),
      ),
    );
  }
}

/// Star ratings only: their own summary (average, count, how many of each
/// star), their own filter (by stars) and their own list. The written
/// messages are on the Feedback tab.
class _RatingsTab extends StatefulWidget {
  const _RatingsTab();

  @override
  State<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<_RatingsTab>
    with AutomaticKeepAliveClientMixin {
  final _collection = FirebaseFirestore.instance.collection('feedback');

  @override
  bool get wantKeepAlive => true;

  final _names = AdminNameLookup(
    collection: 'users',
    nameOf: (data) => data['username'] as String?,
  );

  /// null = every rating, otherwise 1-5 stars.
  int? _stars;

  late AdminPageController _pager = _newPager();

  double? _average;
  Map<int, int>? _counts;

  AdminPageController _newPager() {
    // Only items that carry a rating (the app's rating is optional).
    final base = _stars == null
        ? _collection.where('rating', whereIn: [1, 2, 3, 4, 5])
        : _collection.where('rating', isEqualTo: _stars);
    final pager = AdminPageController(
      base.orderBy('submittedAt', descending: true),
    );
    pager.addListener(_loadNamesForPage);
    return pager;
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _pager.removeListener(_loadNamesForPage);
    _pager.dispose();
    super.dispose();
  }

  void _setStars(int? stars) {
    if (stars == _stars) return;
    final old = _pager;
    old.removeListener(_loadNamesForPage);
    setState(() {
      _stars = stars;
      _pager = _newPager();
    });
    old.dispose();
  }

  Future<void> _loadNamesForPage() async {
    final changed = await _names.ensure(
      _pager.docs.map((d) => d.data()['userId'] as String?),
    );
    if (changed && mounted) setState(() {});
  }

  /// Server-side aggregates: one count per star level and the average.
  Future<void> _loadStats() async {
    try {
      final results = await Future.wait<AggregateQuerySnapshot>([
        for (var s = 1; s <= 5; s++)
          _collection.where('rating', isEqualTo: s).count().get(),
        _collection.aggregate(average('rating')).get(),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = {for (var s = 1; s <= 5; s++) s: results[s - 1].count ?? 0};
        _average = results[5].getAverage('rating');
      });
    } catch (_) {
      // The cards stay on "—"; the list still loads.
    }
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

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final pad = adminIsNarrow(context) ? 16.0 : 24.0;
    final dateFmt = DateFormat('MMM d, y');
    final counts = _counts;
    final total = counts?.values.fold<int>(0, (a, b) => a + b);

    final average = _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average rating',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            _average != null && _average! > 0
                ? '${_average!.toStringAsFixed(1)} ★'
                : '—',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == null ? '' : '$total rating${total == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
    final distribution = _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ratings by stars',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          for (var s = 5; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('$s ★', style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (counts == null || (total ?? 0) == 0)
                            ? 0
                            : (counts[s] ?? 0) / total!,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Colors.orange),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${counts?[s] ?? '—'}',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return AdminPagedList(
      controller: _pager,
      builder: (context, docs) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 560
                    ? Column(
                        children: [
                          average,
                          const SizedBox(height: 12),
                          distribution,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: average),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: distribution),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Show:', style: theme.textTheme.labelMedium),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _stars == null,
                    onSelected: (_) => _setStars(null),
                  ),
                  for (var s = 5; s >= 1; s--)
                    ChoiceChip(
                      label: Text('$s ★'),
                      selected: _stars == s,
                      onSelected: (_) => _setStars(s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    AdminHScroll(
                      minWidth: 520,
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
                                _th(context, 'User', flex: 3),
                                _th(context, 'Rating', flex: 3),
                                _th(context, 'Date', flex: 2),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (docs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _stars == null
                                    ? 'No ratings yet.'
                                    : 'No $_stars-star ratings.',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ...docs.indexed.map((entry) {
                            final data = entry.$2.data();
                            final rating =
                                (data['rating'] as num?)?.toInt() ?? 0;
                            final submitted =
                                (data['submittedAt'] as Timestamp?)?.toDate();
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
                                          '${_pager.rangeStart + entry.$1}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _who(_names, data),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              Icons.star,
                                              size: 16,
                                              color: i < rating
                                                  ? Colors.orange
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          submitted == null
                                              ? '—'
                                              : dateFmt.format(submitted),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey),
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
                    AdminPager(controller: _pager),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
