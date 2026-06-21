import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase/notification_service.dart';

// Standard healing durations by classification, in days. Used to determine
const Map<String, int> _healingDurations = {
  'Injury (Wounds/laceration/Abrasion)': 10,
  'Burns': 7,
  'Skin Issues': 14,
  'Animal Bite/Scratch': 10,
};

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
  bool _showingReferral = false;

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
    return _healingDurations[classification];
  }

  Future<void> _maybeShowMilestone() async {
    final monitored = _monitoredDays();
    final standard = _standardDuration();
    if (monitored == null || standard == null) return;
    if (monitored < standard) return;

    final alreadyResponded = widget.data['milestoneResponded'] == true;
    if (alreadyResponded) return;

    if (!mounted) return;
    await _showMilestoneDialog(standard);
  }

  Future<void> _showMilestoneDialog(int standardDays) async {
    final classification =
        widget.data['classification'] as String? ?? 'this issue';

    final feelingBetter = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Healing Milestone'),
        content: Text(
          'You have reached your healing timeframe for [$classification].\n'
          'Are you feeling better?\n\n'
          'Duration: $standardDays Days Monitored',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No, I am still not"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, I'm feeling better"),
          ),
        ],
      ),
    );

    if (feelingBetter == null) return; // dismissed without choosing

    await _recordMilestoneResponse(feelingBetter);

    if (!feelingBetter && mounted) {
      setState(() => _showingReferral = true);
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
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 48),
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
                              ? '$imageCount image(s) attached locally\n(cloud sync pending Storage upgrade)'
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
                        'We advise to seek medical consultation',
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
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export feature coming soon'),
                            ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AI follow-up chat coming soon'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Need More Help'),
              ),

              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  NotificationService().showTestMilestoneNotification(
                    classification: classification,
                  );
                },
                child: const Text('(Test) Send milestone notification'),
              ),

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export feature coming soon')),
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
