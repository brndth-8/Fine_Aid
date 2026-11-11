import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api/gemini_service.dart';
import '../../../core/reminder_message.dart';
import '../../../i18n/notification_strings.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../services/firebase/first_aid_content_service.dart';
import '../../../services/ai_scan_stats_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/health_profile_service.dart';
import '../../../services/otc_filter_service.dart';
import '../../../core/widgets/health_profile_box.dart';
import 'ai_camera_screen.dart';
import '../../../data/health_context.dart';
import '../../../i18n/checklist_strings.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../../core/widgets/otc_suggestions_block.dart';
import '../../../core/widgets/assessment_questions.dart';
import '../../../i18n/ai_scan_stats_strings.dart';
import '../../../i18n/assessment_strings.dart';
import '../../../core/widgets/first_aid_step_list.dart';
import '../../../core/severe_case.dart';
import '../../../data/health_profile_summary.dart';
import '../../../i18n/health_kit_locale.dart';
import '../../../i18n/health_kit_ui_strings.dart';
import '../../../i18n/severe_strings.dart';
import '../../../core/widgets/icon_popup.dart';
import '../../../services/emergency_alert.dart';
import '../../../core/widgets/classification_info_button.dart';
import '../../../data/pain_assessment.dart';
import '../../../i18n/pain_strings.dart';
import '../../../core/widgets/guest_gate_dialogs.dart';
import '../../../core/widgets/guest_usage_badge.dart';
import '../../../services/guest_usage_service.dart';
import '../../../core/network_error.dart';
import '../../../core/follow_up_fallback.dart';
import '../../../core/display_formatters.dart';
import '../../../core/scope_check.dart';
import '../../dashboard/first_aid_kit_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../i18n/app_language.dart';
import '../../../i18n/screen_text_strings.dart';

