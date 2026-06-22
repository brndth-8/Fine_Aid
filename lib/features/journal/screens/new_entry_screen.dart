import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<XFile> _pickedImages = [];
  String? _classification;
  String? _severity; // for Injury: Deep / Minor
  bool _remindMe = false;
  bool _isSaving = false;

  final List<String> _classifications = [
    'Injury (Wounds/laceration/Abrasion)',
    'Burns',
    'Skin Issues',
    'Animal Bite/Scratch',
  ];

  // ─── NEW: initState with guest warning ───────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGuestWarning());
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── NEW: Guest warning dialog ───────────────────────────────────────────
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

    return true; // they chose "Continue as Guest"
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleAddImage() async {
    // ─── Guest check before image picker ─────────────────────────────────
    final canProceed = await _checkGuestWarning();
    if (!canProceed) return;
    // ─────────────────────────────────────────────────────────────────────

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text(
          'The image attached will be viewable to admin\'s module for review.\n\n'
          'Agree to continue?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (consent != true) return;

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedImages.add(image));
    }
  }

  Future<void> _handleSave() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a title.')));
      return;
    }
    if (_classification == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a classification.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      //Image upload to firebase storage is delayed until magupgrade ng blaze plan
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'classification': _classification,
            'severity': _severity,
            'remindMe': _remindMe,
            'imageUrls': <String>[], // populated once Storage is enabled
            'imageCount': _pickedImages.length,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save entry. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _classificationButton(ThemeData theme, String label) {
    final isSelected = _classification == label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => setState(() {
            _classification = label;
            if (!label.startsWith('Injury')) _severity = null;
          }),
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : null,
            foregroundColor: isSelected
                ? Colors.white
                : theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Health Journal',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _handleAddImage,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Image'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
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
                    itemBuilder: (context, index) => ClipRRect(
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
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'Add Title',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(),
                    Text(_formattedToday(), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'How are you feeling today?',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ..._classifications.map((c) => _classificationButton(theme, c)),
              if (_classification != null &&
                  _classification!.startsWith('Injury'))
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _severity = 'Deep'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _severity == 'Deep'
                                ? theme.colorScheme.primary
                                : null,
                            foregroundColor: _severity == 'Deep'
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                          child: const Text('Deep'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _severity = 'Minor'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _severity == 'Minor'
                                ? theme.colorScheme.primary
                                : null,
                            foregroundColor: _severity == 'Minor'
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                          child: const Text('Minor'),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: _remindMe,
                  onChanged: (value) =>
                      setState(() => _remindMe = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Remind Me',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'NOTIFY ME BASED ON STANDARD HEALING TIME',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
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
                    : const Text('Save Entry'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedToday() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}
