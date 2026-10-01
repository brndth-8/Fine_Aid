import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/guest_usage_service.dart';

/// "X of 5 left today" — shown only for a guest (not registered or logged
/// in), near the AI Cam trigger or a follow-up question input. Renders
/// nothing for a signed-in user, who has no limit.
class GuestUsageBadge extends StatefulWidget {
  final TextStyle? style;

  const GuestUsageBadge({super.key, this.style});

  @override
  State<GuestUsageBadge> createState() => _GuestUsageBadgeState();
}

class _GuestUsageBadgeState extends State<GuestUsageBadge> {
  @override
  void initState() {
    super.initState();
    GuestUsageService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser != null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: GuestUsageService.instance,
      builder: (context, _) {
        final remaining = GuestUsageService.instance.remaining;
        final theme = Theme.of(context);
        return Text(
          '$remaining of ${GuestUsageService.dailyLimit} left today (guest)',
          style:
              widget.style ??
              theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        );
      },
    );
  }
}
