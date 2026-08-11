import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminJournalLogReview extends StatelessWidget {
  const AdminJournalLogReview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'Journal Log Review',
          subtitle:
              'Review user health journal entries and monitor healing progress.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('journalEntries')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No journal entries yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
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
                            _th('Title', flex: 2),
                            _th('Classification', flex: 2),
                            _th('Monitored'),
                            _th('Referred'),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final title = data['title'] as String? ?? 'Untitled';
                        final classification =
                            data['classification'] as String? ?? '—';
                        final ts = data['createdAt'] as Timestamp?;
                        final days = ts != null
                            ? DateTime.now().difference(ts.toDate()).inDays
                            : 0;
                        final referred = data['feelingBetter'] == false;

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
                                      title,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      classification,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$days days',
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
                                        color: referred
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        referred ? 'Referred' : 'Recovering',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: referred
                                              ? Colors.red
                                              : Colors.green,
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
