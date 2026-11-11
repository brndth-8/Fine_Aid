import 'package:flutter/material.dart';
import '../../../i18n/journal_edit_strings.dart';
import 'edit_entry_screen.dart';
import 'journal_list_screen.dart';

enum _EntryAction { edit, delete }

/// The three-dot menu on a journal entry: Edit and Delete. [onEdited] gets the
/// fields that were changed; [onDeleted] runs after the entry is gone. (The
/// lists read the entries live, so they update by themselves.)
class JournalEntryMenu extends StatelessWidget {
  final String entryId;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>>? onEdited;
  final VoidCallback? onDeleted;

  /// The three dots' colour: grey on a white card, white on the maroon bar.
  final Color? iconColor;

  const JournalEntryMenu({
    super.key,
    required this.entryId,
    required this.data,
    this.onEdited,
    this.onDeleted,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = JournalEditStrings.of(context);
    return PopupMenuButton<_EntryAction>(
      tooltip: s.menuTooltip,
      icon: Icon(Icons.more_vert, color: iconColor ?? Colors.grey.shade800),
      color: const Color(0xFFD9D9D9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) async {
        switch (action) {
          case _EntryAction.edit:
            final changes = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (_) => EditEntryScreen(entryId: entryId, data: data),
              ),
            );
            if (changes != null) onEdited?.call(changes);
          case _EntryAction.delete:
            final deleted = await JournalListScreen.confirmAndDeleteEntry(
              context,
              entryId,
            );
            if (deleted) onDeleted?.call();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _EntryAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(s.edit),
            ],
          ),
        ),
        PopupMenuItem(
          value: _EntryAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(s.delete),
            ],
          ),
        ),
      ],
    );
  }
}
