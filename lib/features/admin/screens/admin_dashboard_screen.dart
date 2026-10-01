import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';
import '../theme/admin_theme.dart';
import 'admin_change_password_screen.dart';
import 'admin_login_screen.dart';
import 'sections/admin_main_dashboard.dart';
import 'sections/admin_user_management.dart';
import 'sections/admin_content_management.dart';
import 'sections/admin_notifications.dart';
import 'sections/admin_journal_log_review.dart';
import 'sections/admin_feedback.dart';
import 'sections/admin_reports_analytics.dart';
import 'sections/admin_accounts.dart';
import 'sections/admin_audit_logs.dart';
import 'sections/admin_system_security.dart';

enum AdminSection {
  dashboard,
  userManagement,
  contentManagement,
  notifications,
  journalLogReview,
  feedback,
  reportsAnalytics,
  auditLogs,
  systemSecurity,
  accounts,
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminSection _currentSection = AdminSection.dashboard;

  // Checked once per mount regardless of how this screen was reached (admin
  // portal login, the legacy mobile-app admin login path, or AdminGate on a
  // page refresh) so a newly seeded admin can't skip setting their own
  // password by using a different entry point.
  late final Future<bool> _mustChangePasswordFuture =
      _checkMustChangePassword();

  Future<bool> _checkMustChangePassword() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return AuthService().adminMustChangePassword(uid);
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      await AuthService().signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mustChangePasswordFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const AdminChangePasswordScreen();
        }

        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          body: Row(
            children: [
              _buildSidebar(theme),
              Expanded(child: _buildMainContent(theme)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    // The sidebar used to be a fixed-height Column (logo + Expanded nav +
    // admin tile) that assumed it always gets the full viewport height.
    // Shrinking the browser window (or mid-resize, before layout settles)
    // could give it less height than its fixed-size children (logo header,
    // dividers, admin tile) need, which overflowed instead of adapting.
    // Wrapping it in a scroll view lets it scroll internally at short
    // window heights instead of erroring, while looking identical (no
    // visible scrollbar) whenever everything already fits.
    return Container(
      width: 220,
      color: AdminTheme.maroon,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo area — slightly darker shade to separate it from the nav.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AdminTheme.maroonDark,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/FINE_AID_Logo.png',
                    width: 46,
                    height: 40,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Portal',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFF5F5F5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _sidebarSection('OVERVIEW'),
                  _sidebarItem(
                    AdminSection.dashboard,
                    Icons.dashboard_outlined,
                    'Dashboard',
                  ),
                  _sidebarSection('MANAGEMENT'),
                  _sidebarItem(
                    AdminSection.userManagement,
                    Icons.manage_accounts_outlined,
                    'User Management',
                  ),
                  _sidebarItem(
                    AdminSection.contentManagement,
                    Icons.article_outlined,
                    'Content Management',
                  ),
                  _sidebarItem(
                    AdminSection.notifications,
                    Icons.notifications_outlined,
                    'Notifications',
                  ),
                  _sidebarSection('MONITORING'),
                  _sidebarItem(
                    AdminSection.journalLogReview,
                    Icons.book_outlined,
                    'Journal Log Review',
                  ),
                  _sidebarItem(
                    AdminSection.feedback,
                    Icons.feedback_outlined,
                    'Feedback',
                  ),
                  _sidebarItem(
                    AdminSection.reportsAnalytics,
                    Icons.bar_chart_outlined,
                    'Reports & Analytics',
                  ),
                  _sidebarSection('SYSTEM'),
                  _sidebarItem(
                    AdminSection.auditLogs,
                    Icons.history_outlined,
                    'Audit Logs',
                  ),
                  _sidebarItem(
                    AdminSection.systemSecurity,
                    Icons.security_outlined,
                    'System Security',
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            // Admin info at bottom — the "admin icon" that opens Admin
            // Accounts. The trailing logout button has its own tap target
            // and takes precedence over the tile's onTap when pressed.
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                hoverColor: Colors.white.withValues(alpha: 0.08),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Admin',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFF5F5F5),
                  ),
                ),
                subtitle: Text(
                  'Administrator',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  onPressed: () => _logout(context),
                ),
                onTap: () =>
                    setState(() => _currentSection = AdminSection.accounts),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sidebarSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _sidebarItem(AdminSection section, IconData icon, String label) {
    final isSelected = _currentSection == section;
    final unselectedText = const Color(0xFFF5F5F5).withValues(alpha: 0.85);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? const Border(
                left: BorderSide(color: AdminTheme.accentBright, width: 4),
              )
            : null,
      ),
      // Nav items were rendering directly inside a plain DecoratedBox
      // Container with no Material ancestor, so their hover/ripple never
      // painted — Material(transparency) fixes that without affecting the
      // decoration above.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          hoverColor: Colors.white.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(
            icon,
            color: isSelected ? AdminTheme.maroon : unselectedText,
            size: 18,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected ? AdminTheme.maroon : unselectedText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () => setState(() => _currentSection = section),
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return AdminMainDashboard(
          theme: theme,
          onViewAllActivity: () =>
              setState(() => _currentSection = AdminSection.auditLogs),
        );
      case AdminSection.userManagement:
        return const AdminUserManagement();
      case AdminSection.contentManagement:
        return const AdminContentManagement();
      case AdminSection.notifications:
        return const AdminNotifications();
      case AdminSection.journalLogReview:
        return const AdminJournalLogReview();
      case AdminSection.feedback:
        return const AdminFeedback();
      case AdminSection.reportsAnalytics:
        return const AdminReportsAnalytics();
      case AdminSection.auditLogs:
        return const AdminAuditLogs();
      case AdminSection.systemSecurity:
        return AdminSystemSecurity(onLogout: _logout);
      case AdminSection.accounts:
        return const AdminAccounts();
    }
  }
}
