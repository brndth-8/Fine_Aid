import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/photo_permission.dart';
import '../../../i18n/journal_edit_strings.dart';
import '../../../services/guest_journal_store.dart';
import '../../../i18n/photo_strings.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../services/image_compressor.dart';
import '../../camera/screens/ai_camera_screen.dart';

/// Edit a saved journal entry: change its title and notes and add more photos
/// (to keep a visual progress log). Pops with the fields that changed (so the
/// entry screen can show them straight away), or null if nothing was saved.
class EditEntryScreen extends StatefulWidget {
  final String entryId;
  final Map<String, dynamic> data;

  const EditEntryScreen({super.key, required this.entryId, required this.data});

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.data['title'] as String? ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.data['description'] as String? ?? '',
  );
  late final List<String> _savedUrls =
      (widget.data['imageUrls'] as List?)?.cast<String>().toList() ?? [];
  // Photos added in this screen, uploaded when the changes are saved.
  final List<String> _newPaths = [];
  bool _isSaving = false;

  // A Guest Mode entry (kept on this phone).
  bool get _isLocal => widget.data['isLocal'] == true;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = PhotoStrings.of(context);
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(photo.takePhoto),
              onTap: () => Navigator.pop(sheetContext, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(photo.uploadImage),
              onTap: () => Navigator.pop(sheetContext, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    // The permission step first; nothing opens if it is denied.
    if (!await ensurePhotoPermission(context, source)) return;
    if (!mounted) return;

    String? path;
    try {
      if (source == PhotoSource.camera) {
        path = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const AiCameraScreen(captureOnly: true),
          ),
        );
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked != null) path = await compressImageFile(picked.path);
      }
    } catch (e) {
      debugPrint('Add photo failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(photo.couldNotAddPhoto)));
      }
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _newPaths.add(path!));
  }

  Future<void> _save() async {
    final s = JournalEditStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final title = _title.text.trim();
    if (title.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(s.titleRequired)));
      return;
    }
    if (_isSaving) return;
    // A Guest Mode entry is on this phone only: no photos, no reminders.
    if (_isLocal) {
      final description = _notes.text.trim();
      await GuestJournalStore.instance.update(
        widget.entryId,
        title: title,
        description: description,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.saved)));
      Navigator.pop(context, {'title': title, 'description': description});
      return;
    }
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      // Upload the new photos first; if any fails nothing is saved, so no
      // photo is silently lost.
      final urls = [..._savedUrls];
      for (final path in _newPaths) {
        urls.add(
          await StorageService().uploadJournalImage(path, widget.entryId),
        );
      }

      final changes = <String, dynamic>{
        'title': title,
        'description': _notes.text.trim(),
        'imageUrls': urls,
        'imageCount': urls.length,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(widget.entryId)
          .update({...changes, 'updatedAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));

      // Editing an entry sets its reminders again (counted from when it was
      // made); one that was already answered, or asked for none, stays as is.
      try {
        await NotificationService().rescheduleForEntry(
          entryId: widget.entryId,
          data: {...widget.data, ...changes},
        );
      } catch (e) {
        debugPrint('Could not reschedule the reminders: $e');
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.saved)));
      Navigator.pop(context, changes);
    } catch (e) {
      debugPrint('Edit entry failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed)));
    }
  }

  Widget _thumb(Widget image, {String? badge, VoidCallback? onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 90, height: 90, child: image),
        ),
        if (badge != null)
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = JournalEditStrings.of(context);
    final photo = PhotoStrings.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      s.editTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.titleLabel, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    Text(s.notesLabel, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notes,
                      minLines: 4,
                      maxLines: 10,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (!_isLocal) ...[
                      const SizedBox(height: 16),
                      Text(s.photosLabel, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        s.photosHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final url in _savedUrls)
                            _thumb(
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          for (final path in _newPaths)
                            _thumb(
                              Image.file(File(path), fit: BoxFit.cover),
                              badge: s.newPhoto,
                              onRemove: _isSaving
                                  ? null
                                  : () =>
                                        setState(() => _newPaths.remove(path)),
                            ),
                          InkWell(
                            onTap: _isSaving ? null : _addPhoto,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    photo.addImage,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(_isSaving ? s.saving : s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
