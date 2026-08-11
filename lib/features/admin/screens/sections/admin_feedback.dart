import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminFeedback extends StatelessWidget {
  const AdminFeedback({super.key});

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
            stream: FirebaseFirestore.instance
                .collection('feedback')
                .orderBy('submittedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
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
                                _th('User', flex: 2),
                                _th('Message', flex: 3),
                                _th('Rating'),
                                _th('Status'),
                                _th('Action'),
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
                                          data['userId']?.toString().substring(
                                                0,
                                                8,
                                              ) ??
                                              'Unknown',
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
                                            style: TextStyle(
                                              fontSize: 11,
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
                                          },
                                          child: Text(
                                            isResolved ? 'Reopen' : 'Resolve',
                                            style: const TextStyle(
                                              fontSize: 12,
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
