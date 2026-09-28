import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api/gemini_service.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../services/firebase/first_aid_content_service.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/voice_input_service.dart';
import '../../../services/health_profile_service.dart';
import '../../../data/healing_durations.dart';
import '../../../data/health_profile_cautions.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../../core/widgets/voice_message_bubble.dart';
import '../../../core/widgets/otc_suggestions_block.dart';
import '../../../core/follow_up_fallback.dart';
import '../../dashboard/first_aid_kit_screen.dart';

class _FollowUpMessage {
  final String text;
  final String? tagalog;
  final bool isUser;
  final bool suggestNearby;
  final bool isUrgent;
  final List<String> otcSuggestions;
  // Set only for a voice follow-up question — the recorded clip's local
  // file path, so it can be replayed as a chat bubble. `text` is always the
  // transcript either way.
  final String? audioPath;
  _FollowUpMessage({
    required this.text,
    this.tagalog,
    required this.isUser,
    this.suggestNearby = false,
    this.isUrgent = false,
    this.otcSuggestions = const [],
    this.audioPath,
  });

  Map<String, dynamic> toJournalMap() => {
    'role': isUser ? 'user' : 'assistant',
    'text': text,
  };
}

// Staged, controlled progress for the analyzing screen. This does not
// reflect real-time completion (the AI call can't report that) — it's a
// deliberately staged indicator so the user isn't shown a spinner with no
// sense of progress, without pretending to know exact completion percent.
const List<(String, double)> _analysisStages = [
  ('Uploading image...', 0.12),
  ('Detecting wound...', 0.32),
  ('Classifying wound...', 0.52),
  ('Evaluating visible characteristics...', 0.72),
  ('Preparing first aid recommendations...', 0.86),
  ('Preparing results...', 0.95),
];

class AssessmentResultScreen extends StatefulWidget {
  final String imagePath;
  final List<String> woundHints;
  // Set only when opened from the multi-injury results screen for one
  // specific injury the batch call already analyzed — skips this screen's
  // own analyzeWoundV2() call and shows this result directly, since
  // re-running a single-wound analysis on a multi-injury photo would just
  // pick one wound at random rather than the one the user actually tapped.
  final WoundAssessment? precomputedAssessment;
  // Shown alongside the title when set (eg "Injury 2 of 3 — left knee"),
  // so it's clear this is one part of a multi-injury session.
  final String? injuryContextLabel;

  const AssessmentResultScreen({
    super.key,
    required this.imagePath,
    this.woundHints = const [],
    this.precomputedAssessment,
    this.injuryContextLabel,
  });

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  WoundAssessment? _assessment;
  bool _isAnalyzing = true;
  String? _error;
  bool _errorIsOffline = false;
  bool _savedToJournal = false;
  bool _isSaving = false;
  bool _showTagalog = false;
  List<String>? _tagalogSteps;
  bool _isLoadingTagalog = false;
  bool _tagalogTranslationFailed = false;
  final TextEditingController _chatController = TextEditingController();

  List<FirstAidChunk> _otcSuggestions = [];
  bool _isLoadingOtc = false;
  List<String> _healthCautions = [];

  final List<_FollowUpMessage> _followUpMessages = [];
  bool _isSendingFollowUp = false;

  // Journal sync state: once saved, further follow-up messages mark the
  // saved entry as stale so the user can sync them in rather than
  // creating a duplicate entry.
  String? _savedJournalEntryId;
  bool _hasUnsavedFollowUps = false;

  Timer? _analyzingTimer;
  int _analyzingStage = 0;
  // True for the brief moment after the analysis returns, while the
  // progress bar animates the rest of the way to 100% before results show.
  bool _analysisFinishing = false;

