import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

/// Display only: a trailing "(Category)" is dropped from a product name, since
/// the Category column already shows it (e.g. "PHYSIOGEL (Skin)" shows as
/// "PHYSIOGEL"). The stored title is never changed.
String contentDisplayName(String title, String category) {
  final match = RegExp(r'\s*\(([^()]*)\)\s*$').firstMatch(title);
  if (match == null) return title;
  final inner = match.group(1)!.trim().toLowerCase();
  final cat = category.trim().toLowerCase();
  if (inner.isEmpty || cat.isEmpty) return title;
  final sameThing = inner == cat || cat.contains(inner) || inner.contains(cat);
  final stripped = title.substring(0, match.start).trimRight();
  return sameThing && stripped.isNotEmpty ? stripped : title;
}

class AdminContentManagement extends StatefulWidget {
  const AdminContentManagement({super.key, @visibleForTesting this.pager});

  /// Supplies the article list in tests; the app always builds its own.
  final AdminPageController? pager;

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
  String? _editingId;
  bool _saving = false;

  /// Articles with an unpublish/delete/restore in flight, so a double click
  /// can't send the same change twice.
  final Set<String> _busyIds = {};

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

  late final AdminPageController _pager =
      widget.pager ??
      AdminPageController(
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
    if (widget.pager == null) _pager.dispose();
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
                Wrap(spacing: 8, children: [Chip(label: Text(_category))]),
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

  // ---- layout -------------------------------------------------------------

  /// Table and article panel sit side by side from this page width up; below
  /// it the panel stacks under the table.
  static const double _sideBySideFrom = 1100;
  static const double _panelWidth = 380;

  static const _headerBackground = Color(0xFFF7F7F7);
  static const _rule = Color(0xFFEEEEEE);

  void _edit(AdminDoc doc, Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _contentController.text = data['content'] ?? '';
    _sourceController.text = data['source'] as String? ?? '';
    _sourceUrlController.text = data['sourceUrl'] as String? ?? '';
    setState(() {
      _sourceUrlError = null;
      _editingId = doc.id;
      // Bulk-imported articles store the category under `subtopic`/`topic`
      // instead of `category`.
      final resolved =
          data['category'] as String? ??
          data['subtopic'] as String? ??
          data['topic'] as String?;
      _category = (resolved == null || resolved.isEmpty)
          ? 'Emergency'
          : resolved;
    });
  }

  String _categoryOf(Map<String, dynamic> data) =>
      data['category'] as String? ??
      data['subtopic'] as String? ??
      data['topic'] as String? ??
      '';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sideBySide = width >= _sideBySideFrom;
        final compact = width < 768; // tighter cells, one ⋯ menu per row
        final cards = width < 600; // each row becomes a stacked card
        final sidePad = compact ? 16.0 : 32.0;
        final table = _tableCard(compact: compact, cards: cards);
        final panel = _editPanel(cards: cards);
        return Column(
          children: [
            AdminHeader(
              title: 'Content management',
              subtitle:
                  'Update first aid instructions, add new emergency procedures, and modify health information to ensure accuracy.',
              horizontalPadding: sidePad,
              verticalPadding: 24,
              titleGap: 4,
            ),
            Expanded(
              child: sideBySide
                  // The panel stays put at the top while the table scrolls.
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(sidePad, 20, sidePad, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SingleChildScrollView(child: table)),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: _panelWidth,
                            child: SingleChildScrollView(child: panel),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(sidePad, 20, sidePad, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [table, const SizedBox(height: 24), panel],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---- table --------------------------------------------------------------

  Widget _tableCard({required bool compact, required bool cards}) {
    final theme = Theme.of(context);
    return Container(
      // Clips the rows and header to the card's rounded corners, so nothing
      // pokes out and no scrollbar appears between the table and the panel.
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListenableBuilder(
        listenable: _pager,
        builder: (context, _) {
          if (_pager.error != null && _pager.docs.isEmpty) {
            return SizedBox(
              height: 200,
              child: AdminPageError(
                error: _pager.error!,
                onRetry: _pager.retry,
              ),
            );
          }
          if (_pager.loading && _pager.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = _pager.docs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final padH = compact ? 12.0 : 20.0;
                  final padV = compact ? 10.0 : 12.0;
                  // The columns are 42 / 24 / 14 / 20 percent of the table.
                  // When the table is too narrow for the date or the three
                  // action links to fit on one line, use a shorter date and
                  // the ⋯ menu instead of letting them wrap or overflow. The
                  // widths are measured from the real text, so this holds
                  // for whatever font is in use.
                  final inner = box.maxWidth - 2; // inside the card border
                  final updatedInner = inner * 0.14 - padH * 2;
                  final actionInner = inner * 0.20 - padH * 2;
                  final base = DefaultTextStyle.of(context).style;
                  final linksNeed =
                      _measure('Edit', base, 12) +
                      math.max(
                        _measure('Unpublish', base, 12),
                        _measure('Re-publish', base, 12),
                      ) +
                      _measure('Delete', base, 12) +
                      32 + // two 16px gaps
                      8; // breathing room
                  final dateNeed = _measure('May 30, 2026', base, 13) + 4;
                  final shortDate = updatedInner < dateNeed;
                  final menu = compact || actionInner < linksNeed;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!cards) _headerRow(theme, padH, padV),
                      if (docs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No content yet.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      for (final doc in docs)
                        _articleRow(
                          theme,
                          doc,
                          padH: padH,
                          padV: padV,
                          compact: compact,
                          cards: cards,
                          menu: menu || cards,
                          shortDate: shortDate,
                        ),
                    ],
                  );
                },
              ),
              AdminPager(
                controller: _pager,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 20,
                  vertical: 14,
                ),
                topBorder: true,
                controlGap: 6,
                centered: cards,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Width of [text] on one line at [size], in the current font.
  double _measure(String text, TextStyle base, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(fontSize: size, fontWeight: FontWeight.w500),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _headerRow(ThemeData theme, double padH, double padV) {
    Widget th(String label, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF777777),
          ),
        ),
      ),
    );
    return Container(
      color: _headerBackground,
      padding: EdgeInsets.symmetric(vertical: padV),
      child: Row(
        children: [
          th('Name of Products', 42),
          th('Category', 24),
          th('Updated', 14),
          th('Action', 20),
        ],
      ),
    );
  }

  Widget _articleRow(
    ThemeData theme,
    AdminDoc doc, {
    required double padH,
    required double padV,
    required bool compact,
    required bool cards,
    required bool menu,
    required bool shortDate,
  }) {
    final data = doc.data();
    final ts = data['updatedAt'] as Timestamp?;
    final updated = ts == null
        ? ''
        : DateFormat(shortDate ? 'M/d/yy' : 'MMM d, y').format(ts.toDate());
    final title = data['title'] as String? ?? '';
    final category = _categoryOf(data);
    final deleted = data['deletedAt'] != null;
    final unpublished = data['status'] == 'unpublished';
    final busy = _busyIds.contains(doc.id);
    final source = (data['source'] as String?)?.trim();
    final shownName = contentDisplayName(title, category);

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Tooltip(
                message: title,
                child: Text(
                  shownName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (deleted || unpublished) ...[
              const SizedBox(width: 8),
              _statePill(
                deleted ? 'Deleted' : 'Unpublished',
                deleted ? Colors.red : Colors.orange,
              ),
            ],
          ],
        ),
        // The source line is hidden on small screens.
        if (!compact && source != null && source.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Source: $source',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );

    final pill = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEAEA),
          borderRadius: BorderRadius.circular(999),
        ),
        // Wraps between words only, never in the middle of one.
        child: Text(
          category,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF7A0C0C),
          ),
        ),
      ),
    );

    final date = Text(
      updated,
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFF555555),
      ),
    );

    final actions = menu
        ? Align(
            alignment: Alignment.centerLeft,
            child: _actionsMenu(doc, data, title, deleted, unpublished, busy),
          )
        : _actionLinks(doc, data, title, deleted, unpublished, busy);

    final Widget body;
    if (cards) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            name,
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(child: pill),
                const SizedBox(width: 12),
                date,
              ],
            ),
            const SizedBox(height: 6),
            actions,
          ],
        ),
      );
    } else {
      // Every cell has its own side padding (20px, or 12px on small
      // screens), so the columns keep the same edges as the header row.
      Widget cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: child,
        ),
      );
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: padV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            cell(42, name),
            cell(24, pill),
            cell(14, date),
            cell(20, actions),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: _rule),
        body,
      ],
    );
  }

  /// Edit / Unpublish / Delete as plain links, 16px apart, on one line.
  Widget _actionLinks(
    AdminDoc doc,
    Map<String, dynamic> data,
    String title,
    bool deleted,
    bool unpublished,
    bool busy,
  ) {
    final style = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12),
    );
    final error = Theme.of(context).colorScheme.error;
    final links = deleted
        ? [
            TextButton(
              style: style,
              onPressed: busy ? null : () => _restore(doc.id, title),
              child: const Text('Restore'),
            ),
          ]
        : [
            TextButton(
              style: style,
              onPressed: () => _edit(doc, data),
              child: const Text('Edit'),
            ),
            TextButton(
              style: style,
              onPressed: busy
                  ? null
                  : () => _togglePublished(doc.id, title, unpublished),
              child: Text(unpublished ? 'Re-publish' : 'Unpublish'),
            ),
            TextButton(
              style: style.copyWith(
                foregroundColor: WidgetStatePropertyAll(error),
              ),
              onPressed: busy ? null : () => _softDelete(doc.id, title),
              child: const Text('Delete'),
            ),
          ];
    return Row(
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          links[i],
        ],
      ],
    );
  }

  /// The same options behind a single ⋯ button, for small screens.
  Widget _actionsMenu(
    AdminDoc doc,
    Map<String, dynamic> data,
    String title,
    bool deleted,
    bool unpublished,
    bool busy,
  ) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      enabled: !busy,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        switch (value) {
          case 'restore':
            _restore(doc.id, title);
          case 'edit':
            _edit(doc, data);
          case 'publish':
            _togglePublished(doc.id, title, unpublished);
          case 'delete':
            _softDelete(doc.id, title);
        }
      },
      itemBuilder: (_) => deleted
          ? const [PopupMenuItem(value: 'restore', child: Text('Restore'))]
          : [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'publish',
                child: Text(unpublished ? 'Re-publish' : 'Unpublish'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: error)),
              ),
            ],
    );
  }

  // ---- new / edit article panel --------------------------------------------

  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );

  /// One-line input: 44px high, 14px text, 14px side padding.
  InputDecoration _field({String? hint, String? error}) => InputDecoration(
    hintText: hint,
    errorText: error,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    constraints: const BoxConstraints(minHeight: 44),
  );

  Widget _labelled(String label, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 6),
      input,
    ],
  );

  Widget _editPanel({required bool cards}) {
    final theme = Theme.of(context);
    const inputText = TextStyle(fontSize: 14);
    final save = ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      onPressed: _saving ? null : _save,
      child: Text(_saving ? 'Saving…' : 'Save changes'),
    );
    final preview = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      onPressed: _preview,
      child: const Text('Preview', style: TextStyle(color: Colors.black)),
    );
    final children = <Widget>[
      Text(
        _editingId != null ? 'Edit article' : 'New article',
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.black),
      ),
      _labelled(
        'Name of Products',
        TextField(
          controller: _titleController,
          style: inputText,
          decoration: _field(hint: 'Enter name of product'),
        ),
      ),
      _labelled(
        'Category',
        DropdownButtonFormField<String>(
          // DropdownButtonFormField asserts/crashes if `initialValue` isn't
          // one of `items`. Bulk-imported articles can carry a category (from
          // `subtopic`/`topic`) that isn't one of the 5 curated options, so
          // that value is added to the list rather than dropped: editing
          // never crashes, and the admin can still switch to a curated one.
          initialValue: _category,
          isExpanded: true,
          style: inputText.copyWith(color: Colors.black87),
          decoration: _field(),
          items: _dropdownCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
      ),
      _labelled(
        'Content',
        TextField(
          controller: _contentController,
          style: inputText,
          minLines: 6, // about 140px tall, growing as the text does
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Enter content',
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
      _labelled(
        'Source / Reference (optional)',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _sourceController,
              maxLength: 150,
              style: inputText,
              decoration: _field(
                hint: 'e.g. Philippine Red Cross First Aid Manual',
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceUrlController,
              keyboardType: TextInputType.url,
              style: inputText,
              decoration: _field(
                hint: 'https://… (optional link)',
                error: _sourceUrlError,
              ),
              onChanged: (_) {
                if (_sourceUrlError != null) {
                  setState(() => _sourceUrlError = null);
                }
              },
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: cards
            // Small screens: the buttons stack, each full width.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [save, const SizedBox(height: 12), preview],
              )
            : Row(
                children: [
                  Expanded(child: save),
                  const SizedBox(width: 12),
                  Expanded(child: preview),
                ],
              ),
      ),
    ];
    return Container(
      padding: EdgeInsets.all(cards ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            children[i],
          ],
        ],
      ),
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
}