class _FollowUpMessage {
  final String text;
  final String? tagalog;
  final bool isUser;
  final bool suggestNearby;
  final bool isUrgent;
  final List<OtcSuggestion> otcSuggestions;
  _FollowUpMessage({
    required this.text,
    this.tagalog,
    required this.isUser,
    this.suggestNearby = false,
    this.isUrgent = false,
    this.otcSuggestions = const [],
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

  const AssessmentResultScreen({
    super.key,
    required this.imagePath,
    this.woundHints = const [],
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
  List<String>? _tagalogSteps;
  bool _isLoadingTagalog = false;
  bool _tagalogTranslationFailed = false;
  final TextEditingController _chatController = TextEditingController();

  List<OtcSuggestion> _otcSuggestions = [];
  bool _isLoadingOtc = false;
  // The saved Health Profile (for the blue "Based on Your Health Profile" box).
  Map<String, dynamic>? _profile;

  // What the user answered after the AI scan and before the results are
  // shown (see askAssessmentQuestions): a 0-5 pain rating, a 0-5 itchiness
  // rating (skin issues only) and the medication they take. Saved with the
  // journal entry.
  int? _painScore;
  int? _itchScore;
  List<String> _medications = const [];

  // The answer to "Are you satisfied with the result?" (null = not answered).
  bool? _satisfied;

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

  @override
  void initState() {
    super.initState();
    _analyzeImage();
    _loadHealthCautions();
  }

  Future<void> _loadHealthCautions() async {
    final profile = await HealthProfileService().getHealthProfile();
    if (!mounted) return;
    if (profile != null) setState(() => _profile = profile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The app was switched to Tagalog while a result is on screen.
    if (AppLanguageScope.isTagalog(context) && _assessment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureTagalogSteps();
      });
    }
  }

  @override
  void dispose() {
    _analyzingTimer?.cancel();
    _chatController.dispose();
    EmergencyAlert.stop();
    super.dispose();
  }

  /// Counts this scan for the AI-scan reliability numbers: a technical
  /// failure (with its reason), a scan that found no wound, a result the
  /// model had low confidence in (counted as failed), or a success. Never
  /// stores the photo or anything about the person.
  void _recordScanOutcome(WoundAssessment a) {
    final stats = AiScanStatsService.instance;
    if (a.error != null) {
      stats.recordFailure(failureReasonFromError(a.error!));
    } else if (!a.isWound) {
      stats.recordNoWound();
    } else if (a.confidence < kLowConfidenceThreshold) {
      stats.recordFailure(ScanFailureReason.lowConfidence);
    } else {
      stats.recordSuccess();
    }
  }

  /// The questions before the result: pain (and, for a skin issue,
  /// itchiness) and medication, then a short "You indicated that…" summary of
  /// the Health Profile and the medication. Null if the screen went away.
  Future<AssessmentAnswers?> _askQuestions(WoundAssessment a) async {
    final profile = await HealthProfileService().getHealthProfile();
    if (!mounted) return null;
    final answers = await askAssessmentQuestions(
      context,
      skinIssue: isSkinIssueCategory(a.category),
      savedMedications: profileMedications(profile),
      // A guest has no Health Profile: ask about existing conditions here.
      askConditions: FirebaseAuth.instance.currentUser == null,
    );
    if (answers == null || !mounted) return null;
    // An animal bite or scratch: nothing more is asked or shown.
    if (answers.animalBite) return answers;
    // Medications named here also go into the Health Profile.
    await HealthProfileService().addMedications(answers.medications);
    if (!mounted) return null;
    final lines = acknowledgementLines(
      context,
      profile: profile ?? answers.conditions,
      medications: answers.medications,
    );
    if (lines.isNotEmpty) await showAcknowledgement(context, lines);
    return answers;
  }

  /// A severe result is an emergency: a pop-up telling the user to get
  /// medical help now (with the alert vibration while it is open). It offers
  /// Call Emergency Services (911) and Nearby Hospitals; the X closes it.
  Future<void> _showSevereDialog() async {
    final s = SevereStrings.of(context);
    const maroon = Color(0xFF7A0000);
    EmergencyAlert.start();
    final openNearby = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/emergency_siren.png',
                        height: 84,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.emergencyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(dialogContext).textTheme.titleMedium
                            ?.copyWith(
                              color: maroon,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _callEmergencyServices,
                        icon: const Icon(Icons.phone_in_talk, size: 18),
                        label: Text(s.callEmergency),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: maroon,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                          shape: const StadiumBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PopupBadge(
                            icon: Icons.local_hospital,
                            size: 36,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              s.medicalNeeded,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: maroon,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: Text(s.nearbyHospitalsButton),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: maroon,
                          side: const BorderSide(color: maroon),
                          minimumSize: const Size.fromHeight(44),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: s.closeTooltip,
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await EmergencyAlert.stop();
    if (!mounted) return;
    if (openNearby == true) {
      showNearbyHealthcareSheet(context);
    } else if (openNearby == false) {
      // The X: close the dialog AND go back to the camera, ready for a new
      // photo. A fresh camera screen sets up its own controller.
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AiCameraScreen()),
      );
    }
  }

  /// An animal was involved: this app cannot address it, so the person is
  /// told to get medical help (with a Nearby hospitals button) and the scan
  /// ends.
  Future<void> _showAnimalDialog({String? message}) async {
    final a = AssessmentStrings.of(context);
    final s = SevereStrings.of(context);
    final openNearby = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFFFFF0F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Text(
            message ?? a.animalCannotHelp,
            style: Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.normal,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.nearbyHospitals),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.close),
            ),
          ],
        ),
      ),
    );
    if (openNearby == true && mounted) await showNearbyHealthcareSheet(context);
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
    _painScore = null;
    _itchScore = null;
    _medications = const [];
    _satisfied = null;

    // A guest whose daily allowance is used up cannot start another scan (this
    // also covers the second wound picked on the multi-injury screen).
    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (isGuest && await GuestUsageService.instance.hasReachedLimit()) {
      if (!mounted) return;
      await showGuestUsageLimitDialog(context);
      if (mounted) Navigator.pop(context);
      return;
    }

    _startAnalyzingTimer();

    final online = await ConnectivityService().isOnline;
    if (!online) {
      _analyzingTimer?.cancel();
      AiScanStatsService.instance.recordFailure(ScanFailureReason.offline);
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
      if (!mounted) return;
      // The language the person has chosen, read before the slow requests.
      final tagalog = AppLanguageScope.isTagalog(context);
      final hintQuery = widget.woundHints.isNotEmpty
          ? widget.woundHints.join(' ')
          : 'wound skin injury first aid care';
      final referenceContext = await FirstAidContentService()
          .buildReferenceContext(hintQuery);

      // What the Health Profile says (conditions, allergies, medicines), so
      // the steps and OTC suggestions can differ for someone with a health
      // condition. Nothing for a guest: they are asked afterwards.
      final profile = await HealthProfileService().getHealthProfile();
      final assessment = await GeminiService().analyzeWoundV2(
        widget.imagePath,
        referenceContext: referenceContext,
        tagalog: tagalog,
        healthContext: healthContextText(profile, profileMedications(profile)),
      );
      _recordScanOutcome(assessment);
      // A real answer came back: it uses one of a guest's daily scans. (An
      // error, eg offline or a timeout, never does.)
      if (isGuest && assessment.error == null) {
        await GuestUsageService.instance.recordSuccessfulUse();
      }
      _analyzingTimer?.cancel();
      if (mounted) {
        // Let the bar visibly reach 100% before swapping in the results.
        setState(() => _analysisFinishing = true);
        await Future.delayed(const Duration(milliseconds: 450));
      }
      // The result waits for the questions, which can't be skipped. They are
      // only asked when the scan found a wound, and not for a severe result:
      // that goes straight to the emergency advice.
      AssessmentAnswers? answers;
      final severe = isSevereCase(assessment);
      // A cut, scratch or laceration: was an animal involved? If so this app
      // cannot help with it; say so and stop here.
      if (mounted &&
          assessment.error == null &&
          assessment.isWound &&
          !severe &&
          isCutScratchLacerationCategory(assessment.category)) {
        final animal = await askAnimalInvolved(context);
        if (!mounted) return;
        if (animal == true) {
          await _showAnimalDialog();
          if (mounted) Navigator.pop(context);
          return;
        }
      }
      if (mounted &&
          assessment.error == null &&
          assessment.isWound &&
          !severe) {
        answers = await _askQuestions(assessment);
        if (answers?.animalBite == true && mounted) {
          final a = AssessmentStrings.of(context);
          await _showAnimalDialog(
            message: '${a.animalBiteAdvice}\n\n${a.guidanceDisclaimer}',
          );
          if (mounted) Navigator.pop(context);
          return;
        }
      }
      if (mounted) {
        setState(() {
          _analysisFinishing = false;
          _assessment = assessment;
          _painScore = answers?.pain;
          _itchScore = answers?.itch;
          _medications = answers?.medications ?? const [];
          // A guest's own answer about conditions stands in for the profile.
          if (answers?.conditions != null) _profile = answers!.conditions;
          // Already in Tagalog when the request asked for it.
          _tagalogSteps = assessment.firstAidStepsTl.isNotEmpty
              ? assessment.firstAidStepsTl
              : null;
          _isAnalyzing = false;
        });
        if (severe) {
          _showSevereDialog();
        } else {
          _loadOtcSuggestions();
        }
        if (AppLanguageScope.isTagalog(context)) _ensureTagalogSteps();
      }
    } catch (e) {
      _analyzingTimer?.cancel();
      AiScanStatsService.instance.recordFailure(
        failureReasonFromError(e.toString()),
      );
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

  // The wound-assessment model returns its own generic-name (brand),
  // age/allergy/how-to-use OTC suggestions directly (see gemini_service's
  // shared OTC_OPTIONS rules) — this just re-validates them through the
  // same denylist/allowlist filter every other AI surface uses, so this
  // screen and chat follow-ups can never show different things.
  Future<void> _loadOtcSuggestions() async {
    final assessment = _assessment;
    if (assessment == null) return;
    setState(() => _isLoadingOtc = true);
    try {
      final filtered = await OtcFilterService.instance.filter(
        assessment.otcOptions,
      );
      // Then take out what conflicts with the person's conditions (a bleeding
      // disorder or blood thinner: no aspirin/NSAIDs; a latex allergy: no
      // latex).
      final results = filterOtcForHealth(
        filtered,
        profile: _profile,
        medications: _medications,
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

  /// The Tagalog steps, asking for them (one extra request) when the result
  /// did not come with them. False if they could not be had; the English
  /// steps stay, with a short note.
  Future<bool> _ensureTagalogSteps() async {
    final assessment = _assessment;
    if (assessment == null) return false;
    if (_tagalogSteps != null) return true;
    if (_isLoadingTagalog) return false;
    setState(() {
      _isLoadingTagalog = true;
      _tagalogTranslationFailed = false;
    });
    final translated = await GeminiService().translateToTagalog(
      assessment.firstAidSteps,
    );
    if (!mounted) return false;
    setState(() {
      _tagalogSteps = translated.isNotEmpty ? translated : null;
      _isLoadingTagalog = false;
      _tagalogTranslationFailed = translated.isEmpty;
    });
    return translated.isNotEmpty;
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
    buffer.writeln('Wound type: ${woundTypeDisplayLabel(a.woundType)}');
    buffer.writeln('Triage: ${triageDisplayLabel(a.triage)}');
    if (_painScore != null) buffer.writeln('Pain score: $_painScore/$kPainMax');
    if (_itchScore != null) {
      buffer.writeln('Itchiness score: $_itchScore/$kPainMax');
    }
    final conditions = profileConditionLabels(_profile, ChecklistStrings.en);
    if (conditions.isNotEmpty) {
      buffer.writeln('Health conditions reported: ${conditions.join('; ')}');
    }
    if (_medications.isNotEmpty) {
      buffer.writeln('Medication taken: ${_medications.join(', ')}');
    }
    // A severe result has no first aid steps (it is an emergency).
    if (a.firstAidSteps.isNotEmpty && !isSevereCase(a)) {
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

  /// "Done": when there is something not saved yet, asks first - "Are you
  /// done with this assessment?" - with Save to Health Journal / Don't save /
  /// Cancel. Saving uses the same journal save as the Save button, then leaves.
  Future<void> _handleDone() async {
    final unsaved = !(_savedToJournal && !_hasUnsavedFollowUps);
    if (!unsaved) {
      Navigator.maybePop(context);
      return;
    }
    final t = ScreenText.of(context);
    // 'save' | 'leave' | null (Cancel / tapped outside)
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.doneConfirmTitle),
        content: Text(t.doneConfirmBody),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(t.doneSaveToJournal),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'leave'),
            child: Text(t.doneDontSave),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'save') {
      await _saveToJournal();
      // Leave only once it is saved (a guest, or a failed save, stays here).
      if (!mounted || !_savedToJournal) return;
    }
    Navigator.maybePop(context);
  }

  Future<void> _saveToJournal() async {
    final user = FirebaseAuth.instance.currentUser;
    final assessment = _assessment;
    if (assessment == null) return;
    if (user == null) {
      await showGuestSaveGateDialog(context);
      return;
    }

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
        'firstAidSteps': isSevereCase(assessment)
            ? <String>[]
            : assessment.firstAidSteps,
        'warningSigns': assessment.redFlags,
        'triage': assessment.triage.name,
        'visibleBleeding': assessment.visibleBleeding,
        'apparentDepth': assessment.apparentDepth,
        'needsProfessionalEvaluation': assessment.needsProfessionalEvaluation,
        'otcSuggestions': _otcSuggestions
            .map(
              (c) => {
                'name': c.name,
                'ageLimit': c.ageLimit,
                'allergyPrecaution': c.allergyPrecaution,
                'howToUse': c.howToUse,
                'category': c.category.name,
              },
            )
            .toList(),
        'userConcern': _userConcern,
        'followUpConversation': _followUpMessages
            .map((m) => m.toJournalMap())
            .toList(),
        'severity': null,
        if (_painScore != null) ...{
          'painScore': _painScore,
          // Marks the 0-5 scale (older entries were rated 1-10).
          'painScaleMax': kPainMax,
        },
        if (_itchScore != null) 'itchScore': _itchScore,
        if (_satisfied != null) 'resultSatisfied': _satisfied,
        if (_medications.isNotEmpty) 'medications': _medications,
        'remindMe': true,
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

        // The healing check-in and, for a wound, the "time to clean your
        // wound" reminders: set for every saved scan, like any journal entry.
        var reminderNote = '';
        if (mounted) {
          final allowed = await NotificationService()
              .ensureHealingReminderPermission(context);
          final due = await NotificationService().scheduleForEntry(
            entryId: docRef.id,
            classification: assessment.category,
          );
          if (mounted) {
            if (due == null) {
              reminderNote = ' ${NotificationStrings.of(context).noBenchmark}';
            } else if (allowed) {
              reminderNote =
                  ' ${await announceReminderSet(context, entryId: docRef.id, due: due)}';
            }
          }
        }

        if (mounted) {
          setState(() {
            _savedToJournal = true;
            _savedJournalEntryId = docRef.id;
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${ScreenText.of(context).assessmentSaved}$reminderNote',
              ),
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
            .timeout(Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _hasUnsavedFollowUps = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ScreenText.of(context).journalEntryUpdated)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ScreenText.of(context).couldNotSaveJournal)),
        );
      }
    }
  }

  /// The triage banner's text, or null when no banner is shown.
  String? _triageBannerTitle(WoundAssessment a) {
    final urgent =
        a.triage == TriageLevel.emergency || a.triage == TriageLevel.urgentCare;
    if (!urgent && !a.needsProfessionalEvaluation) return null;
    final t = ScreenText.of(context);
    if (a.triage == TriageLevel.emergency) return t.seekEmergency;
    return urgent ? t.seekUrgent : t.professionalEval;
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

  /// The send button in the "Describe your concern" bar.
  Widget _buildSendButton(ThemeData theme) {
    final hasText = _chatController.text.trim().isNotEmpty;
    return _buildRoundInputButton(
      theme,
      icon: Icons.send_rounded,
      tooltip: 'Send',
      onPressed: (_isSendingFollowUp || !hasText)
          ? null
          : () => _handleFollowUpSend(),
    );
  }

  /// The blue "Based on Your Health Profile" box (see [HealthProfileBox]).
  Widget _buildHealthCautionBox(ThemeData theme) => HealthProfileBox(
    profile: _profile,
    medications: _medications,
    tagalog: AppLanguageScope.isTagalog(context),
  );

  // Philippines' unified national emergency hotline.
  static const String _emergencyPhoneNumber = '911';

  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: _emergencyPhoneNumber);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScreenText.of(context).couldNotOpenDialer911)),
      );
    }
  }

  /// The reminder banner's text, or null when no banner is shown. Combines
  /// the AI's own result with the user's pain score: whichever is more
  /// serious wins (eg a minor-looking wound with pain 10 still shows urgent
  /// care; a low pain score never lowers an AI emergency/urgent result).
  String? _reminderTitle(WoundAssessment a) {
    final fromAi = reminderFromAssessment(
      a.triage,
      a.needsProfessionalEvaluation,
    );
    final fromPain = reminderFromPain(_painScore);
    if (fromAi.index >= fromPain.index) return _triageBannerTitle(a);
    final p = PainStrings.of(context);
    return fromPain == ReminderLevel.urgent
        ? p.urgentTitle
        : p.professionalTitle;
  }

  /// The pain result under the banner: the score and the message for that
  /// rating (from PainStrings.ratings, one entry per rating). Severe and
  /// worst pain also get a nearby-healthcare button.
  Widget _buildPainCard(ThemeData theme) {
    final score = _painScore;
    if (!isValidPainScore(score)) return const SizedBox.shrink();
    final p = PainStrings.of(context);
    final content = p.rating(score!);
    final level = painLevelFor(score);
    final color = switch (level) {
      PainLevel.mild => Colors.green,
      PainLevel.moderate => Colors.amber.shade800,
      PainLevel.severe => Colors.deepOrange,
      PainLevel.worst => Colors.red,
    };

    final children = <Widget>[
      Text(
        p.scoreLabel(score),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      // The message for this rating.
      Text(
        content.message,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      if (level == PainLevel.severe || level == PainLevel.worst) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showNearbyHealthcareSheet(context),
          icon: const Icon(Icons.local_hospital_outlined, size: 18),
          label: Text(p.findHealthcare),
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTriageBanner(ThemeData theme, WoundAssessment a) {
    if (_reminderTitle(a) == null) return const SizedBox.shrink();

    final isEmergency = a.triage == TriageLevel.emergency;
    final color = isEmergency ? Colors.red : Colors.orange;
    final title = _reminderTitle(a)!;

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
                  label: Text(ScreenText.of(context).callEmergency),
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

  /// Saves the answer to "Are you satisfied with the result?". It counts in
  /// the AI scan numbers (the admin dashboard's AI Scan Performance); a changed
  /// answer moves the count instead of adding a second one. When the scan is
  /// already saved to the journal, the entry gets the answer too (and it is
  /// saved with the entry otherwise).
  void _setSatisfied(bool value) {
    final previous = _satisfied;
    if (previous == value) return;
    AiScanStatsService.instance.recordRating(
      previous: previous,
      current: value,
    );
    setState(() => _satisfied = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AiScanStatsStrings.of(context).feedbackThanks)),
    );

    final user = FirebaseAuth.instance.currentUser;
    final entryId = _savedJournalEntryId;
    if (user != null && entryId != null) {
      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journalEntries')
            .doc(entryId)
            .update({'resultSatisfied': value})
            .catchError((Object e) {
              debugPrint('Could not save the satisfaction answer: $e');
            }),
      );
    }
  }

  Widget _buildSatisfaction(ThemeData theme) {
    final s = AiScanStatsStrings.of(context);
    Widget choice(String label, bool value) {
      final selected = _satisfied == value;
      return ElevatedButton(
        onPressed: () => _setSatisfied(value),
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? theme.colorScheme.primary : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black87,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: selected ? 0 : 1,
        ),
        child: Text(label),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.feedbackQuestion,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          choice(s.yes, true),
          const SizedBox(width: 8),
          choice(s.no, false),
        ],
      ),
    );
  }

  /// The itchiness rating a skin-issue answer gave (nothing when none).
  Widget _buildItchCard(ThemeData theme) {
    final score = _itchScore;
    if (score == null) return const SizedBox.shrink();
    final a = AssessmentStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          '${a.itchTitle.replaceAll('?', '')}: $score/$kPainMax '
          '(${a.itchLabels[score]})',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Shown instead of the first aid steps for a severe result.
  Widget _buildSevereNotice(ThemeData theme) {
    final s = SevereStrings.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.noStepsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(s.noStepsBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showNearbyHealthcareSheet(context),
              icon: const Icon(Icons.local_hospital_outlined, size: 18),
              label: Text(s.nearbyHospitals),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentResult(ThemeData theme, WoundAssessment a) {
    final severe = isSevereCase(a);
    // Tagalog when the app language is Tagalog (set in Settings).
    final useTl = AppLanguageScope.isTagalog(context);
    final locale = useTl ? HealthKitLocale.tl : HealthKitLocale.en;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTriageBanner(theme, a),
        _buildPainCard(theme),
        // The Evaluation, right after the pain result (the same one that is
        // saved with the entry and shown in its Overview).
        _buildItchCard(theme),
        _buildHealthCautionBox(theme),
        if (severe)
          _buildSevereNotice(theme)
        else if (a.firstAidSteps.isNotEmpty) ...[
          Text(
            ScreenText.of(context).firstAidStepsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (_tagalogTranslationFailed)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                ScreenText.of(context).couldNotTranslate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 8),
          FirstAidStepList(
            steps: phasedStepsFromAi(
              a.firstAidSteps,
              shown: useTl ? _tagalogSteps : null,
            ),
            phaseLabel: (phase) =>
                HealthKitStrings.of('phase_${phase.name}', locale),
            whyLabel: HealthKitStrings.of('whyLabel', locale),
            numbered: true,
            circleNumbers: true,
            phaseStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        if (a.uncertainties.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: Color(0xFF8F8584),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ScreenText.of(context).uncertainDetails.replaceFirst(
                      '{details}',
                      (useTl && a.uncertaintiesTl.isNotEmpty
                              ? a.uncertaintiesTl
                              : a.uncertainties)
                          .join('; '),
                    ),
                    style: AppTheme.noteStyle(),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE797),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info, color: Color(0xFF695300), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ScreenText.of(context).disclaimerTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF695300),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ScreenText.of(context).disclaimerBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF695300),
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
        Text(
          ScreenText.of(context).analyzingWound,
          style: theme.textTheme.titleMedium,
        ),
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
                  ScreenText.of(context).analysisTip,
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
              _painScore = null;
              _itchScore = null;
              _medications = const [];
              _satisfied = null;
              _otcSuggestions = [];
            });
            _analyzeImage();
          },
          icon: const Icon(Icons.refresh),
          label: Text(ScreenText.of(context).retry),
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
          label: Text(ScreenText.of(context).useOfflineKit),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  // Renders through the same shared OtcSuggestionsBlock widget every AI
  // entry point uses (see otc_suggestions_block.dart) — already filtered
  // via OtcFilterService in _loadOtcSuggestions, and grouped into
  // "Suggested OTC options"/"Suggested supplies" by suggestion.category.
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
              'Looking up OTC suggestions…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OtcSuggestionsBlock(suggestions: _otcSuggestions, cardStyle: true),
    );
  }

  Future<void> _handleFollowUpSend() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSendingFollowUp) return;

    // Deliberately no local out-of-scope pre-check here (unlike the
    // standalone chatbot) — this screen already has a specific wound in
    // context (CURRENT WOUND ANALYSIS, sent with every message below), so
    // a message like "I have a headache" is very plausibly ABOUT that
    // wound (eg a head injury) even without repeating wound-related
    // words. A keyword-only check can't see that context and would wrongly
    // refuse it; the shared system prompt's own scope/borderline-case
    // judgment, which DOES see the wound context, is the right place to
    // decide here.
    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (isGuest && await GuestUsageService.instance.hasReachedLimit()) {
      if (!mounted) return;
      await showGuestUsageLimitDialog(context);
      return;
    }

    setState(() {
      _followUpMessages.add(_FollowUpMessage(text: text, isUser: true));
      _isSendingFollowUp = true;
    });
    _chatController.clear();

    final online = await ConnectivityService().isOnline;
    if (!online) {
      if (!mounted) return;
      setState(() {
        _followUpMessages.add(
          _FollowUpMessage(text: noInternetMessage, isUser: false),
        );
        _isSendingFollowUp = false;
      });
      return;
    }

    String english;
    String? tagalog;
    bool suggestNearby = false;
    bool isUrgent = false;
    List<OtcSuggestion> otcSuggestions = const [];
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
            // What the person said about their health (profile / the scan's
            // questions), so the follow-up answers fit them.
            healthContext: chatHealthContext(
              profile: _profile,
              medications: _medications,
            ),
          )
          .timeout(const Duration(seconds: 20));
      final parsed = parseBilingualReply(raw);
      english = parsed.english.trim().isNotEmpty
          ? parsed.english
          : randomFollowUpFallbackMessage();
      tagalog = parsed.tagalog;
      suggestNearby = parsed.suggestNearby;
      isUrgent = parsed.isUrgent;
      otcSuggestions = await OtcFilterService.instance.filter(
        parsed.otcSuggestions,
      );
      if (isGuest && !isRefusalReply(english)) {
        await GuestUsageService.instance.recordSuccessfulUse();
      }
    } catch (e, st) {
      logFollowUpError('AssessmentResult', e, st);
      english = isNetworkError(e)
          ? noInternetMessage
          : randomFollowUpFallbackMessage();
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
        Row(
          children: [
            Text(
              ScreenText.of(context).followUpLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const GuestUsageBadge(),
          ],
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                (!m.isUser &&
                                        AppLanguageScope.isTagalog(context) &&
                                        m.tagalog != null)
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
                      label: Text(ScreenText.of(context).findNearbyHealthcare),
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
    // As wide as the Save to Health Journal and Done buttons (the screen's own
    // 16px side padding), with a maroon outline; the send button sits at the
    // right edge with only a few pixels around it.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: ScreenText.of(context).describeHint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleFollowUpSend(),
            ),
          ),
          _buildSendButton(theme),
        ],
      ),
    );
  }

  /// The yellow "for initial assessment only" banner under the top bar.
  Widget _disclaimerBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE797),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        ScreenText.of(context).disclaimerShort,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          color: const Color(0xFF483900),
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  /// While the photo is being analysed: the photo takes all the room there is,
  /// with the progress under it.
  Widget _buildAnalyzingBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _disclaimerBanner(theme),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(widget.imagePath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildAnalyzingState(theme),
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
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_box_outlined,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            // "Category: " in regular, the name in bold.
            Builder(
              builder: (context) {
                final label = ScreenText.of(context).categoryLabel;
                final at = label.indexOf('{category}');
                final name = ScreenText.of(context).categoryName(category);
                final style = theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                );
                return Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      TextSpan(text: at < 0 ? label : label.substring(0, at)),
                      TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (at >= 0)
                        TextSpan(
                          text: label.substring(at + '{category}'.length),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            ClassificationInfoButton(
              classification: category,
              color: theme.colorScheme.primary,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'AI Vision Camera',
          style: TextStyle(fontWeight: FontWeight.normal),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Everything else scrolls, so this screen can never overflow
            // regardless of screen size or how much content is shown.
            Expanded(
              child: _isAnalyzing && _error == null
                  ? _buildAnalyzingBody(theme)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _disclaimerBanner(theme),
                          const SizedBox(height: 12),

                          // Captured image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              File(widget.imagePath),
                              height: 186,
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                          if (!_isAnalyzing &&
                              _error == null &&
                              !(assessment != null && isSevereCase(assessment)))
                            _buildOtcSuggestions(theme),

                          // Satisfaction question: feeds the AI Scan Performance
                          // numbers in the admin dashboard.
                          if (!_isAnalyzing &&
                              _error == null &&
                              assessment != null &&
                              assessment.isWound)
                            _buildSatisfaction(theme),

                          // Save to Journal button
                          if (!_isAnalyzing && _error == null) ...[
                            if (_savedToJournal && !_hasUnsavedFollowUps)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                  ),
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
                                      ScreenText.of(context).savedToJournal,
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
                                      ? ScreenText.of(context).saving
                                      : _hasUnsavedFollowUps
                                      ? ScreenText.of(context).updateJournal
                                      : ScreenText.of(context).saveToJournal,
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
            // The scan is finished: Done goes back to the Dashboard (the
            // camera is no longer under this screen).
            if (!_isAnalyzing && _error == null && assessment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleDone,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(ScreenText.of(context).done),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
