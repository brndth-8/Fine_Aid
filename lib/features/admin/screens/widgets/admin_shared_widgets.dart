import 'package:flutter/material.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;
  final IconData icon;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.change,
    this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Icon(icon, color: theme.colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminAnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final Color? changeColor;

  const AdminAnalyticsCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              style: TextStyle(
                fontSize: 11,
                color: changeColor ?? Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
