import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';
import '../widgets/admin_user_info.dart';

class AdminJournalLogReview extends StatefulWidget {
  const AdminJournalLogReview({super.key});

  @override
  State<AdminJournalLogReview> createState() => _AdminJournalLogReviewState();
}

class _AdminJournalLogReviewState extends State<AdminJournalLogReview> {
  // Created once per mount (not inside build()) so rebuilds such as a window
  // resize don't tear down the listener and reload the page.
  late final AdminPageController _pager = AdminPageController(
    FirebaseFirestore.instance
        .collectionGroup('journalEntries')
        .orderBy('createdAt', descending: true),
  );

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// "View user details": who the entry belongs to and how it stands, so an
  /// admin can decide whether the user needs to be referred. Only contact and
  /// profile basics plus the entry's category, date and status are shown; the
  /// journal's private content (descriptions, concerns, photos) is not.
  Future<void> _showUserDetails(AdminDoc entry) async {
    final uid = entry.reference.parent.parent?.id;
    final data = entry.data();
    try {
      final user = uid == null
          ? null
          : await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final profile = user?.data() ?? const <String, dynamic>{};
      final basics = {
        for (final (label, value) in adminUserInfoRows(profile)) label: value,
      };
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      final referred = data['feelingBetter'] == false;
      final deactivated = profile['deactivated'] == true;
      await showAdminUserInfo(
        context,
        profile,
        title: 'User details',
        rows: [
          for (final label in const [
            'Username',
            'First Name',
            'Last Name',
            'Age',
            'Gender',
            'Email',
            'Phone number',
          ])
            (label, basics[label] ?? 'N/A'),
          (
            'Account status',
            user == null || !user.exists
                ? 'N/A'
                : deactivated
                ? 'Deactivated'
                : 'Active',
          ),
          (
            'Journal entry',
            (data['title'] as String?)?.trim().isNotEmpty == true
                ? data['title'] as String
                : 'Untitled',
          ),
          ('Category', (data['classification'] as String?) ?? 'N/A'),
          (
            'Logged on',
            created == null ? 'N/A' : DateFormat('MMM d, y').format(created),
          ),
          (
            'Days monitored',
            created == null
                ? 'N/A'
                : '${DateTime.now().difference(created).inDays} days',
          ),
          (
            'Status',
            referred
                ? 'Referred (said they are not feeling better)'
                : 'Recovering',
          ),
        ],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load this user's details.")),
      );
    }
  }

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
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No journal entries yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
              return SingleChildScrollView(
                padding: EdgeInsets.all(adminIsNarrow(context) ? 16 : 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      AdminHScroll(
                        minWidth: 720,
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
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...docs.map((doc) {
                              final data = doc.data();
                              final title =
                                  data['title'] as String? ?? 'Untitled';
                              final classification =
                                  data['classification'] as String? ?? '—';
                              final ts = data['createdAt'] as Timestamp?;
                              final days = ts != null
                                  ? DateTime.now()
                                        .difference(ts.toDate())
                                        .inDays
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              referred
                                                  ? 'Referred'
                                                  : 'Recovering',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color: referred
                                                        ? Colors.red
                                                        : Colors.green,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'More actions',
                                          icon: const Icon(
                                            Icons.more_vert,
                                            size: 18,
                                          ),
                                          onSelected: (_) =>
                                              _showUserDetails(doc),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'details',
                                              child: Text('View details'),
                                            ),
                                          ],
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
