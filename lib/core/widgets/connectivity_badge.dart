import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// A small, subtle "Offline" pill. Renders nothing at all while online, so
/// it never adds visual noise to a screen — it only appears when there's
/// actually something the user should know.
class ConnectivityBadge extends StatefulWidget {
  const ConnectivityBadge({super.key});

  @override
  State<ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<ConnectivityBadge> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    ConnectivityService().isOnline.then((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
