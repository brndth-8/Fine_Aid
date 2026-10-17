import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminAuditLogs extends StatefulWidget {
  const AdminAuditLogs({super.key});

  @override
  State<AdminAuditLogs> createState() => _AdminAuditLogsState();
}

class _AdminAuditLogsState extends State<AdminAuditLogs> {
  late final Query<Map<String, dynamic>> _logsQuery = FirebaseFirestore.instance
      .collection('auditLogs')
      .orderBy('timestamp', descending: true);

  late final AdminPageController _pager = AdminPageController(_logsQuery);

  // Audit entries are written by admins, so the actor is an `admins` doc.
  final _names = AdminNameLookup(
    collection: 'admins',
    nameOf: (data) =>
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? data['displayName'] as String
        : data['email'] as String?,
  );

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_loadNamesForPage);
  }

  @override
  void dispose() {
    _pager.removeListener(_loadNamesForPage);
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadNamesForPage() async {
    final changed = await _names.ensure(
      _pager.docs.map((d) => auditActorUid(d.data())),
    );
    if (changed && mounted) setState(() {});
  }

  String _actor(Map<String, dynamic> data) => auditActorLabel(data, _names);

  Future<void> _exportLogs() async {
    setState(() => _exporting = true);
    try {
      final snapshot = await _logsQuery.get();
      await _names.ensure(snapshot.docs.map((d) => auditActorUid(d.data())));
      await exportAdminCsv(
        filename: 'fine_aid_audit_logs.csv',
        headers: const ['Timestamp', 'Action', 'User', 'Type'],
        rows: snapshot.docs.map((doc) {
          final data = doc.data();
          final ts = data['timestamp'] as Timestamp?;
          return [
            ts?.toDate().toIso8601String() ?? '',
            data['action'] ?? '',
            _actor(data),
            data['type'] ?? 'UPDATE',
          ];
        }).toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
          title: 'Audit logs',
          subtitle:
              'Complete record of all admin activities â€” from account changes to notifications â€” for accountability and security.',
          action: OutlinedButton.icon(
            onPressed: _exporting ? null : _exportLogs,
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 16),
            label: Text(_exporting ? 'Exportingâ€¦' : 'Export logs'),
          ),
        ),
        Expanded(
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
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
                            _th(context, 'Timestamp', flex: 2),
                            _th(context, 'Action', flex: 4),
                            _th(context, 'User'),
                            _th(context, 'Type'),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No audit logs yet. Admin actions will appear here automatically.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final ts = data['timestamp'] as Timestamp?;
                        final timeText = ts != null
                            ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                            : '';
                        final actionType = data['type'] as String? ?? 'UPDATE';
                        final typeColor =
                            {
                              'CREATE': Colors.green,
                              'UPDATE': Colors.blue,
                              'DELETE': Colors.red,
                              'LOGIN': Colors.purple,
                            }[actionType] ??
                            Colors.grey;

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
                                      timeText,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      data['action'] ?? '',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _actor(data),
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
                                        color: typeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        actionType,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(color: typeColor),
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
