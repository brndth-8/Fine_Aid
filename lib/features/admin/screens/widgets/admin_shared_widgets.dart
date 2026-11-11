import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';

/// Best-effort admin activity log write. Never throws — a logging failure
/// should not block the admin action that triggered it.
///
/// Firestore rules deny client writes to `auditLogs`, so this goes through
/// the `writeAuditLog` Cloud Function, which fills in the acting admin and
/// the timestamp from the verified sign-in (neither can be supplied here).
/// Keep [targetName] and [reason] short and free of personal or health
/// content; never pass passwords, tokens or message text.
Future<void> logAdminAction(
  String action, {
  String type = 'UPDATE',
  String? targetType,
  String? targetId,
  String? targetName,
  bool success = true,
  String? reason,
}) async {
  final payload = {
    'action': action,
    'type': type,
    'targetType': targetType,
    'targetId': targetId,
    'targetName': targetName,
    'result': success ? 'success' : 'failure',
    'reason': reason,
  };
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('writeAuditLog')
          .call<Object?>(payload);
      return;
    } catch (_) {
      // Retry once, then give up: best-effort only.
    }
  }
}

/// Builds a CSV file from [headers]/[rows] and hands it to the browser's
/// share/download flow. Throws on failure — callers should catch and show
/// their own error feedback.
Future<void> exportAdminCsv({
  required String filename,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_csvCell).join(','));
  }
  final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
    ),
  );
}

String _csvCell(Object? value) {
  var text = (value ?? '').toString();
  // Spreadsheet apps run a cell that starts with = + - @ as a formula, and
  // exported text includes names an admin or user typed. A leading quote
  // keeps it as plain text (CSV/formula-injection guard).
  if (value is String && text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// Truncates an id-like value for compact table display without throwing
/// when the value is shorter than [length] (e.g. "System").
String shortId(Object? value, {int length = 8, String fallback = 'Unknown'}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text.length > length ? text.substring(0, length) : text;
}

/// Returns a loading/error placeholder for a Firestore [AsyncSnapshot], or
/// null when the snapshot has data and the caller should render it.
///
/// Firestore streams surface some failures (e.g. a collection-group query
/// missing its composite index) as a stream error rather than data. Without
/// this check a bare `if (!snapshot.hasData)` spins forever instead of
/// telling the admin what went wrong.
Widget? adminSnapshotFallback(AsyncSnapshot<Object?> snapshot) {
  if (snapshot.hasError) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(height: 8),
            Text(
              _friendlyFirestoreError(snapshot.error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
  if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }
  return null;
}

/// Confirmation dialog in the same style as the user app's own
/// confirmations (`confirmLogout` in settings_screen.dart): rounded, outlined
/// Cancel, filled confirm button (error color when [destructive]). Only the
/// first tap counts, and Cancel, tapping outside or pressing back all return
/// false, so none of them can confirm the action.
Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var answered = false;
      void answer(bool value) {
        if (answered) return;
        answered = true;
        Navigator.pop(dialogContext, value);
      }

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          OutlinedButton(
            onPressed: () => answer(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => answer(true),
            style: destructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

String adminErrorMessage(Object? error) => _friendlyFirestoreError(error);

String _friendlyFirestoreError(Object? error) {
  final text = error.toString();
  if (text.contains('failed-precondition') ||
      text.contains('requires an index')) {
    return "This query needs a Firestore index that hasn't been created yet. "
        'Check the debug console for a link, or see firestore.indexes.json.';
  }
  if (text.contains('permission-denied')) {
    return "You don't have permission to view this data.";
  }
  return "Couldn't load this data. Please try again.";
}

/// Width below which the admin portal switches to its phone/tablet layout
/// (drawer navigation, stacked cards).
const double kAdminNarrowWidth = 900;

/// True when the portal is shown in a narrow window.
bool adminIsNarrow(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAdminNarrowWidth;

/// Page header. On a narrow window the action button drops below the title
/// instead of squeezing it, and the side padding shrinks.
class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  /// Left/right padding; the default is 24 (16 on a phone). A page whose
  /// content uses a different side padding passes it so the title lines up.
  final double? horizontalPadding;
  final double verticalPadding;

  /// Space between the title and the subtitle.
  final double titleGap;

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.horizontalPadding,
    this.verticalPadding = 16,
    this.titleGap = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (titleGap > 0) SizedBox(height: titleGap),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
    return Container(
      // Always the full width of the page, left-aligned, with or without an
      // action button (a Column parent would otherwise centre a shrunken box).
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding ?? (narrow ? 16 : 24),
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: action == null
          ? text
          : narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 12), action!],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 12),
                action!,
              ],
            ),
    );
  }
}

/// Lets a wide, column-based table scroll sideways on a small screen instead
/// of overflowing or squashing its columns. Wider windows use the full width.
class AdminHScroll extends StatefulWidget {
  const AdminHScroll({super.key, required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  State<AdminHScroll> createState() => _AdminHScrollState();
}

class _AdminHScrollState extends State<AdminHScroll> {
  // Its own controller: a visible scrollbar needs one, and the page's primary
  // controller belongs to the vertical scroll.
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.minWidth) return widget.child;
        return Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: widget.minWidth, child: widget.child),
          ),
        );
      },
    );
  }
}

/// A row of panels that sits side by side on a wide window and stacks, in the
/// same order and each full width, on a narrow one. Pass the same children
/// you would give a Row (Expanded panels and fixed-width spacers); on a narrow
/// window the Expanded wrappers and spacers are dropped.
class AdminResponsiveRow extends StatelessWidget {
  const AdminResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 720,
    this.gap = 16,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final double breakpoint;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          );
        }
        final stacked = <Widget>[
          for (final w in children)
            if (!(w is SizedBox && w.child == null && w.height == null))
              w is Expanded ? w.child : w,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stacked.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              stacked[i],
            ],
          ],
        );
      },
    );
  }
}

/// A white card that, when [onTap] is given, is a real button: it highlights
/// on hover and on keyboard focus, shows a pointer cursor, and activates with
/// Enter or Space as well as a click.
class AdminCardButton extends StatefulWidget {
  const AdminCardButton({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  State<AdminCardButton> createState() => _AdminCardButtonState();
}

class _AdminCardButtonState extends State<AdminCardButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final clickable = widget.onTap != null;
    final active = clickable && (_hovered || _focused);
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: active ? primary : Colors.grey.shade200,
        width: active ? 2 : 1,
      ),
      boxShadow: active
          ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
    final content = Padding(padding: widget.padding, child: widget.child);
    if (!clickable) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DecoratedBox(
          decoration: decoration,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onFocusChange: (f) => setState(() => _focused = f),
            hoverColor: Colors.transparent,
            focusColor: primary.withValues(alpha: 0.05),
            child: content,
          ),
        ),
      ),
    );
  }
}

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;
  final IconData icon;

  /// Makes the whole card a button (hover, focus and keyboard accessible).
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.change,
    this.changeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminCardButton(
      onTap: onTap,
      semanticLabel: onTap == null ? null : '$label: $value. Open.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              Icon(icon, color: theme.colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminAnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;

  /// Every analytics card is exactly this tall, whatever it shows (a card
  /// with no note under its number is the same size as one with a note).
  static const double height = 128;

  /// Makes the whole card a button to its related page (hover, focus and
  /// keyboard accessible).
  final VoidCallback? onTap;

  const AdminAnalyticsCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AdminCardButton(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        semanticLabel: onTap == null ? null : '$label: $value. Open.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (change != null) ...[
              const SizedBox(height: 4),
              Text(
                change!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: changeColor ?? Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
