import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import 'admin_shared_widgets.dart';

typedef AdminDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Cursor-based paging over an already-ordered Firestore [query].
///
/// Only the current page is ever read (`limit` + `startAfterDocument` /
/// `endBeforeDocument`), never the whole collection. The page is a live
/// snapshot listener, so edits made on screen still update in place. The
/// total (for "Page X of Y") comes from a cheap `count()` aggregate.
///
/// [query] must already have an `orderBy`; Firestore appends the document ID
/// as a tiebreaker, which keeps the order stable (no duplicated or skipped
/// rows between pages).
class AdminPageController extends ChangeNotifier {
  AdminPageController(this.query, {this.pageSize = 10}) {
    goToFirst();
    _refreshTotal();
  }

  final Query<Map<String, dynamic>> query;
  final int pageSize;

  List<AdminDoc> docs = const [];
  bool loading = true;
  Object? error;
  int page = 1;
  int? total;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Query<Map<String, dynamic>>? _activeQuery;
  int _activePage = 1;
  bool _disposed = false;

  int? get totalPages => total == null
      ? null
      : (total == 0 ? 1 : (total! + pageSize - 1) ~/ pageSize);
  bool get hasPrev => page > 1;
  bool get hasNext =>
      totalPages != null ? page < totalPages! : docs.length == pageSize;
  int get rangeStart => docs.isEmpty ? 0 : (page - 1) * pageSize + 1;
  int get rangeEnd => docs.isEmpty ? 0 : rangeStart + docs.length - 1;

  void goToFirst() => _listen(query.limit(pageSize), 1);

  void next() {
    if (docs.isEmpty || !hasNext) return;
    _listen(query.startAfterDocument(docs.last).limit(pageSize), page + 1);
  }

  void previous() {
    if (docs.isEmpty || !hasPrev) return;
    _listen(
      query.endBeforeDocument(docs.first).limitToLast(pageSize),
      page - 1,
    );
  }

  Future<void> goToLast() async {
    final count = total ?? await _refreshTotal();
    if (count == null || count == 0) return;
    final pages = (count + pageSize - 1) ~/ pageSize;
    final onLastPage = count - (pages - 1) * pageSize;
    _listen(query.limitToLast(onLastPage), pages);
  }

  void retry() {
    _listen(_activeQuery ?? query.limit(pageSize), _activePage);
    _refreshTotal();
  }

  Future<int?> _refreshTotal() async {
    try {
      final snapshot = await query.count().get();
      total = snapshot.count;
      _notify();
    } catch (_) {
      // The pager just omits "of Y" if the count can't be read.
    }
    return total;
  }

  void _listen(Query<Map<String, dynamic>> q, int newPage) {
    _sub?.cancel();
    _activeQuery = q;
    _activePage = newPage;
    loading = true;
    error = null;
    _notify();

    var firstEvent = true;
    _sub = q.snapshots().listen(
      (snapshot) {
        final listChanged = snapshot.docChanges.any(
          (c) => c.type != DocumentChangeType.modified,
        );
        docs = snapshot.docs;
        page = newPage;
        loading = false;
        error = null;
        if (docs.isEmpty && newPage > 1) {
          // The page emptied out (e.g. its last record was removed).
          goToFirst();
          _refreshTotal();
          return;
        }
        _notify();
        if (!firstEvent && listChanged) _refreshTotal();
        firstEvent = false;
      },
      onError: (Object e) {
        error = e;
        loading = false;
        _notify();
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// Handles the first-load spinner and the error + retry state, then hands
/// the current page of [docs] to [builder]. An empty page is passed through
/// so each screen can show its own empty message inside its table.
class AdminPagedList extends StatelessWidget {
  const AdminPagedList({
    super.key,
    required this.controller,
    required this.builder,
  });

  final AdminPageController controller;
  final Widget Function(BuildContext context, List<AdminDoc> docs) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (c.error != null && c.docs.isEmpty) {
          return AdminPageError(error: c.error!, onRetry: c.retry);
        }
        if (c.loading && c.docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(context, c.docs);
      },
    );
  }
}

class AdminPageError extends StatelessWidget {
  const AdminPageError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(height: 8),
            Text(
              adminErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Showing 1–10 of 32 entries" + First / Previous / current page / Next /
/// Last. Buttons are disabled at the ends and while a page is loading.
class AdminPager extends StatelessWidget {
  const AdminPager({super.key, required this.controller});

  final AdminPageController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final idle = !c.loading;
        final summary = c.docs.isEmpty
            ? ''
            : c.total == null
            ? 'Showing ${c.rangeStart}–${c.rangeEnd}'
            : 'Showing ${c.rangeStart}–${c.rangeEnd} of ${c.total} entries';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.loading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(summary, style: theme.textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PagerButton(
                    icon: Icons.keyboard_double_arrow_left,
                    tooltip: 'First page',
                    onPressed: idle && c.hasPrev ? c.goToFirst : null,
                  ),
                  _PagerButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous page',
                    onPressed: idle && c.hasPrev ? c.previous : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AdminTheme.maroon,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${c.page}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (c.totalPages != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'of ${c.totalPages}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  _PagerButton(
                    icon: Icons.chevron_right,
                    tooltip: 'Next page',
                    onPressed: idle && c.hasNext ? c.next : null,
                  ),
                  _PagerButton(
                    icon: Icons.keyboard_double_arrow_right,
                    tooltip: 'Last page',
                    onPressed: idle && c.hasNext && c.total != null
                        ? () => c.goToLast()
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 36,
        height: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AdminTheme.maroon,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Tooltip(message: tooltip, child: Icon(icon, size: 18)),
        ),
      ),
    );
  }
}
