import 'package:flutter/material.dart';
import '../../../i18n/help_strings.dart';

/// A page under Help & Support -> References ("Verified Medical Sources",
/// "Doctor-Reviewed Content"). The body is a placeholder for now; to add
/// content later, fill [children] (the page scrolls) — no restructuring
/// needed.
class ReferenceDetailScreen extends StatelessWidget {
  final String title;

  /// The page's content. Empty for now, which shows the placeholder.
  final List<Widget> children;

  const ReferenceDetailScreen({
    super.key,
    required this.title,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: children.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Text(
                              HelpStrings.of(context).contentComingSoon,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ]
                      : children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
