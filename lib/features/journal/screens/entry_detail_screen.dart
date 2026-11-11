import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/export_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../i18n/offline_strings.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../i18n/notification_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/evaluation_card.dart';
import '../../../core/widgets/first_aid_step_list.dart';
import '../../../data/first_aid_guides.dart' show GuidePhase;
import '../../../i18n/health_kit_locale.dart';
import '../../../i18n/health_kit_ui_strings.dart';
import '../../../i18n/journal_edit_strings.dart';
import '../../../data/journal_evaluation.dart';
import '../../../i18n/app_language.dart';
import '../../../data/health_profile_summary.dart';
import '../../../data/healing_durations.dart';
import '../../../i18n/checklist_strings.dart';
import '../../../services/health_profile_service.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../chatbot/screens/chatbot_screen.dart';
import 'journal_entry_menu.dart';
import '../../../i18n/screen_text_strings.dart';

class EntryDetailScreen extends StatefulWidget {
  final String entryId;
  final Map<String, dynamic> data;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    required this.data,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  // Reflects the persisted response as soon as the entry is opened — not
  // just when the in-app dialog runs this same session — so a "Wound
  // Worsened" reply given via the scheduled healing check-in notification
  // (answered from outside the app, or on a previous visit) still shows the
  // caution banner the next time this entry is opened.
  late bool _showingReferral =
      widget.data['milestoneResponded'] == true &&
      widget.data['feelingBetter'] == false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowMilestone());
  }

  int? _monitoredDays() {
    final timestamp = widget.data['createdAt'] as Timestamp?;
    if (timestamp == null) return null;
    return DateTime.now().difference(timestamp.toDate()).inDays;
  }

  int? _standardDuration() {
    return healingDaysFor(
      widget.data['classification'] as String?,
      severity: widget.data['severity'] as String?,
    );
  }

  Future<void> _maybeShowMilestone() async {
    final monitored = _monitoredDays();
    final standard = _standardDuration();
    if (monitored == null || standard == null) return;
    if (monitored < standard) return;

    final alreadyResponded = widget.data['milestoneResponded'] == true;
    if (alreadyResponded) return;

    if (!mounted) return;
    await _showMilestoneDialog();
  }

  Future<void> _showMilestoneDialog() async {
    final text = NotificationStrings.of(context);

    // '_better' / '_notYet' / '_worse' — a plain string result keeps this a
    // 3-way choice without a one-off enum just for this dialog. Neutral
    // check-in question only; "It's getting worse" leads to a
    // recommendation, not a diagnosis.
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(text.checkInTitle),
        content: Text(text.checkInBody),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '_notYet'),
            child: Text(text.dialogNotYet),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, '_worse'),
            child: Text(text.dialogWorse),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '_better'),
            child: Text(text.dialogBetter),
          ),
        ],
      ),
    );

    if (choice == null) return; // dismissed without choosing

    switch (choice) {
      case '_better':
        await _recordMilestoneResponse(true);
        await NotificationService().cancelHealingCheckIn(widget.entryId);
        break;
      case '_worse':
        await _recordMilestoneResponse(false);
        await NotificationService().cancelHealingCheckIn(widget.entryId);
        if (mounted) setState(() => _showingReferral = true);
        break;
      case '_notYet':
        await NotificationService().remindHealingCheckInTomorrow(
          entryId: widget.entryId,
          classification:
              widget.data['classification'] as String? ?? 'this issue',
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(text.notYetSnack)));
        }
        break;
    }
  }

  Future<void> _recordMilestoneResponse(bool feelingBetter) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(widget.entryId)
          .update({'milestoneResponded': true, 'feelingBetter': feelingBetter})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-critical; if this fails, the dialog may reappear next visit
    }
  }

  Widget _buildPhotoStrip(ThemeData theme, List<String> imageUrls) {
    final s = JournalEditStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.photosCountFormat(imageUrls.length),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrls[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Icon(Icons.cloud_off_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrls[i],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 72,
                    height: 72,
                    child: ColoredBox(color: Colors.black12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationSection(ThemeData theme) {
    final userConcern = widget.data['userConcern'] as String?;
    final conversation =
        (widget.data['followUpConversation'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final questionsAndAnswers =
        (widget.data['questionsAndAnswers'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    final redFlags =
        (widget.data['redFlags'] as List?)?.cast<String>() ?? const [];

    if ((userConcern == null || userConcern.trim().isEmpty) &&
        conversation.isEmpty &&
        questionsAndAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userConcern != null && userConcern.trim().isNotEmpty) ...[
            Text(
              'Your Concern',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(userConcern, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          if (questionsAndAnswers.isNotEmpty) ...[
            Text(
              'Questions & Answers',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...questionsAndAnswers.asMap().entries.map((entry) {
              final qa = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Q${entry.key + 1}: ${qa['question']}\nA: ${qa['answer']}',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (redFlags.isNotEmpty) ...[
            Container(
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
                    'Professional Consultation Recommended',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...redFlags.map(
                    (f) => Text(
                      '• $f',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (conversation.isNotEmpty) ...[
            Text(
              'Follow-Up Conversation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...conversation.map((turn) {
              final isUser = turn['role'] == 'user';
              final text = turn['text']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUser ? 'You' : 'Assistant',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// The auto-generated Evaluation (ADPIE: Evaluation), built from fixed
  /// templates filled with what this entry saved — never free AI text.
  Widget _buildHealingTimeline(ThemeData theme) {
    final standard = _standardDuration();
    final monitored = _monitoredDays() ?? 0;

    if (standard == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Healing-time estimate unavailable — this entry wasn\'t '
                'confidently matched to a specific wound type. Monitor how '
                'you feel and consult a professional if you\'re unsure.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final progress = (monitored / standard).clamp(0.0, 1.0);
    final isComplete = monitored >= standard;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFCEDED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Healing Progress',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: ' (Estimate)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isComplete
                        ? 'Milestone reached!'
                        : 'Day $monitored of $standard',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isComplete ? Colors.green[700] : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFFBD3D3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? Colors.green : primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Day 0', style: theme.textTheme.bodySmall),
                  Text(
                    'Day $standard\n(Standard)',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              if (isComplete) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You\'ve reached the standard healing timeframe.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is a general estimate based on typical recovery '
          'timelines, not a guaranteed recovery date. Actual healing '
          'varies by person — consult a doctor if it isn\'t improving.',
          style: AppTheme.noteStyle(),
        ),
      ],
    );
  }

  /// An AI-scan entry's saved text, split back into its facts (Wound type,
  /// Triage, Pain score...) and anything else it says. Null for an entry that
  /// was written by hand.
  ({List<(String, String)> facts, String rest})? _aiParts(String description) {
    if (widget.data['source'] != 'ai_camera') return null;
    final facts = <(String, String)>[];
    final rest = <String>[];
    var inSteps = false;
    var inFacts = true;
    for (final raw in description.split('\n')) {
      final line = raw.trimRight();
      if (inFacts) {
        final m = RegExp(r'^([A-Za-z ]{2,24}):\s*(.+)$').firstMatch(line);
        if (m != null) {
          final label = m.group(1)!;
          facts.add((label, m.group(2)!));
          continue;
        }
        inFacts = false;
      }
      if (line.trim().toUpperCase() == 'FIRST AID STEPS:') {
        inSteps = true;
        continue;
      }
      if (inSteps) {
        if (line.trim().isEmpty) {
          inSteps = false;
        }
        continue; // the steps are drawn from the saved list
      }
      rest.add(line);
    }
    if (facts.isEmpty) return null;
    return (facts: facts, rest: rest.join('\n').trim());
  }

  /// The blue box of facts: bold label, then its value.
  Widget _factsBox(ThemeData theme, List<(String, String)> facts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3F6DB3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: '${f.$1}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: f.$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "First Aid Steps": Before / During / After, numbered on from one to the
  /// next. Empty when the entry saved no steps.
  List<Widget> _stepsSection(ThemeData theme) {
    final saved = (widget.data['firstAidSteps'] as List?)?.cast<String>() ?? [];
    if (saved.isEmpty) return const [];
    final locale = AppLanguageScope.isTagalog(context)
        ? HealthKitLocale.tl
        : HealthKitLocale.en;
    return [
      const SizedBox(height: 14),
      Text(
        'First Aid Steps',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      const SizedBox(height: 4),
      FirstAidStepList(
        steps: [
          for (final step in phasedStepsFromAi(saved))
            PhasedStep(phase: step.phase, text: step.text),
        ],
        phaseLabel: (GuidePhase phase) =>
            HealthKitStrings.of('phase_${phase.name}', locale),
        whyLabel: '',
        numbered: true,
        phaseStyle: theme.textTheme.titleSmall?.copyWith(color: Colors.black),
      ),
    ];
  }

  /// Exports this entry as a PDF, with the Health Profile's conditions and
  /// current medications (read when exporting, so they are up to date).
  Future<void> _exportEntry({
    required String title,
    required String description,
    required String classification,
    required Timestamp? timestamp,
    required int monitoredDays,
  }) async {
    final tagalog = AppLanguageScope.isTagalog(context);
    Map<String, dynamic>? profile;
    try {
      profile = await HealthProfileService().getHealthProfile();
    } catch (_) {
      // No profile (offline, guest): printed as "None listed".
    }
    await ExportService().exportEntryAsPdf(
      title: title,
      description: description,
      classification: classification,
      createdAt: timestamp?.toDate() ?? DateTime.now(),
      monitoredDays: monitoredDays,
      referredForConsultation: _showingReferral,
      evaluation: _evaluationText(widget.data, monitoredDays),
      healthConditions: profileConditionLabels(
        profile,
        tagalog ? ChecklistStrings.tl : ChecklistStrings.en,
      ),
      medications: profileMedications(profile),
    );
  }

  /// The same Evaluation text the card shows, in the current language, for
  /// the exported log.
  String? _evaluationText(Map<String, dynamic> data, int monitoredDays) =>
      buildJournalEvaluation(
        data,
        tagalog: AppLanguageScope.isTagalog(context),
        monitoredDays: monitoredDays,
      );

  /// A text-only entry: title, date and notes. Offline it also carries the
  /// yellow notice and the big "Offline Mode" mark.
  Widget _buildTextOnly(
    ThemeData theme,
    PreferredSizeWidget appBar, {
    required String title,
    required String dateText,
    required String description,
    required Timestamp? timestamp,
    required int monitoredDays,
  }) {
    final s = OfflineStrings.of(context);
    final offline = ConnectivityService().lastKnownOnline == false;
    const maroon = Color(0xFF7A0000);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF1F1),
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFFFAF9FF),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: maroon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(color: maroon),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE797),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF483900),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.healingNotice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF483900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (offline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off, size: 120, color: maroon),
                      const SizedBox(height: 8),
                      Text(
                        s.offlineModeLabel,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: maroon,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Back online: the usual ways to get more help.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: OutlinedButton(
                    onPressed: () => _exportEntry(
                      title: title,
                      description: description,
                      classification: 'Unspecified',
                      timestamp: timestamp,
                      monitoredDays: monitoredDays,
                    ),
                    child: Text(ScreenText.of(context).exportLog),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final classification = data['classification'] as String? ?? 'Unspecified';
    final timestamp = data['createdAt'] as Timestamp?;
    final dateText = timestamp != null
        ? DateFormat('EEEE, MMMM d').format(timestamp.toDate())
        : '';
    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
    final imageCount = data['imageCount'] as int? ?? imageUrls.length;
    final monitoredDays = _monitoredDays() ?? 0;

    final ai = _aiParts(description);

    final appBar = AppBar(
      centerTitle: true,
      title: const Text('Health Journal'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        JournalEntryMenu(
          entryId: widget.entryId,
          data: widget.data,
          iconColor: Colors.white,
          // Show the edited entry straight away.
          onEdited: (changes) => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EntryDetailScreen(
                entryId: widget.entryId,
                data: {...widget.data, ...changes},
              ),
            ),
          ),
          onDeleted: () => Navigator.pop(context),
        ),
      ],
    );

    // An entry with no category (written offline or as a guest): just the
    // notes, no healing timeline or evaluation.
    if (data['classification'] == null) {
      return _buildTextOnly(
        theme,
        appBar,
        title: title,
        dateText: dateText,
        description: description,
        timestamp: timestamp,
        monitoredDays: monitoredDays,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrls.first,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    // Offline (or a photo that is gone): a quiet placeholder,
                    // never an error message.
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          imageCount > 0
                              ? '$imageCount image(s) attached'
                              : 'No image',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              // Every photo of this entry: new ones added over time make a
              // visual progress log.
              if (imageUrls.length > 1) ...[
                const SizedBox(height: 8),
                _buildPhotoStrip(theme, imageUrls),
              ],
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (ai != null) ...[
                _factsBox(theme, ai.facts),
                ..._stepsSection(theme),
                if (ai.rest.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(ai.rest, style: theme.textTheme.bodyMedium),
                ],
              ] else
                Text(description, style: theme.textTheme.bodyMedium),

              const SizedBox(height: 14),
              _buildHealingTimeline(theme),
              const SizedBox(height: 14),
              EvaluationCard(data: data, monitoredDays: monitoredDays),

              _buildConversationSection(theme),
              if (_showingReferral) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        color: theme.colorScheme.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We recommend seeking professional consultation',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We have noted your concern. It sounds like your recovery is '
                        'not progressing as expected for this timeframe. Based on '
                        'clinical standards, a lack of improvement at this stage '
                        'requires a closer look to prevent complications.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => showNearbyHealthcareSheet(context),
                        icon: const Icon(Icons.local_hospital_outlined),
                        label: Text(
                          ScreenText.of(context).findNearbyHealthcare,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _exportEntry(
                          title: title,
                          description: description,
                          classification: classification,
                          timestamp: timestamp,
                          monitoredDays: monitoredDays,
                        ),
                        child: Text(ScreenText.of(context).exportLog),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatbotScreen(
                        initialContext: classification,
                        journalEntryId: widget.entryId,
                        // Recovery not progressing: open with nearby options.
                        showNearbyFirst: _showingReferral,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(ScreenText.of(context).needMoreHelp),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _exportEntry(
                  title: title,
                  description: description,
                  classification: classification,
                  timestamp: timestamp,
                  monitoredDays: monitoredDays,
                ),
                child: Text(ScreenText.of(context).exportLog),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
