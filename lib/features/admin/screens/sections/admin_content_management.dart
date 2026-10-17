import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminContentManagement extends StatefulWidget {
  const AdminContentManagement({super.key});

  @override
  State<AdminContentManagement> createState() => _AdminContentManagementState();
}

class _AdminContentManagementState extends State<AdminContentManagement> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  // `source` already exists on imported articles (the chatbot cites it), so
  // the form edits that same field; `sourceUrl` is new and optional.
  final _sourceController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  String? _sourceUrlError;
  String _category = 'Emergency';
  bool _offlineAvailable = true;
  String? _editingId;
  bool _saving = false;

  /// Articles with an unpublish/delete/restore in flight, so a double click
  /// can't send the same change twice.
  final Set<String> _busyIds = {};

  // The "Live" status column/badge is hidden for now. The stored `status`
  // field (still written on create below) and this code are intentionally
  // kept — flip to true to bring the column back.
  static const bool _showLiveStatus = false;

  final List<String> _categories = [
    'Emergency',
    'Injuries',
    'Wounds',
    'Skin',
    'Burns',
  ];

  /// The curated categories, plus whatever `_category` currently holds if
  /// it isn't one of them — keeps the dropdown from crashing when editing
  /// an article whose real category came from bulk-imported data.
  List<String> get _dropdownCategories => _categories.contains(_category)
      ? _categories
      : [..._categories, _category];

  late final AdminPageController _pager = AdminPageController(
    FirebaseFirestore.instance
        .collection('firstAidContent')
        .orderBy('updatedAt', descending: true),
  );

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _sourceController.dispose();
    _sourceUrlController.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// Null when [value] is empty (the field is optional) or a usable web
  /// address; otherwise the message to show under the field.
  static String? validateSourceUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
    return ok
        ? null
        : 'Enter a full web address, e.g. https://www.redcross.org.ph';
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name of Products is required.')),
      );
      return;
    }
    final urlError = validateSourceUrl(_sourceUrlController.text);
    setState(() => _sourceUrlError = urlError);
    if (urlError != null) return;

    final title = _titleController.text.trim();
    final source = _sourceController.text.trim();
    final sourceUrl = _sourceUrlController.text.trim();
    final editing = _editingId != null;
    // When editing, clearing a source field removes it; when creating, an
    // empty one is simply left out.
    Object sourceValue(String v) => v.isEmpty ? FieldValue.delete() : v;
    final data = <String, Object>{
      'title': title,
      'content': _contentController.text.trim(),
      'category': _category,
      'offlineAvailable': _offlineAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
      if (editing || source.isNotEmpty) 'source': sourceValue(source),
      if (editing || sourceUrl.isNotEmpty) 'sourceUrl': sourceValue(sourceUrl),
    };
    setState(() => _saving = true);
    try {
      final collection = FirebaseFirestore.instance.collection(
        'firstAidContent',
      );
      if (editing) {
        await collection.doc(_editingId).update(data);
        logAdminAction(
          'Updated article "$title"',
          targetType: 'content',
          targetId: _editingId,
          targetName: title,
        );
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['status'] = 'Live';
        final ref = await collection.add(data);
        logAdminAction(
          'Created article "$title"',
          type: 'CREATE',
          targetType: 'content',
          targetId: ref.id,
          targetName: title,
        );
      }
      _titleController.clear();
      _contentController.clear();
      _sourceController.clear();
      _sourceUrlController.clear();
      if (mounted) setState(() => _editingId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: ${adminErrorMessage(e)}")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Runs one status change on article [id] once at a time, with feedback.
  Future<void> _change(
    String id,
    String title, {
    required Map<String, Object?> update,
    required String audit,
    required String done,
    String auditType = 'UPDATE',
  }) async {
    if (!_busyIds.add(id)) return;
    setState(() {});
    try {
      await FirebaseFirestore.instance
          .collection('firstAidContent')
          .doc(id)
          .update({...update, 'updatedAt': FieldValue.serverTimestamp()});
      logAdminAction(
        audit,
        type: auditType,
        targetType: 'content',
        targetId: id,
        targetName: title,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update: ${adminErrorMessage(e)}")),
        );
      }
    } finally {
      _busyIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  /// Unpublish is the normal way to take an article down: it is hidden from
  /// users but stays here and can be re-published.
  Future<void> _togglePublished(String id, String title, bool publish) async {
    if (!publish) {
      final ok = await adminConfirm(
        context,
        title: 'Unpublish "$title"?',
        message:
            'Users will no longer see this article. It stays in the library '
            'and you can re-publish it at any time.',
        confirmLabel: 'Unpublish',
      );
      if (!ok || !mounted) return;
    }
    await _change(
      id,
      title,
      update: publish
          ? {
              'status': 'Live',
              'unpublishedAt': FieldValue.delete(),
              'unpublishedBy': FieldValue.delete(),
            }
          : {
              'status': 'unpublished',
              'unpublishedAt': FieldValue.serverTimestamp(),
              'unpublishedBy': FirebaseAuth.instance.currentUser?.uid,
            },
      audit: publish
          ? 'Published article "$title"'
          : 'Unpublished article "$title"',
      done: publish ? 'Article published.' : 'Article unpublished.',
    );
  }

  /// Soft delete: nothing is erased. The article is unpublished (so users
  /// can't see it), stamped deleted, and can be restored.
  Future<void> _softDelete(String id, String title) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete "$title"?',
      message:
          'This article will be hidden from users and marked as deleted. '
          "It isn't erased: you can restore it later.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _change(
      id,
      title,
      update: {
        'status': 'unpublished',
        'unpublishedAt': FieldValue.serverTimestamp(),
        'unpublishedBy': FirebaseAuth.instance.currentUser?.uid,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': FirebaseAuth.instance.currentUser?.uid,
      },
      audit: 'Deleted article "$title"',
      auditType: 'DELETE',
      done: 'Article deleted. You can restore it from its row.',
    );
  }

  /// Brings a deleted article back as *unpublished*, so nothing reaches users
  /// until an admin deliberately re-publishes it.
  Future<void> _restore(String id, String title) {
    return _change(
      id,
      title,
      update: {
        'deletedAt': FieldValue.delete(),
        'deletedBy': FieldValue.delete(),
      },
      audit: 'Restored article "$title"',
      done: 'Article restored (still unpublished).',
    );
  }

  void _preview() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _titleController.text.trim().isEmpty
              ? '(No product name)'
              : _titleController.text.trim(),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(_category)),
                    if (_offlineAvailable)
                      const Chip(label: Text('Offline available')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _contentController.text.trim().isEmpty
                      ? '(No content yet)'
                      : _contentController.text.trim(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
          title: 'Content management',
          subtitle:
              'Update first aid instructions, add new emergency procedures, and modify health information to ensure accuracy.',
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content library table
              Expanded(
                flex: 3,
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
                                  _th('Name of Products', flex: 3),
                                  _th('Category'),
                                  _th('Updated'),
                                  if (_showLiveStatus) _th('Status'),
                                  _th('Action', flex: 3),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (docs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No content yet.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ...docs.map((doc) {
                              final data = doc.data();
                              final ts = data['updatedAt'] as Timestamp?;
                              final updated = ts != null
                                  ? DateFormat('MMM d, y').format(ts.toDate())
                                  : '';
                              final title = data['title'] as String? ?? '';
                              final deleted = data['deletedAt'] != null;
                              final unpublished =
                                  data['status'] == 'unpublished';
                              final busy = _busyIds.contains(doc.id);
                              final source = (data['source'] as String?)
                                  ?.trim();
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
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      title,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            color: Colors.black,
                                                          ),
                                                    ),
                                                  ),
                                                  if (deleted ||
                                                      unpublished) ...[
                                                    const SizedBox(width: 8),
                                                    _statePill(
                                                      deleted
                                                          ? 'Deleted'
                                                          : 'Unpublished',
                                                      deleted
                                                          ? Colors.red
                                                          : Colors.orange,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (source != null &&
                                                  source.isNotEmpty)
                                                Text(
                                                  'Source: $source',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            // Bulk-imported articles (via
                                            // seed_firestore/seed.js) store
                                            // this under `subtopic`/`topic`
                                            // instead of `category`, which
                                            // only articles saved through
                                            // this admin form itself set.
                                            data['category'] as String? ??
                                                data['subtopic'] as String? ??
                                                data['topic'] as String? ??
                                                '',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            updated,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.black87,
                                                ),
                                          ),
                                        ),
                                        if (_showLiveStatus)
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Live',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: Colors.green,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          flex: 3,
                                          child: Wrap(
                                            children: [
                                              if (deleted)
                                                TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _restore(
                                                          doc.id,
                                                          title,
                                                        ),
                                                  child: Text(
                                                    'Restore',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                )
                                              else ...[
                                                TextButton(
                                                  onPressed: () {
                                                    _titleController.text =
                                                        data['title'] ?? '';
                                                    _contentController.text =
                                                        data['content'] ?? '';
                                                    _sourceController.text =
                                                        data['source']
                                                            as String? ??
                                                        '';
                                                    _sourceUrlController.text =
                                                        data['sourceUrl']
                                                            as String? ??
                                                        '';
                                                    setState(() {
                                                      _sourceUrlError = null;
                                                      _editingId = doc.id;
                                                      // Same fallback as the list
                                                      // column: bulk-imported
                                                      // articles store this under
                                                      // `subtopic`/`topic` instead
                                                      // of `category`.
                                                      final resolved =
                                                          data['category']
                                                              as String? ??
                                                          data['subtopic']
                                                              as String? ??
                                                          data['topic']
                                                              as String?;
                                                      _category =
                                                          (resolved == null ||
                                                              resolved.isEmpty)
                                                          ? 'Emergency'
                                                          : resolved;
                                                    });
                                                  },
                                                  child: Text(
                                                    'Edit',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _togglePublished(
                                                          doc.id,
                                                          title,
                                                          unpublished,
                                                        ),
                                                  child: Text(
                                                    unpublished
                                                        ? 'Re-publish'
                                                        : 'Unpublish',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _softDelete(
                                                          doc.id,
                                                          title,
                                                        ),
                                                  child: Text(
                                                    'Delete',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .error,
                                                        ),
                                                  ),
                                                ),
                                              ],
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
                    );
                  },
                ),
              ),
              // Edit panel
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingId != null ? 'Edit article' : 'New article',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Name of Products',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter name of product',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Category',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: Colors.black),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    // DropdownButtonFormField asserts/crashes
                                    // if `initialValue` isn't one of `items`.
                                    // Bulk-imported articles can carry a
                                    // category (from `subtopic`/`topic`)
                                    // that isn't one of the 5 curated
                                    // options below, so that value is added
                                    // to the list rather than dropped —
                                    // editing never crashes, and the admin
                                    // can still switch to a curated one.
                                    initialValue: _category,
                                    items: _dropdownCategories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline available',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.black,
                                  ),
                                ),
                                Switch(
                                  value: _offlineAvailable,
                                  onChanged: (v) =>
                                      setState(() => _offlineAvailable = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Content',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contentController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Enter content',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Source / Reference (optional)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _sourceController,
                          maxLength: 150,
                          decoration: const InputDecoration(
                            hintText:
                                'e.g. Philippine Red Cross First Aid Manual',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sourceUrlController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'https://… (optional link)',
                            errorText: _sourceUrlError,
                          ),
                          onChanged: (_) {
                            if (_sourceUrlError != null) {
                              setState(() => _sourceUrlError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving ? 'Saving…' : 'Save changes',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _preview,
                                child: const Text(
                                  'Preview',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statePill(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color.shade800,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.black),
      ),
    );
  }
}
