import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminJournalLogReview extends StatefulWidget {
  const AdminJournalLogReview({super.key});

  @override
  State<AdminJournalLogReview> createState() => _AdminJournalLogReviewState();
}

class _AdminJournalLogReviewState extends State<AdminJournalLogReview> {
  // Created once per mount instead of inline in build(): a fresh Stream
  // object on every rebuild makes StreamBuilder drop its cached data and
  // resubscribe from scratch, which is what made the list appear to
  // "disappear" or reload on every unrelated rebuild (e.g. a window resize).
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _entriesStream =
      FirebaseFirestore.instance
          .collectionGroup('journalEntries')
          .orderBy('createdAt', descending: true)
          .snapshots();

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
            stream: _entriesStream,
            builder: (context, snapshot) {
              final fallback = adminSnapshotFallback(snapshot);
              if (fallback != null) return fallback;

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
                            _th(context, 'Title', flex: 2),
                            _th(context, 'Classification', flex: 2),
                            _th(context, 'Monitored'),
                            _th(context, 'Referred'),
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
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.normal,
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
