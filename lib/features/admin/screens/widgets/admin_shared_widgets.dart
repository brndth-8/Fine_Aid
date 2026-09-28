import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

/// Best-effort admin activity log write. Never throws — a logging failure
/// should not block the admin action that triggered it.
Future<void> logAdminAction(String action, {String type = 'UPDATE'}) async {
  try {
    await FirebaseFirestore.instance.collection('auditLogs').add({
      'action': action,
      'type': type,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Best-effort only.
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
  final text = (value ?? '').toString();
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

class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
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

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.change,
    this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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

  const AdminAnalyticsCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
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
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.normal,
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
