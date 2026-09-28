import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminFeedback extends StatefulWidget {
  const AdminFeedback({super.key});

  @override
  State<AdminFeedback> createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedback> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _feedbackStream =
      FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('submittedAt', descending: true)
          .snapshots();

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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _feedbackStream,
            builder: (context, snapshot) {
              final fallback = adminSnapshotFallback(snapshot);
              if (fallback != null) return fallback;

              final docs = snapshot.data!.docs;

              final open = docs
                  .where((d) => d.data()['status'] != 'resolved')
                  .length;
              final resolved = docs
                  .where((d) => d.data()['status'] == 'resolved')
                  .length;
              final ratings = docs
                  .where((d) => d.data()['rating'] != null)
                  .map((d) => (d.data()['rating'] as num).toDouble())
                  .toList();
              final avgRating = ratings.isEmpty
                  ? 0.0
                  : ratings.reduce((a, b) => a + b) / ratings.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _feedbackStat(
                          theme,
                          'Open feedback',
                          '$open',
                          Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Resolved all time',
                          '$resolved',
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _feedbackStat(
                          theme,
                          'Average rating',
                          avgRating > 0
                              ? '${avgRating.toStringAsFixed(1)} ★'
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
                                _th(context, 'User', flex: 2),
                                _th(context, 'Message', flex: 3),
                                _th(context, 'Rating'),
                                _th(context, 'Status'),
                                _th(context, 'Action'),
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
                          ...docs.map((doc) {
                            final data = doc.data();
                            final isResolved = data['status'] == 'resolved';
                            final rating = data['rating'] as int?;

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
                                          shortId(data['userId']),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          data['message'] ?? '',
                                          style: theme.textTheme.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        child: rating != null
                                            ? Row(
                                                children: List.generate(
                                                  rating,
                                                  (_) => const Icon(
                                                    Icons.star,
                                                    size: 12,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              )
                                            : const Text('—'),
                                      ),
                                      Expanded(
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
                                        child: TextButton(
                                          onPressed: () {
                                            FirebaseFirestore.instance
                                                .collection('feedback')
                                                .doc(doc.id)
                                                .update({
                                                  'status': isResolved
                                                      ? 'open'
                                                      : 'resolved',
                                                });
                                            logAdminAction(
                                              isResolved
                                                  ? 'Reopened feedback ${doc.id}'
                                                  : 'Resolved feedback ${doc.id}',
                                            );
                                          },
                                          child: Text(
                                            isResolved ? 'Reopen' : 'Resolve',
                                            style: theme.textTheme.bodySmall,
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
