import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;
  final Map<String, dynamic> data;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final classification = data['classification'] as String? ?? 'Unspecified';
    final timestamp = data['createdAt'] as Timestamp?;
    final dateText = timestamp != null
        ? DateFormat('EEEE, MMMM d').format(timestamp.toDate())
        : '';
    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
    final imageCount = data['imageCount'] as int? ?? imageUrls.length;

    final monitoredDays = timestamp != null
        ? DateTime.now().difference(timestamp.toDate()).inDays
        : 0;

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
                              ? '$imageCount image(s) attached locally\n(cloud sync pending Storage need to upgrade)'
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
