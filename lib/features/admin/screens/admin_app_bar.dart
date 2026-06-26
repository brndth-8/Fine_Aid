import 'package:flutter/material.dart';

Widget adminAppBar(BuildContext context, ThemeData theme, String title) {
  return Container(
    color: theme.colorScheme.primary,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ),
  );
}
