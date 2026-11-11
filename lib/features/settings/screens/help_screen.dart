import 'package:flutter/material.dart';
import '../../../core/widgets/help_tour_launcher.dart';
import '../../../i18n/nav_strings.dart';
import '../../../i18n/help_strings.dart';
import 'help_topic_screen.dart';

/// The banner behind the heart picture (the picture's own background).
const Color _heroColor = Color(0xFF780000);

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _topics = [
    (HelpTopic.gettingStarted, 'assets/images/help_getting_started.png'),
    (HelpTopic.privacy, 'assets/images/help_privacy.png'),
    (HelpTopic.journal, 'assets/images/help_journal.png'),
    (HelpTopic.references, 'assets/images/help_references.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = HelpStrings.of(context);
    final primary = theme.colorScheme.primary;
    final descriptions = [
      s.gettingStartedSub,
      s.privacySub,
      s.journalSub,
      s.referencesSub,
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(NavStrings.of(context).helpAndSupport),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // The page fills the screen: the banner and the cards share whatever
        // height is left (never less than their own minimum, so on a short
        // screen the page scrolls instead).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 34,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.heading,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.intro,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // The maroon banner with the hugging heart: full width and
                    // wider than tall (3:2), as in the design.
                    AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _heroColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/help_hero.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Two cards to a row.
                    for (var row = 0; row < _topics.length; row += 2) ...[
                      Expanded(
                        flex: 2,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = row; i < row + 2; i++) ...[
                              if (i > row) const SizedBox(width: 14),
                              Expanded(
                                child: _PageTile(
                                  title: HelpTopicScreen.sectionOf(
                                    s,
                                    _topics[i].$1,
                                  ).title,
                                  description: descriptions[i],
                                  icon: _topics[i].$2,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HelpTopicScreen(topic: _topics[i].$1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: () {
                        HelpTourLauncher.instance.requestTour();
                        // Back to the dashboard. A guest, or someone in
                        // Offline Mode, entered it on top of the login
                        // screen, so "the first screen" is not enough.
                        Navigator.of(context).popUntil(
                          (route) =>
                              route.isFirst ||
                              route.settings.name == '/dashboard',
                        );
                      },
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: Text(
                        s.replayTour,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7ECEB),
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withValues(alpha: 0.5)),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white card (a pink circle with the icon, the title, a line about it)
/// that opens a Help page.
class _PageTile extends StatelessWidget {
  final String title;
  final String description;
  final String icon;
  final VoidCallback onTap;

  const _PageTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 140),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE3E3),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(icon, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF303130),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
