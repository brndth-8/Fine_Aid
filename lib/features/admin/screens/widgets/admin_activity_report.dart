import '../../../../core/widgets/app_date_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_name_lookup.dart';
import 'admin_pagination.dart';
import 'admin_shared_widgets.dart';

/// "Admin activity report": who did what in the admin portal, built from the
/// audit log. Filtered by date range, admin and action type; the filters are
/// part of the Firestore query (not applied to a downloaded list), and the
/// table pages with the same pager as the other admin screens.
///
/// CSV export columns (nothing else is exported): Date/time, Admin, Action,
/// Target, Result. Admins and targets appear by name, never by raw id.
class AdminActivityReport extends StatefulWidget {
  const AdminActivityReport({super.key});

  @override
  State<AdminActivityReport> createState() => _AdminActivityReportState();
}

class _AdminActivityReportState extends State<AdminActivityReport> {
  static const _types = ['CREATE', 'UPDATE', 'DELETE', 'LOGIN'];
  static const _exportBatch = 500;
  static const _exportCap = 20000;

  late DateTimeRange _range = () {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }();
  String? _adminUid;
  String? _type;
  List<({String uid, String label})> _admins = const [];

  final _names = AdminNameLookup(
    collection: 'admins',
    nameOf: (data) =>
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? data['displayName'] as String
        : data['email'] as String?,
  );

  late AdminPageController _pager = _newPager();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  @override
  void dispose() {
    _pager.removeListener(_loadNamesForPage);
    _pager.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    var q = FirebaseFirestore.instance
        .collection('auditLogs')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_range.start),
        )
        .where(
          'timestamp',
          isLessThan: Timestamp.fromDate(
            _range.end.add(const Duration(days: 1)),
          ),
        );
    if (_adminUid != null) q = q.where('actorUid', isEqualTo: _adminUid);
    if (_type != null) q = q.where('type', isEqualTo: _type);
    return q.orderBy('timestamp', descending: true);
  }

  AdminPageController _newPager() {
    final pager = AdminPageController(_query());
    pager.addListener(_loadNamesForPage);
    return pager;
  }

  void _applyFilters() {
    final old = _pager;
    old.removeListener(_loadNamesForPage);
    setState(() => _pager = _newPager());
    old.dispose();
  }

  Future<void> _loadAdmins() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('admins').get();
      final list = [
        for (final d in snap.docs)
          (
            uid: d.id,
            label:
                ((d.data()['displayName'] as String?)?.trim().isNotEmpty == true
                    ? d.data()['displayName'] as String
                    : d.data()['email'] as String?) ??
                'Admin',
          ),
      ]..sort((a, b) => a.label.compareTo(b.label));
      if (mounted) setState(() => _admins = list);
    } catch (_) {
      // The admin filter simply stays on "All admins".
    }
  }

  Future<void> _loadNamesForPage() async {
    final changed = await _names.ensure(
      _pager.docs.map((d) => auditActorUid(d.data())),
    );
    if (changed && mounted) setState(() {});
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showAppDateRangePicker(
      context,
      initial: _range,
      firstDate: DateTime(2024),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    _range = picked;
    _applyFilters();
  }

  String _result(Map<String, dynamic> data) => switch (data['result']) {
    'success' => 'Success',
    'failure' => 'Failed',
    _ => '—', // Entries from before results were recorded.
  };

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
      final rows = <List<Object?>>[];
      DocumentSnapshot<Map<String, dynamic>>? last;
      // Read in batches rather than one huge get(), and give the UI a turn
      // between batches so it doesn't freeze.
      while (rows.length < _exportCap) {
        var q = _query().limit(_exportBatch);
        if (last != null) q = q.startAfterDocument(last);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        await _names.ensure(snap.docs.map((d) => auditActorUid(d.data())));
        for (final doc in snap.docs) {
          final data = doc.data();
          final ts = (data['timestamp'] as Timestamp?)?.toDate();
          rows.add([
            ts == null ? '' : fmt.format(ts.toLocal()),
            auditActorLabel(data, _names),
            data['action'] ?? '',
            data['targetName'] ?? '',
            _result(data),
          ]);
        }
        last = snap.docs.last;
        if (snap.docs.length < _exportBatch) break;
        await Future<void>.delayed(Duration.zero);
      }
      await exportAdminCsv(
        filename: 'fine_aid_admin_activity.csv',
        headers: const ['Date/time', 'Admin', 'Action', 'Target', 'Result'],
        rows: rows,
      );
      logAdminAction(
        'Exported admin activity report',
        targetType: 'report',
        targetName: 'Admin activity report',
        reason: 'csv_export',
      );
      if (mounted && rows.length >= _exportCap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported the newest $_exportCap entries. Narrow the date '
              'range to export older ones.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${adminErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('MMM d, y');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin activity report',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actions taken in the admin portal, from the audit log. '
                  'The admin filter covers entries recorded since the audit '
                  'log started storing the acting admin.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range_outlined, size: 16),
                      label: Text(
                        '${dateFmt.format(_range.start)} – '
                        '${dateFmt.format(_range.end)}',
                      ),
                    ),
                    _dropdown<String?>(
                      label: 'Admin',
                      value: _adminUid,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All admins'),
                        ),
                        for (final a in _admins)
                          DropdownMenuItem(value: a.uid, child: Text(a.label)),
                      ],
                      onChanged: (v) {
                        _adminUid = v;
                        _applyFilters();
                      },
                    ),
                    _dropdown<String?>(
                      label: 'Action type',
                      value: _type,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All types'),
                        ),
                        for (final t in _types)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) {
                        _type = v;
                        _applyFilters();
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_outlined, size: 16),
                      label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                _th(theme, 'Date & time', flex: 2),
                _th(theme, 'Admin', flex: 2),
                _th(theme, 'Action', flex: 4),
                _th(theme, 'Target', flex: 2),
                _th(theme, 'Result', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1),
          ListenableBuilder(
            listenable: _pager,
            builder: (context, _) {
              if (_pager.error != null && _pager.docs.isEmpty) {
                return SizedBox(
                  height: 180,
                  child: AdminPageError(
                    error: _pager.error!,
                    onRetry: _pager.retry,
                  ),
                );
              }
              if (_pager.loading && _pager.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_pager.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No admin activity matches these filters.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              final fmt = DateFormat('MMM d, y h:mm a');
              return Column(
                children: [
                  for (final doc in _pager.docs) ...[
                    _row(theme, fmt, doc.data()),
                    const Divider(height: 1),
                  ],
                  AdminPager(controller: _pager),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, DateFormat fmt, Map<String, dynamic> data) {
    final ts = (data['timestamp'] as Timestamp?)?.toDate();
    final result = _result(data);
    final color = switch (result) {
      'Success' => Colors.green,
      'Failed' => Colors.red,
      _ => Colors.grey,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              ts == null ? '' : fmt.format(ts.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              auditActorLabel(data, _names),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              data['action'] as String? ?? '',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (data['targetName'] as String?)?.isNotEmpty == true
                  ? data['targetName'] as String
                  : '—',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _th(ThemeData theme, String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}
