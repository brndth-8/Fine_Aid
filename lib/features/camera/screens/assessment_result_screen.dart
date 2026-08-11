import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/api/gemini_service.dart';
import '../../chatbot/screens/chatbot_screen.dart';
import '../../../services/firebase/storage_service.dart';

class AssessmentResultScreen extends StatefulWidget {
  final String imagePath;

  const AssessmentResultScreen({super.key, required this.imagePath});

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  String? _analysisResult;
  bool _isAnalyzing = true;
  String? _error;
  String? _detectedClassification;
  bool _savedToJournal = false;
  bool _isSaving = false;
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    try {
      final result = await GeminiService().analyzeWoundImage(widget.imagePath);
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
          _detectedClassification = _detectClassification(result);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Analysis failed. Please try again.\nError: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  String? _detectClassification(String result) {
    final lower = result.toLowerCase();
    if (lower.contains('burn')) return 'Burns';
    if (lower.contains('laceration') ||
        lower.contains('cut') ||
        lower.contains('wound')) {
      return 'Injury (Wounds/laceration/Abrasion)';
    }
    if (lower.contains('animal') ||
        lower.contains('bite') ||
        lower.contains('scratch')) {
      return 'Animal Bite/Scratch';
    }
    if (lower.contains('skin') ||
        lower.contains('rash') ||
        lower.contains('irritation')) {
      return 'Skin Issues';
    }
    return null;
  }

  Future<void> _saveToJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // Upload image to Firebase Storage first
      String? imageUrl;
      try {
        imageUrl = await StorageService().uploadJournalImage(
          widget.imagePath,
          'ai_camera_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('Image upload failed: $e');
        // Continue saving even if image upload fails
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .add({
            'title': 'AI Camera Assessment',
            'description': _analysisResult ?? '',
            'classification':
                _detectedClassification ??
                'Injury (Wounds/laceration/Abrasion)',
            'severity': null,
            'remindMe': false,
            'imageUrls': imageUrl != null ? [imageUrl] : <String>[],
            'imageCount': 1,
            'source': 'ai_camera',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _savedToJournal = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment saved to Health Journal.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save to journal. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _buildFormattedResult(ThemeData theme) {
    if (_analysisResult == null) return const SizedBox.shrink();

    final lines = _analysisResult!.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final cleaned = trimmed
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('##', '')
          .trim();

      if (cleaned.isEmpty) continue;

      final isHeader =
          RegExp(r'^[A-Z][A-Z\s]+:').hasMatch(cleaned) ||
          (trimmed.startsWith('**') && trimmed.endsWith('**'));

      if (isHeader) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              cleaned,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        continue;
      }

      // Numbered steps
      if (RegExp(r'^\d+\.').hasMatch(cleaned)) {
        final dotIndex = cleaned.indexOf('.');
        final number = cleaned.substring(0, dotIndex + 1);
        final content = cleaned.substring(dotIndex + 1).trim();

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Text(content, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet points
      if (cleaned.startsWith('•') || cleaned.startsWith('-')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    cleaned.replaceFirst(RegExp(r'^[•\-]\s*'), ''),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular text
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(cleaned, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildAnalyzingState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text('Analyzing wound...', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Our AI is examining the image.\nThis typically takes 5-15 seconds.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: Ensure the wound is well-lit and clearly '
                  'visible for the most accurate assessment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          'Analysis failed',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Something went wrong. Please try again.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isAnalyzing = true;
              _error = null;
              _analysisResult = null;
              _detectedClassification = null;
            });
            _analyzeImage();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'AI Vision Camera',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Disclaimer banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For initial assessment only. '
                        'Not a diagnostic tool. Seek professional help.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Captured image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(widget.imagePath),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Classification badge
            if (_detectedClassification != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Detected: $_detectedClassification',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_detectedClassification != null) const SizedBox(height: 8),

            // Result area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isAnalyzing
                      ? _buildAnalyzingState(theme)
                      : _error != null
                      ? _buildErrorState(theme)
                      : SingleChildScrollView(
                          child: _buildFormattedResult(theme),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Save to Journal button
            if (!_isAnalyzing && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _savedToJournal
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Saved to Health Journal',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveToJournal,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save to Health Journal',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
              ),
            const SizedBox(height: 8),

            // Chat input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _chatController,
                          decoration: const InputDecoration(
                            hintText: 'Describe your concern...',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (text) {
                            if (text.trim().isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChatbotScreen(initialContext: text.trim()),
                              ),
                            );
                            _chatController.clear();
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: theme.colorScheme.primary),
                      onPressed: () {
                        final text = _chatController.text.trim();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatbotScreen(
                              initialContext: text.isEmpty
                                  ? _analysisResult
                                  : text,
                            ),
                          ),
                        );
                        _chatController.clear();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
