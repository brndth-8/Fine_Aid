import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

/// Geometry shared by the sidebar's pieces so everything lines up: items put
/// the icon in a fixed-width column (margin + accent bar + padding from the
/// left edge), and the label text starts at [textLeft].
class AdminNavMetrics {
  AdminNavMetrics._();

  static const double margin = 8;
  static const double bar = 4;
  static const double padding = 12;
  static const double iconColumn = 24;
  static const double gap = 12;

  /// Where item text (and therefore section headings) start from the left.
  static const double textLeft = margin + bar + padding + iconColumn + gap;
}

/// A heading such as OVERVIEW with a thin divider under it. The line is inset
/// 16px from both edges and the label has 8px of its own left padding, so the
/// label starts exactly above the nav icons (which sit 4 + 12px inside the
/// 8px item margin).
class AdminNavSection extends StatelessWidget {
  const AdminNavSection(this.label, {super.key, this.first = false});

  final String label;

  /// The first heading sits right under the sidebar header: the nav list's
  /// own 8px of padding is the only space above it (16px for the others).
  final bool first;

  /// Where the label (and so the icons below it) start from the left.
  static const double labelLeft = 16 + 8;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Nav items carry 2px of vertical margin of their own, so 14 + 2 = 16px
      // above a heading and 4 + 2 = 6px between its line and the first item.
      padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 11 * 0.08,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// One navigation entry: icon in a fixed-width column, label on a single line.
class AdminNavItem extends StatelessWidget {
  const AdminNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unselectedText = const Color(0xFFF5F5F5).withValues(alpha: 0.85);
    final color = selected ? AdminTheme.maroon : unselectedText;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AdminNavMetrics.margin,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        // The accent bar is always there (transparent when not selected) so
        // selected and unselected items keep their text on the same line.
        border: Border(
          left: BorderSide(
            color: selected ? AdminTheme.accentBright : Colors.transparent,
            width: AdminNavMetrics.bar,
          ),
        ),
      ),
      // Material(transparency) so hover/ripple paint over the decoration.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminNavMetrics.padding,
              vertical: 10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: AdminNavMetrics.iconColumn,
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: AdminNavMetrics.gap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom tile: the admin's name, role and the logout icon on ONE row,
/// vertically centred with each other. Tapping the tile opens Admin Accounts;
/// the logout icon has its own tap target.
class AdminNavFooter extends StatelessWidget {
  const AdminNavFooter({
    super.key,
    required this.onOpenAccount,
    required this.onLogout,
  });

  final VoidCallback onOpenAccount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        hoverColor: Colors.white.withValues(alpha: 0.08),
        onTap: onOpenAccount,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFF5F5F5),
                      ),
                    ),
                    Text(
                      'Administrator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log out',
                icon: Icon(
                  Icons.logout,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 18,
                ),
                onPressed: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sidebar's frame: [header] on top, [nav] in the middle (it scrolls when
/// the window is shorter than the menu), [footer] pinned to the bottom. It
/// always fills the height it is given, so on a tall monitor the maroon column
/// runs the full height of the window instead of ending after the menu.
class AdminSidebarFrame extends StatelessWidget {
  const AdminSidebarFrame({
    super.key,
    required this.header,
    required this.nav,
    required this.footer,
    this.width = 240,
    this.color,
  });

  final Widget header;
  final Widget nav;
  final Widget footer;
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: color,
      child: Column(
        children: [
          header,
          Expanded(child: SingleChildScrollView(child: nav)),
          footer,
        ],
      ),
    );
  }
}

/// The wide layout: sidebar on the left, the page on the right. The row
/// STRETCHES its children, so the sidebar is as tall as the window (a plain
/// Row would centre a short sidebar vertically and leave gaps above and
/// below it on a tall screen).
class AdminWideShell extends StatelessWidget {
  const AdminWideShell({
    super.key,
    required this.sidebar,
    required this.content,
  });

  final Widget sidebar;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sidebar,
        Expanded(child: content),
      ],
    );
  }
}
