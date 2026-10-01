import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/export_service.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../data/healing_durations.dart';
import '../../../core/widgets/nearby_healthcare_sheet.dart';
import '../../chatbot/screens/chatbot_screen.dart';
import 'journal_list_screen.dart';

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
    final classification = widget.data['classification'] as String?;
    return healingDurationDays[classification];
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
    final classification = widget.data['classification'] as String?;

    // '_better' / '_notYet' / '_worse' — a plain string result keeps this
    // a 3-way choice without a one-off enum just for this dialog.
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(healingMilestoneTitle),
        content: Text(healingMilestoneBody(classification)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '_notYet'),
            child: const Text('Not yet'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, '_worse'),
            child: const Text('It\'s getting worse'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '_better'),
            child: const Text('Yes, I\'m feeling better'),
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
          classification: classification ?? 'this issue',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Okay — we\'ll check in again tomorrow.'),
            ),
          );
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Healing Progress (Estimate)',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                isComplete
                    ? 'Milestone reached!'
                    : 'Day $monitored of $standard',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isComplete
                      ? Colors.green[700]
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.15,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
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
          const SizedBox(height: 8),
          Text(
            'This is a general estimate based on typical recovery '
            'timelines, not a guaranteed recovery date. Actual healing '
            'varies by person — consult a doctor if it isn\'t improving.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.grey.shade700,
                    ),
                    tooltip: 'Delete entry',
                    onPressed: () async {
                      final deleted =
                          await JournalListScreen.confirmAndDeleteEntry(
                            context,
                            widget.entryId,
                          );
                      if (deleted && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrls.first,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(dateText, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Text(description, style: theme.textTheme.bodyMedium),

              const SizedBox(height: 16),
              _buildHealingTimeline(theme),

              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Classification: ', style: theme.textTheme.bodyMedium),
                  Text(
                    classification,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Monitored: $monitoredDays Day${monitoredDays == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium,
              ),
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
                        label: const Text('Find Nearby Healthcare'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          ExportService().exportEntryAsPdf(
                            title: title,
                            description: description,
                            classification: classification,
                            createdAt: timestamp?.toDate() ?? DateTime.now(),
                            monitoredDays: monitoredDays,
                            referredForConsultation: _showingReferral,
                          );
                        },
                        child: const Text('Export Log'),
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
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Need More Help'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  ExportService().exportEntryAsPdf(
                    title: title,
                    description: description,
                    classification: classification,
                    createdAt: timestamp?.toDate() ?? DateTime.now(),
                    monitoredDays: monitoredDays,
                    referredForConsultation: _showingReferral,
                  );
                },
                child: const Text('Export Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
