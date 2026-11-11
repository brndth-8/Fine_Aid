import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_audit_pdf.dart';
import '../widgets/admin_audit_text.dart';
import '../widgets/admin_file_download_stub.dart'
    if (dart.library.js_interop) '../widgets/admin_file_download_web.dart';
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminAuditLogs extends StatefulWidget {
  const AdminAuditLogs({super.key});

  @override
  State<AdminAuditLogs> createState() => _AdminAuditLogsState();
}

class _AdminAuditLogsState extends State<AdminAuditLogs> {
  /// The PDF holds the newest entries up to this many (readable, and quick
  /// to build in the browser).
  static const int _pdfLimit = 5000;
  static const int _pdfBatch = 500;

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

  String _time(Timestamp? ts) =>
      ts == null ? '' : DateFormat('MMM d, y h:mm a').format(ts.toDate());

  /// Builds a PDF of the log (plain-language text, same columns as the
  /// screen) and saves it straight to the device as a download.
  Future<void> _exportLogs() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = <List<String>>[];
      DocumentSnapshot<Map<String, dynamic>>? last;
      var truncated = false;
      while (true) {
        var q = _logsQuery.limit(_pdfBatch);
        if (last != null) q = q.startAfterDocument(last);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        await _names.ensure(snap.docs.map((d) => auditActorUid(d.data())));
        for (final doc in snap.docs) {
          final data = doc.data();
          rows.add([
            _time(data['timestamp'] as Timestamp?),
            describeAudit(data, _actor(data)),
            _actor(data),
            auditActionLabel(data),
          ]);
        }
        last = snap.docs.last;
        if (rows.length >= _pdfLimit) {
          truncated = snap.docs.length == _pdfBatch;
          break;
        }
        if (snap.docs.length < _pdfBatch) break;
        // Let the page breathe between batches.
        await Future<void>.delayed(Duration.zero);
      }

      final now = DateTime.now();
      final bytes = await buildAuditLogPdf(
        rows: rows,
        generatedAt: now,
        generatedBy: FirebaseAuth.instance.currentUser?.email ?? 'an admin',
        truncated: truncated,
      );
      final name =
          'fine_aid_audit_log_${DateFormat('yyyy-MM-dd').format(now)}.pdf';
      await downloadFile(
        filename: name,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      logAdminAction('Exported the audit log', reason: 'pdf_export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              truncated
                  ? 'Downloaded $name (the newest $_pdfLimit entries).'
                  : 'Downloaded $name.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't create the PDF: ${adminErrorMessage(e)}"),
          ),
        );
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
              'A plain-language record of what admins do in the portal, for accountability and security.',
          action: OutlinedButton.icon(
            onPressed: _exporting ? null : _exportLogs,
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: Text(_exporting ? 'Preparing PDF…' : 'Export log'),
          ),
        ),
        Expanded(
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
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
                        minWidth: 760,
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
                                  _th(context, 'Details', flex: 5),
                                  _th(context, 'User', flex: 2),
                                  _th(context, 'Action', flex: 2),
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
                              final actor = _actor(data);
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _time(
                                              data['timestamp'] as Timestamp?,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: Text(
                                            describeAudit(data, actor),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            actor,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            auditActionLabel(data),
                                            style: theme.textTheme.bodySmall,
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