  final VoiceInputService _voiceInput = VoiceInputService();
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  double _recordingLevel = 0;
  Timer? _recordingTimer;
  StreamSubscription<double>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
    _loadHealthCautions();
  }

  Future<void> _loadHealthCautions() async {
    final profile = await HealthProfileService().getHealthProfile();
    if (!mounted) return;
    final cautions = healthProfileCautions(profile);
    if (cautions.isNotEmpty) setState(() => _healthCautions = cautions);
  }

  @override
  void dispose() {
    _analyzingTimer?.cancel();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _voiceInput.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _startAnalyzingTimer() {
    _analyzingTimer?.cancel();
    _analyzingStage = 0;
    _analyzingTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) return;
      if (_analyzingStage < _analysisStages.length - 1) {
        setState(() => _analyzingStage++);
      }
    });
  }

  Future<void> _analyzeImage() async {
    // Start this wound's follow-up conversation clean — the chat model
    // keeps a persistent multi-turn session, and we don't want an
    // unrelated earlier wound's conversation bleeding into this one.
    GeminiService().resetChat();

    final precomputed = widget.precomputedAssessment;
    if (precomputed != null) {
      setState(() {
        _assessment = precomputed;
        _tagalogSteps = null;
        _isAnalyzing = false;
      });
      _loadOtcSuggestions();
      return;
    }

    _startAnalyzingTimer();

    final online = await ConnectivityService().isOnline;
    if (!online) {
      _analyzingTimer?.cancel();
      if (mounted) {
        setState(() {
          _error =
              'No internet connection. Please check your connection '
              'and try again.';
          _errorIsOffline = true;
          _isAnalyzing = false;
        });
      }
      return;
    }

    try {
      final hintQuery = widget.woundHints.isNotEmpty
          ? widget.woundHints.join(' ')
          : 'wound skin injury first aid care';
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(hintQuery);

      final assessment = await GeminiService().analyzeWoundV2(
        widget.imagePath,
        referenceContext: referenceContext,
      );
      _analyzingTimer?.cancel();
      if (mounted) {
        // Let the bar visibly reach 100% before swapping in the results.
        setState(() => _analysisFinishing = true);
        await Future.delayed(const Duration(milliseconds: 450));
      }
      if (mounted) {
        setState(() {
          _analysisFinishing = false;
          _assessment = assessment;
          _tagalogSteps = null;
          _isAnalyzing = false;
        });
        _loadOtcSuggestions();
      }
    } catch (e) {
      _analyzingTimer?.cancel();
      if (mounted) {
        final offline =
            e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('network');
        setState(() {
          _error = offline
              ? 'No internet connection. Please check your connection and '
                    'try again.'
              : 'Analysis failed. Please try again.';
          _errorIsOffline = offline;
          _isAnalyzing = false;
        });
      }
    }
  }

  String _otcQueryForCategory(String category, List<String> otcOptions) {
    // Deliberately specific, condition-matched terms rather than generic
    // words like "pain" or "relief" alone — those matched unrelated
    // products (an antacid, a cough lozenge) that happened to share one
    // generic keyword. FirstAidContentService now also requires 2+
    // overlapping keywords by default, so precise phrasing here matters.
    // The model's own otc_options are folded in as extra search terms,
    // not shown directly as if they were verified local products.
    final base = switch (category) {
      WoundCategories.burn =>
        'burn wound antiseptic burn ointment silver sulfadiazine '
            'antipyretic paracetamol ibuprofen',
      WoundCategories.laceration || WoundCategories.punctureWound =>
        'wound antiseptic povidone iodine betadine antibiotic ointment '
            'gauze dressing tetanus',
      WoundCategories.minorCut ||
      WoundCategories.abrasion ||
      WoundCategories.scratch =>
        'wound antiseptic povidone iodine betadine antibiotic ointment '
            'bandage dressing infection disinfectant',
      WoundCategories.rash =>
        'antihistamine antipruritic anti-itch calamine rash topical skin '
            'antifungal hydrocortisone',
      WoundCategories.bruise || WoundCategories.swelling =>
        'anti-inflammatory analgesic gel diclofenac ibuprofen topical '
            'swelling bruise muscle pain',
      _ => 'antiseptic wound care topical ointment',
    };
    return otcOptions.isEmpty ? base : '$base ${otcOptions.join(' ')}';
  }

  Future<void> _loadOtcSuggestions() async {
    final assessment = _assessment;
    if (assessment == null) return;
    setState(() => _isLoadingOtc = true);
    try {
      final query = _otcQueryForCategory(
        assessment.category,
        assessment.otcOptions,
      );
      final results = await FirstAidContentService().searchOtcMedications(
        query,
        limit: 8,
      );
      if (mounted) {
        setState(() {
          _otcSuggestions = results;
          _isLoadingOtc = false;
        });
      }
    } catch (e) {
      debugPrint('OTC suggestions error: $e');
      if (mounted) setState(() => _isLoadingOtc = false);
    }
  }

  Future<void> _toggleTagalog() async {
    if (_showTagalog) {
      setState(() => _showTagalog = false);
      return;
    }
    final assessment = _assessment;
    if (assessment == null) return;

    if (_tagalogSteps == null && !_isLoadingTagalog) {
      setState(() {
        _isLoadingTagalog = true;
        _tagalogTranslationFailed = false;
      });
      final translated = await GeminiService().translateToTagalog(
        assessment.firstAidSteps,
      );
      if (!mounted) return;
      setState(() {
        _tagalogSteps = translated.isNotEmpty ? translated : null;
        _isLoadingTagalog = false;
        _tagalogTranslationFailed = translated.isEmpty;
      });

      // Translation genuinely failed (network hiccup, timeout, a malformed
      // reply) — stay in English rather than flipping the toggle to "Show
      // English" while silently still showing English steps underneath
      // (the original bug). No popup, but a small inline note appears next
      // to the button so it's clear something didn't work, instead of the
      // button just appearing to do nothing when tapped.
      if (translated.isEmpty) return;
    }
    if (mounted) setState(() => _showTagalog = true);
  }

  /// The first message the user typed (before any assistant reply) is
  /// saved as the standalone "user concern" field; the full exchange
  /// (including that same message) is saved as the structured follow-up
  /// conversation so it can be displayed as a thread later.
  String? get _userConcern {
    for (final m in _followUpMessages) {
      if (m.isUser) return m.text;
    }
    return null;
  }

  String _synthesizeDescription(WoundAssessment a) {
    final buffer = StringBuffer();
    buffer.writeln('Wound type: ${a.woundType}');
    buffer.writeln('Triage: ${a.triage.name}');
    if (a.firstAidSteps.isNotEmpty) {
      buffer.writeln('\nFIRST AID STEPS:');
      for (var i = 0; i < a.firstAidSteps.length; i++) {
        buffer.writeln('${i + 1}. ${a.firstAidSteps[i]}');
      }
    }
    if (a.redFlags.isNotEmpty) {
      buffer.writeln('\nRED FLAGS:');
      for (final f in a.redFlags) {
        buffer.writeln('- $f');
      }
    }
    return buffer.toString().trim();
  }

  Future<void> _saveToJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    final assessment = _assessment;
    if (user == null || assessment == null) return;

    setState(() => _isSaving = true);

    try {
      final journalData = <String, dynamic>{
        'title': 'AI Camera Assessment',
        'description': _synthesizeDescription(assessment),
        'aiObservations': _synthesizeDescription(assessment),
        // The saved classification always matches what this same
        // analysis reported — never a guessed/generic category — so
        // the Health Journal's healing-timeframe estimate stays
        // consistent with what the AI Scanner actually recognized.
        'classification': assessment.category,
        'category': assessment.category,
        'firstAidSteps': assessment.firstAidSteps,
        'warningSigns': assessment.redFlags,
        'triage': assessment.triage.name,
        'visibleBleeding': assessment.visibleBleeding,
        'apparentDepth': assessment.apparentDepth,
        'needsProfessionalEvaluation': assessment.needsProfessionalEvaluation,
        'otcSuggestions': _otcSuggestions
            .map((c) => {'title': c.title, 'content': c.content})
            .toList(),
        'userConcern': _userConcern,
        'followUpConversation': _followUpMessages
            .map((m) => m.toJournalMap())
            .toList(),
        'severity': null,
        'remindMe': false,
        'imageCount': 1,
        'source': 'ai_camera',
      };

      if (_savedJournalEntryId == null) {
        // First save for this wound — upload the image once.
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
        journalData['imageUrls'] = imageUrl != null ? [imageUrl] : <String>[];
        journalData['createdAt'] = FieldValue.serverTimestamp();

        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journalEntries')
            .add(journalData)
            .timeout(const Duration(seconds: 10));

        final healingDays = healingDurationDays[assessment.category];
        if (healingDays != null) {
          NotificationService().scheduleHealingCheckIn(
            entryId: docRef.id,
            classification: assessment.category,
            scheduledDate: DateTime.now().add(Duration(days: healingDays)),
          );
        }

        if (mounted) {
          setState(() {
            _savedToJournal = true;
            _savedJournalEntryId = docRef.id;
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assessment saved to Health Journal.'),
            ),
          );
        }
      } else {
        // Already saved — sync the (now longer) conversation into the
        // same entry rather than creating a duplicate.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journalEntries')
            .doc(_savedJournalEntryId)
            .update({
              'userConcern': journalData['userConcern'],
              'followUpConversation': journalData['followUpConversation'],
            })
            .timeout(const Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Journal entry updated.')),
          );
        }
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

  IconData _iconForStepText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('wash') ||
        lower.contains('rinse') ||
        lower.contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (lower.contains('bandage') ||
        lower.contains('dressing') ||
        lower.contains('cover') ||
        lower.contains('gauze')) {
      return Icons.healing_outlined;
    }
    if (lower.contains('pressure') || lower.contains('press')) {
      return Icons.back_hand_outlined;
    }
    if (lower.contains('ice') ||
        lower.contains('cold') ||
        lower.contains('cool')) {
      return Icons.ac_unit_outlined;
    }
    if (lower.contains('call') ||
        lower.contains('911') ||
        lower.contains('emergency') ||
        lower.contains('hospital') ||
        lower.contains('doctor') ||
        lower.contains('medical help')) {
      return Icons.local_hospital_outlined;
    }
    if (lower.contains('elevate') ||
        lower.contains('raise') ||
        lower.contains('lift')) {
      return Icons.arrow_upward;
    }
    if (lower.contains('rest') ||
        lower.contains('immobil') ||
        lower.contains('splint') ||
        lower.contains('still')) {
      return Icons.accessibility_new_outlined;
    }
    if (lower.contains('ointment') ||
        lower.contains('cream') ||
        lower.contains('apply') ||
        lower.contains('medicine') ||
        lower.contains('medication')) {
      return Icons.medication_outlined;
    }
    if (lower.contains('remove')) {
      return Icons.remove_circle_outline;
    }
    if (lower.contains('avoid') ||
        lower.contains('do not') ||
        lower.contains("don't")) {
      return Icons.block_outlined;
    }
    return Icons.check_circle_outline;
  }

  String? _extractField(String content, String label) {
    final match = RegExp('$label:\\s*(.+)').firstMatch(content);
    return match?.group(1)?.trim();
  }

  /// The triage banner's text, or null when no banner is shown.
  String? _triageBannerTitle(WoundAssessment a) {
    final urgent =
        a.triage == TriageLevel.emergency || a.triage == TriageLevel.urgentCare;
    if (!urgent && !a.needsProfessionalEvaluation) return null;
    if (a.triage == TriageLevel.emergency) {
      return 'Seek Emergency Care Immediately';
    }
    return urgent
        ? 'Seek Urgent Medical Care'
        : 'Professional Evaluation Recommended';
  }

  /// Round button matching the send button, sitting next to it in the
  /// "Describe your concern" bar.
  Widget _buildRoundInputButton(
    ThemeData theme, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Mic and send buttons side by side in the "Describe your concern" bar.
  Widget _buildVoiceOrSendButton(ThemeData theme) {
    final hasText = _chatController.text.trim().isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoundInputButton(
          theme,
          icon: Icons.mic,
          tooltip: 'Record a follow-up question',
          onPressed: _isSendingFollowUp ? null : _startVoiceRecording,
        ),
        const SizedBox(width: 6),
        _buildRoundInputButton(
          theme,
          icon: Icons.send_rounded,
          tooltip: 'Send',
          onPressed: (_isSendingFollowUp || !hasText)
              ? null
              : () => _handleFollowUpSend(),
        ),
      ],
    );
  }

  /// Short cautions derived from the user's onboarding Health Profile
  /// (diabetes, bleeding disorders, severe allergies) — an additive nudge
  /// alongside the AI's own assessment, not a replacement for it.
  Widget _buildHealthCautionBox(ThemeData theme) {
    if (_healthCautions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on Your Health Profile',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ..._healthCautions.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  c,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Philippines' unified national emergency hotline.
  static const String _emergencyPhoneNumber = '911';

  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: _emergencyPhoneNumber);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the dialer. Please call 911 directly.',
          ),
        ),
      );
    }
  }

  Widget _buildTriageBanner(ThemeData theme, WoundAssessment a) {
    if (_triageBannerTitle(a) == null) return const SizedBox.shrink();

    final isEmergency = a.triage == TriageLevel.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    final title = _triageBannerTitle(a)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Emergency-level only — urgent-but-not-emergency and the
            // "professional evaluation recommended" case are real but not
            // immediately life-threatening, so a direct dial-out CTA isn't
            // warranted there; the banner text alone already tells the
            // user to seek care.
            if (isEmergency) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _callEmergencyServices,
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call Emergency Services (911)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentResult(ThemeData theme, WoundAssessment a) {
    final steps = _showTagalog && _tagalogSteps != null
        ? _tagalogSteps!
        : a.firstAidSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTriageBanner(theme, a),
        _buildHealthCautionBox(theme),
        if (a.firstAidSteps.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'First Aid Steps',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _isLoadingTagalog ? null : _toggleTagalog,
                icon: _isLoadingTagalog
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate, size: 16),
                label: Text(
                  _showTagalog ? 'Show English' : 'Translate to Tagalog',
                  style: theme.textTheme.bodySmall,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (_tagalogTranslationFailed)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Couldn't translate right now — tap Translate to Tagalog "
                'to try again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconForStepText(entry.value),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (a.uncertainties.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Some details were unclear from this photo: '
            '${a.uncertainties.join('; ')}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This is an AI-generated preliminary assessment, not '
                      'a medical diagnosis. Always use your own judgment '
                      'and seek professional care when in doubt.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState(ThemeData theme) {
    final stage = _analysisStages[_analyzingStage];
    final label = _analysisFinishing ? 'Done!' : stage.$1;
    final target = _analysisFinishing ? 1.0 : stage.$2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Analyzing your wound...', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        // Animates smoothly between stage targets instead of jumping, so
        // the bar always looks like it's actively filling.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: Duration(milliseconds: _analysisFinishing ? 350 : 1200),
          curve: Curves.easeOut,
          builder: (context, value, _) => Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.15,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$label  ${(value * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _errorIsOffline ? Icons.wifi_off : Icons.error_outline,
          color: _errorIsOffline ? Colors.grey : Colors.red,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _errorIsOffline ? 'No Internet Connection' : 'Analysis Failed',
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
              _errorIsOffline = false;
              _assessment = null;
              _otcSuggestions = [];
            });
            _analyzeImage();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const FirstAidKitScreen(),
              ),
            );
          },
          icon: const Icon(Icons.medical_services_outlined),
          label: const Text('Use Offline First Aid Health Kit'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildOtcCard(ThemeData theme, FirstAidChunk item) {
    final indication = _extractField(item.content, 'Indications');
    return GestureDetector(
      onTap: () => _showOtcDetails(item),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                indication ?? 'Tap for details',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Text(
              'Non-Rx',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtcSuggestions(ThemeData theme) {
    if (_otcSuggestions.isEmpty && !_isLoadingOtc) {
      return const SizedBox.shrink();
    }
    if (_otcSuggestions.isEmpty && _isLoadingOtc) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Looking up related OTC products…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.local_pharmacy_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Suggested OTC Products',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _otcSuggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildOtcCard(theme, _otcSuggestions[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              'These are general suggestions, not a prescription. Ask a '
              'pharmacist before taking any medication.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOtcDetails(FirstAidChunk item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Non-prescription (OTC)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(item.content, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(
                    'This is general product information, not a '
                    'recommendation. Ask a pharmacist or doctor before '
                    'taking any medication.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleFollowUpSend([
    String? textOverride,
    String? audioPath,
  ]) async {
    final text = (textOverride ?? _chatController.text).trim();
    if (text.isEmpty || _isSendingFollowUp) return;

    setState(() {
      _followUpMessages.add(
        _FollowUpMessage(text: text, isUser: true, audioPath: audioPath),
      );
      _isSendingFollowUp = true;
    });
    _chatController.clear();

    String english;
    String? tagalog;
    bool suggestNearby = false;
    bool isUrgent = false;
    List<String> otcSuggestions = const [];
    try {
      final category = _assessment?.category;
      // Include the wound's category in the retrieval query so follow-up
      // questions about THIS wound (which may not share vocabulary with
      // the reference books) still surface relevant chunks.
      final contextualQuery = [?category, text].join(' ');
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(contextualQuery)
          .timeout(const Duration(seconds: 15));
      final raw = await GeminiService()
          .sendChatMessage(
            text,
            referenceContext: referenceContext,
            woundContext: _assessment != null
                ? _synthesizeDescription(_assessment!)
                : null,
          )
          .timeout(const Duration(seconds: 20));
      final parsed = parseBilingualReply(raw);
      english = parsed.english.trim().isNotEmpty
          ? parsed.english
          : randomFollowUpFallbackMessage();
      tagalog = parsed.tagalog;
      suggestNearby = parsed.suggestNearby;
      isUrgent = parsed.isUrgent;
      otcSuggestions = parsed.otcSuggestions;
    } catch (e, st) {
      logFollowUpError('AssessmentResult', e, st);
      english = randomFollowUpFallbackMessage();
    }

    if (!mounted) return;
    setState(() {
      _followUpMessages.add(
        _FollowUpMessage(
          text: english,
          tagalog: tagalog,
          isUser: false,
          suggestNearby: suggestNearby,
          isUrgent: isUrgent,
          otcSuggestions: otcSuggestions,
        ),
      );
      _isSendingFollowUp = false;
      if (_savedJournalEntryId != null) _hasUnsavedFollowUps = true;
    });
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startVoiceRecording() async {
    if (_isSendingFollowUp || _isRecording) return;

    final available = await _voiceInput.isAvailable;
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "I couldn't access speech recognition on this device — check "
            'that microphone permission is allowed, or type your question '
            'instead.',
          ),
        ),
      );
      return;
    }

    await _voiceInput.start();
    if (!mounted) return;
    _amplitudeSubscription = _voiceInput.amplitudeStream().listen((level) {
      if (mounted) setState(() => _recordingLevel = level);
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      }
    });
    setState(() {
      _isRecording = true;
      _recordingElapsed = Duration.zero;
    });
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    await _voiceInput.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingElapsed = Duration.zero;
      _recordingLevel = 0;
    });
  }

  Future<void> _finishVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    final result = await _voiceInput.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingElapsed = Duration.zero;
      _recordingLevel = 0;
    });

    if (result.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.audioPath == null
                ? "I couldn't record that — check microphone permission "
                      'and try again, or type your question instead.'
                : "I recorded that, but couldn't make out the words — try "
                      'again, speak a bit closer to the mic, or type your '
                      'question instead.',
          ),
        ),
      );
      return;
    }

    await _handleFollowUpSend(result.transcript, result.audioPath);
  }

  Future<void> _handleFindNearbyHealthcare() async {
    showNearbyHealthcareSheet(context);
  }

  // "Find Nearby Healthcare" only makes sense to surface proactively for
  // conditions serious enough to warrant it — the same emergency/urgent
  // classification that already drives the red/orange triage banner.
  bool get _isSevereAssessment {
    final triage = _assessment?.triage;
    return triage == TriageLevel.emergency || triage == TriageLevel.urgentCare;
  }

  Widget _buildFollowUpSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask a follow-up question',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ..._followUpMessages.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: m.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: m.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? theme.colorScheme.primary
                          : m.isUrgent
                          ? Colors.red.shade50
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: (!m.isUser && m.isUrgent)
                          ? Border.all(color: Colors.red.shade300)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.audioPath != null) ...[
                          VoiceMessageBubble(
                            audioPath: m.audioPath!,
                            isUser: m.isUser,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                (!m.isUser && _showTagalog && m.tagalog != null)
                                    ? m.tagalog!
                                    : m.text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: m.isUser
                                      ? Colors.white
                                      : m.isUrgent
                                      ? Colors.red.shade700
                                      : null,
                                  fontWeight: (!m.isUser && m.isUrgent)
                                      ? FontWeight.bold
                                      : null,
                                  fontStyle: m.audioPath != null
                                      ? FontStyle.italic
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!m.isUser && m.otcSuggestions.isNotEmpty)
                          OtcSuggestionsBlock(suggestions: m.otcSuggestions),
                      ],
                    ),
                  ),
                ),
                if (!m.isUser && m.suggestNearby && _isSevereAssessment)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      onPressed: _handleFindNearbyHealthcare,
                      icon: const Icon(Icons.local_hospital_outlined, size: 16),
                      label: const Text('Find Nearby Healthcare'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isSendingFollowUp)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        _buildFollowUpInputBar(theme),
      ],
    );
  }

  Widget _buildFollowUpInputBar(ThemeData theme) {
    // Breaks out of the screen's 16px side padding to sit flush against
    // both edges — Container.margin can't go negative (it asserts
    // non-negative), so this widens the box to full screen width and
    // shifts it left by the same 16px instead.
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isRecording) {
      return Container(
        width: screenWidth,
        transform: Matrix4.translationValues(-16, 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: 'Cancel recording',
              onPressed: _cancelVoiceRecording,
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 0.85 + _recordingLevel * 0.45),
              duration: const Duration(milliseconds: 150),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Listening… ${_formatElapsed(_recordingElapsed)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: theme.colorScheme.primary),
              tooltip: 'Stop and send',
              onPressed: _finishVoiceRecording,
            ),
          ],
        ),
      );
    }

    return Container(
      width: screenWidth,
      transform: Matrix4.translationValues(-16, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: 'Describe your concern...',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleFollowUpSend(),
            ),
          ),
          _buildVoiceOrSendButton(theme),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(ThemeData theme, String category) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              'Category: $category',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessment = _assessment;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar (fixed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AI Vision Camera',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (widget.injuryContextLabel != null)
                          Text(
                            widget.injuryContextLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Everything else scrolls, so this screen can never overflow
            // regardless of screen size or how much content is shown.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Disclaimer banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'For initial assessment only. '
                        'Not a diagnostic tool. Seek professional help.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Captured image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(widget.imagePath),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (!_isAnalyzing &&
                        _error == null &&
                        assessment != null) ...[
                      _buildCategoryBadge(theme, assessment.category),
                      const SizedBox(height: 8),
                    ],

                    // Result area — natural height (min 220), not Expanded,
                    // so it never fights the outer scroll view for space.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 220),
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
                            : assessment == null
                            ? const SizedBox.shrink()
                            : _buildAssessmentResult(theme, assessment),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Suggested OTC products
                    if (!_isAnalyzing && _error == null)
                      _buildOtcSuggestions(theme),

                    // Save to Journal button
                    if (!_isAnalyzing && _error == null) ...[
                      if (_savedToJournal && !_hasUnsavedFollowUps)
                        Container(
                          width: double.infinity,
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
                      else
                        ElevatedButton.icon(
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
                              : Icon(
                                  _hasUnsavedFollowUps
                                      ? Icons.sync
                                      : Icons.save_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : _hasUnsavedFollowUps
                                ? 'Update Journal Entry'
                                : 'Save to Health Journal',
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),

                    // Follow-up question stays on this screen, in context.
                    if (!_isAnalyzing && _error == null)
                      _buildFollowUpSection(theme),
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
