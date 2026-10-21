import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../core/widgets/guest_gate_dialogs.dart';
import '../../camera/screens/ai_camera_screen.dart';
import '../../../core/photo_permission.dart';
import '../../../i18n/photo_strings.dart';
import '../../../services/image_compressor.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../data/healing_durations.dart';
import '../../../i18n/notification_strings.dart';
import '../../../i18n/journal_entry_strings.dart';
import '../../../i18n/pain_strings.dart';
import '../../../i18n/classification_strings.dart';
import '../../../i18n/app_language.dart';
import '../../../data/pain_assessment.dart';
import '../../../core/widgets/category_info_dialog.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../../i18n/nearby_strings.dart';
import '../../../core/widgets/pain_scale_dialog.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<XFile> _pickedImages = [];
  String? _classification;
  String? _severity; // for Injury: Deep / Minor
  bool _remindMe = false;
  // The date the entry is for (today unless the user picks another).
  DateTime _entryDate = DateUtils.dateOnly(DateTime.now());
  int? _painScore; // 0-5, required
  bool _isSaving = false;

  // The four existing categories. The key is what is saved (unchanged);
  // what is shown comes from JournalEntryStrings.
  static const List<(String, IconData)> _categories = [
    ('Injury (Wounds/laceration/Abrasion)', Icons.healing),
    ('Burns', Icons.local_fire_department_outlined),
    ('Skin Issues', Icons.back_hand_outlined),
    ('Scratch', Icons.gesture),
    ('Animal Scratch', Icons.pets),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGuestWarning());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<bool> _checkGuestWarning() async {
    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (!isGuest) return true; // not a guest, proceed normally

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text(
          'You are currently in Guest Mode. Notes and images entered here '
          'are temporary and will not be saved.\n\nPlease create a secure account.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue as Guest'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign up'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/registration');
      return false;
    }

    return true;
  }

  /// "Add Image": asks Take photo or Upload image, then (after the matching
  /// permission step) opens the in-app camera or the gallery.
  Future<void> _handleAddImage() async {
    final canProceed = await _checkGuestWarning();
    if (!canProceed) return;
    if (!mounted) return;

    final source = await _chooseSource();
    if (source == null || !mounted) return;
    await _addFrom(source);
  }

  Future<PhotoSource?> _chooseSource() {
    final s = PhotoStrings.of(context);
    return showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.takePhoto),
              onTap: () => Navigator.pop(sheetContext, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.uploadImage),
              onTap: () => Navigator.pop(sheetContext, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Gets one photo from [source] (permission step first) and shows its
  /// preview. With [replaceIndex] it replaces that photo (Retake) instead
  /// of adding a new one.
  Future<void> _addFrom(PhotoSource source, {int? replaceIndex}) async {
    final strings = PhotoStrings.of(context);
    if (!await ensurePhotoPermission(context, source)) return;
    if (!mounted) return;

    String? path;
    try {
      if (source == PhotoSource.camera) {
        // The in-app camera returns the photo's path when one is taken.
        path = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => const AiCameraScreen(captureOnly: true),
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
        ).showSnackBar(SnackBar(content: Text(strings.couldNotAddPhoto)));
      }
      return;
    }
    if (path == null || !mounted) return;

    final image = XFile(path);
    var index = 0;
    setState(() {
      if (replaceIndex != null && replaceIndex < _pickedImages.length) {
        _pickedImages[replaceIndex] = image;
        index = replaceIndex;
      } else {
        _pickedImages.add(image);
        index = _pickedImages.length - 1;
      }
    });
    await _showPreview(index, source: source);
  }

  /// Full-size preview of a picked photo with Retake / Remove. Shown right
  /// after a photo is taken or chosen, and when a thumbnail is tapped.
  Future<void> _showPreview(int index, {PhotoSource? source}) async {
    if (!mounted || index >= _pickedImages.length) return;
    final strings = PhotoStrings.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings.previewTitle),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_pickedImages[index].path),
            fit: BoxFit.contain,
            height: 320,
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'remove'),
            child: Text(strings.remove),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'retake'),
            child: Text(
              source == PhotoSource.gallery
                  ? strings.chooseAnother
                  : strings.retake,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'use'),
            child: Text(strings.usePhoto),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'remove':
        setState(() => _pickedImages.removeAt(index));
        break;
      case 'retake':
        // Same source when it is known (just taken / chosen), otherwise ask.
        final next = source ?? await _chooseSource();
        if (next != null && mounted) {
          await _addFrom(next, replaceIndex: index);
        }
        break;
      default:
        break; // use / dismissed: keep the photo
    }
  }

  bool get _isBackdated => !DateUtils.isSameDay(_entryDate, DateTime.now());

  // The chosen day with the current time of day (so entries on the same day
  // keep their order).
  DateTime _entryDateTime() {
    final now = DateTime.now();
    return DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
      now.hour,
      now.minute,
    );
  }

  // Today keeps the server's own timestamp (as before); another day is saved
  // as that day. Same field, same format.
  Object _createdAtValue() => _isBackdated
      ? Timestamp.fromDate(_entryDateTime())
      : FieldValue.serverTimestamp();

  Future<void> _pickEntryDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showAppDatePicker(
      context,
      initial: _entryDate,
      // Back up to a year, never a future date.
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _entryDate = picked);
  }

  Future<void> _handleSave() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await showGuestSaveGateDialog(context);
      return;
    }

    final strings = JournalEntryStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_titleController.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(strings.titleRequired)));
      return;
    }
    if (_classification == null) {
      messenger.showSnackBar(SnackBar(content: Text(strings.categoryRequired)));
      return;
    }
    if (_painScore == null) {
      messenger.showSnackBar(SnackBar(content: Text(strings.painRequired)));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload images to Firebase Storage
      final List<String> imageUrls = [];
      for (final image in _pickedImages) {
        try {
          final url = await StorageService().uploadJournalImage(
            image.path,
            'entry_${DateTime.now().millisecondsSinceEpoch}',
          );
          imageUrls.add(url);
        } catch (e) {
          debugPrint('Image upload failed: $e');
          // Continue with other images if one fails
        }
      }

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'classification': _classification,
            'severity': _severity,
            'painScore': _painScore,
            // Marks the 0-5 scale (older entries were rated 1-10).
            'painScaleMax': kPainMax,
            'remindMe': _remindMe,
            'imageUrls': imageUrls,
            'imageCount': _pickedImages.length,
            'createdAt': _createdAtValue(),
          })
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      // "Remind me": schedule the healing check-in from the standard healing
      // time of the chosen type. Types without a standard time get no
      // reminder (and the user is told) rather than an invented one.
      final noBenchmarkText = NotificationStrings.of(context).noBenchmark;
      var noBenchmark = false;
      if (_remindMe) {
        final healingDays = healingDurationDays[_classification];
        if (healingDays == null) {
          noBenchmark = true;
        } else {
          await NotificationService().ensureHealingReminderPermission(context);
          await NotificationService().scheduleHealingCheckIn(
            entryId: docRef.id,
            classification: _classification!,
            healingDays: healingDays,
            from: _isBackdated ? _entryDateTime() : null,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      if (noBenchmark) {
        messenger.showSnackBar(SnackBar(content: Text(noBenchmarkText)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.saveFailed)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Tapping a category opens its explanation; only Confirm selects it. For
  /// Injury, Confirm is followed by the required Deep / Minor choice. Closing
  /// either pop-up any other way selects nothing.
  Future<void> _onCategoryTap(String key) async {
    final strings = JournalEntryStrings.of(context);
    final tagalog = AppLanguageScope.isTagalog(context);
    final info = classificationInfoFor(key, tagalog: tagalog);

    final confirmed = await showCategoryInfoDialog(
      context,
      title: strings.categoryNames[key] ?? key,
      description: info?.what ?? '',
    );
    if (confirmed == null || !mounted) return;

    String? subType;
    if (key.startsWith('Injury')) {
      final choice = await showCategoryInfoDialog(
        context,
        title: strings.injuryTypeTitle,
        description: strings.injuryTypePrompt,
        options: [
          CategoryOption(
            value: 'Minor',
            title: strings.minor,
            description: info?.minorSigns ?? '',
          ),
          CategoryOption(
            value: 'Deep',
            title: strings.deep,
            description: info?.seriousSigns ?? '',
          ),
        ],
      );
      if (choice == null || !mounted) return;
      subType = choice.option;
    }

    setState(() {
      _classification = key;
      _severity = subType;
    });

    // An animal scratch needs a doctor: say so right away.
    if (key == 'Animal Scratch') await _showAnimalScratchNotice();
  }

  /// Urgent notice for an animal scratch (rabies, tetanus, infection risk),
  /// with a button to the nearby healthcare options.
  Future<void> _showAnimalScratchNotice() {
    final n = NearbyStrings.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 36,
        ),
        title: Text(n.animalTitle, textAlign: TextAlign.center),
        content: Text(n.animalBody),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          const NearbyHealthcareButton(compact: false),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(n.understood),
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, IconData? icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
  );

  Widget _categoryTile(
    ThemeData theme,
    JournalEntryStrings strings,
    String key,
    IconData icon,
  ) {
    final selected = _classification == key;
    final primary = theme.colorScheme.primary;
    final isInjury = key.startsWith('Injury');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onCategoryTap(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: primary.withValues(alpha: 0.15),
              child: Icon(icon, size: 18, color: primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.categoryNames[key] ?? key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isInjury)
                    Text(
                      strings.injurySubtitle,
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = JournalEntryStrings.of(context);
    final photo = PhotoStrings.of(context);
    final pain = PainStrings.of(context);
    final primary = theme.colorScheme.primary;
    final soft = primary.withValues(alpha: 0.15);
    final isGuest = FirebaseAuth.instance.currentUser == null;

    return Scaffold(
      body: Column(
        children: [
          // Header band with the single back arrow.
          Container(
            width: double.infinity,
            color: primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        strings.screenTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Add Image: a dashed box.
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _handleAddImage,
                    child: CustomPaint(
                      painter: _DashedBorderPainter(color: primary),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 64,
                                  color: primary.withValues(alpha: 0.6),
                                ),
                                Positioned(
                                  right: -10,
                                  bottom: -4,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: primary.withValues(
                                      alpha: 0.7,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              photo.addImage,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              strings.addImageSubtitle,
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_pickedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pickedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => _showPreview(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_pickedImages[index].path),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Title / date / how are you feeling.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(
                          theme,
                          Icons.description_outlined,
                          strings.titleLabel,
                        ),
                        TextField(
                          controller: _titleController,
                          decoration: _fieldDecoration(strings.titleHint),
                        ),
                        const SizedBox(height: 12),
                        _label(theme, null, strings.dateLabel),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickEntryDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    strings.formatDate(_entryDate),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label(theme, Icons.edit_note, strings.feelingLabel),
                        TextField(
                          controller: _descriptionController,
                          minLines: 7,
                          maxLines: 12,
                          decoration: _fieldDecoration(strings.feelingHint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category tiles.
                  Text(
                    strings.categoryHeading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var row = 0; row < _categories.length; row += 2) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = row; i < row + 2; i++) ...[
                            if (i > row) const SizedBox(width: 10),
                            Expanded(
                              child: i < _categories.length
                                  ? _categoryTile(
                                      theme,
                                      strings,
                                      _categories[i].$1,
                                      _categories[i].$2,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_classification != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        strings.selectedFormat.replaceFirst(
                          '{category}',
                          (strings.categoryNames[_classification] ??
                                  _classification!) +
                              (_severity == null
                                  ? ''
                                  : ' — ${strings.subTypeName(_severity)}'),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Pain rating 0-5, in the same card style as the pain dialog.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEEEC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pain.dialogTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(pain.dialogBody, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 12),
                        PainScaleSelector(
                          monochrome: true,
                          value: _painScore,
                          onChanged: (n) => setState(() => _painScore = n),
                        ),
                        if (_painScore != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            pain.rating(_painScore!).message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Guests get no notifications, so no reminder option.
                  if (!isGuest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: primary.withValues(alpha: 0.2),
                            child: Icon(
                              Icons.notifications_none,
                              size: 18,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  NotificationStrings.of(context).remindMeTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  NotificationStrings.of(
                                    context,
                                  ).remindMeSubtitle,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _remindMe,
                            onChanged: (v) => setState(() => _remindMe = v),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(strings.save),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(strings.cancel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, dashed outline for the Add Image box.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
