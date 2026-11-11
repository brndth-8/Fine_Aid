import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../core/network_error.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../i18n/journal_entry_strings.dart';
import '../../../i18n/guest_journal_strings.dart';
import '../../../services/guest_journal_store.dart';
import 'new_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'journal_entry_menu.dart';
import '../../../i18n/screen_text_strings.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  static Future<bool> confirmAndDeleteEntry(
    BuildContext context,
    String entryId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry'),
        content: Text(ScreenText.of(context).deleteEntryBody),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ScreenText.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(ScreenText.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final user = FirebaseAuth.instance.currentUser;
    // A guest's entries are on this phone only.
    if (user == null) {
      await GuestJournalStore.instance.remove(entryId);
      return true;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(entryId)
          .delete()
          .timeout(Duration(seconds: 10));
      await NotificationService().cancelHealingCheckIn(entryId);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ScreenText.of(context).couldNotDeleteEntry)),
        );
      }
      return false;
    }
  }

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  // Only entries between these two dates (inclusive) are shown; null = all.
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    // Guest Mode entries live on this phone.
    if (FirebaseAuth.instance.currentUser == null) {
      GuestJournalStore.instance.load();
    }
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showAppDateRangePicker(
      context,
      initial: _range,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final range = _range;
    if (range == null) return docs;
    return docs.where((doc) {
      final at = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (at == null) return false;
      final day = DateUtils.dateOnly(at);
      return !day.isBefore(range.start) && !day.isAfter(range.end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          ScreenText.of(context).journalBannerTitle,
          style: const TextStyle(fontWeight: FontWeight.normal),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              // The heading and the date filter take at most half the screen and
              // scroll when they are taller (large text), so the list below never
              // overflows.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // What the journal is for, under the top bar.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            ScreenText.of(context).journalBannerSubtitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      // Date-range filter.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickRange,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF303130),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.2,
                                  ),
                                  shape: const StadiumBorder(),
                                  textStyle: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.normal),
                                ),
                                icon: Icon(
                                  Icons.date_range_outlined,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                label: Text(
                                  _range == null
                                      ? JournalEntryStrings.of(
                                          context,
                                        ).filterByDate
                                      : '${formatDateInput(_range!.start)} – '
                                            '${formatDateInput(_range!.end)}',
                                ),
                              ),
                            ),
                            if (_range != null)
                              IconButton(
                                tooltip: JournalEntryStrings.of(
                                  context,
                                ).clearFilter,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _range = null),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: user == null
                    ? _guestList(theme)
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('journalEntries')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            // Never surface a raw exception (eg a bare
                            // SocketException when there's no cache yet to
                            // fall back on) — always a friendly message.
                            final error = snapshot.error;
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error != null && isNetworkError(error)
                                      ? noInternetMessage
                                      : 'Could not load your journal. '
                                            'Please try again.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final all = snapshot.data!.docs;
                          final docs = _filtered(all);
                          if (all.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  ScreenText.of(context).journalEmpty,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            );
                          }
                          if (docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  JournalEntryStrings.of(
                                    context,
                                  ).noEntriesInRange,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              return _entryCard(
                                context,
                                theme,
                                doc.id,
                                doc.data(),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewEntryScreen()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          ScreenText.of(context).addEntry,
          style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  /// Guest Mode: the entries kept on this phone, newest first.
  Widget _guestList(ThemeData theme) {
    return ValueListenableBuilder<List<GuestJournalEntry>>(
      valueListenable: GuestJournalStore.instance.entries,
      builder: (context, all, _) {
        final range = _range;
        final shown = range == null
            ? all
            : all.where((e) {
                final day = DateUtils.dateOnly(
                  (e.data['createdAt'] as Timestamp).toDate(),
                );
                return !day.isBefore(range.start) && !day.isAfter(range.end);
              }).toList();
        if (all.isEmpty || shown.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                all.isEmpty
                    ? ScreenText.of(context).journalEmpty
                    : JournalEntryStrings.of(context).noEntriesInRange,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          itemCount: shown.length,
          itemBuilder: (context, index) =>
              _entryCard(context, theme, shown[index].id, shown[index].data),
        );
      },
    );
  }

  Widget _entryCard(
    BuildContext context,
    ThemeData theme,
    String entryId,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final dateText = timestamp != null
        ? DateFormat('EEEE, MMMM d').format(timestamp.toDate())
        : '';
    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {
        debugPrint('Card tapped! entryId=$entryId');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EntryDetailScreen(entryId: entryId, data: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrls.isNotEmpty
                  ? Image.network(
                      imageUrls.first,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      // Offline (or a photo that is gone): a quiet placeholder,
                      // never an error message.
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.cloud_off_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 90,
                      height: 90,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (data['isLocal'] == true)
                    Text(
                      GuestJournalStrings.of(context).onThisDevice,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            JournalEntryMenu(entryId: entryId, data: data),
          ],
        ),
      ),
    );
  }
}
