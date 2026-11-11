import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase/auth_service.dart';
import '../../settings/screens/settings_screen.dart' show confirmLogout;
import '../admin_security_settings.dart';
import '../theme/admin_theme.dart';
import 'admin_change_password_screen.dart';
import 'admin_login_screen.dart';
import 'widgets/admin_idle_guard.dart';
import 'widgets/admin_sidebar_parts.dart';
import 'widgets/admin_shared_widgets.dart' show adminIsNarrow, logAdminAction;
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

  late final Stream<AdminSecuritySettings> _securitySettings =
      AdminSecuritySettings.watch();

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Opens a section; on a narrow window this also closes the drawer.
  void _select(AdminSection section) {
    setState(() => _currentSection = section);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  bool _isConfirmingLogout = false;

  /// Admin-initiated logout only: asks first (same dialog as the user app),
  /// then runs the existing [_logout] unchanged. Forced logouts elsewhere
  /// (AdminGate, rejected login) intentionally don't go through this.
  Future<void> _confirmAndLogout(BuildContext context) async {
    if (_isConfirmingLogout) return;
    _isConfirmingLogout = true;
    final confirmed = await confirmLogout(context);
    _isConfirmingLogout = false;
    if (!confirmed || !context.mounted) return;
    await _logout(context);
  }

  /// Idle timeout: records the sign-out first (the audit callable needs the
  /// still-valid session, and is capped so a slow network can't delay the
  /// sign-out), then runs the same [_logout] with an explanatory notice.
  Future<void> _signOutForInactivity() async {
    if (!mounted) return;
    await logAdminAction(
      'Signed out automatically after inactivity',
      type: 'LOGIN',
      reason: 'idle_timeout',
    ).timeout(const Duration(seconds: 5), onTimeout: () {});
    if (!mounted) return;
    await _logout(context, notice: 'You were signed out due to inactivity.');
  }

  Future<void> _logout(BuildContext context, {String? notice}) async {
    final navigator = Navigator.of(context);
    try {
      await AuthService().signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AdminLoginScreen(notice: notice)),
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
        // The idle-timeout switch and length come from the System Security
        // page's saved settings and apply live (the defaults until loaded).
        return StreamBuilder<AdminSecuritySettings>(
          stream: _securitySettings,
          initialData: AdminSecuritySettings.defaults,
          builder: (context, settings) {
            final security = settings.data ?? AdminSecuritySettings.defaults;
            return AdminIdleGuard(
              enabled: security.idleTimeoutEnabled,
              timeout: security.idleTimeout,
              onIdleTimeout: _signOutForInactivity,
              child: adminIsNarrow(context)
                  ? Scaffold(
                      key: _scaffoldKey,
                      backgroundColor: const Color(0xFFF8F8F8),
                      appBar: AppBar(
                        backgroundColor: AdminTheme.maroon,
                        foregroundColor: Colors.white,
                        title: const Text('Admin Portal'),
                      ),
                      drawer: Drawer(
                        backgroundColor: AdminTheme.maroon,
                        width: 280,
                        child: SafeArea(
                          child: _buildSidebar(theme, inDrawer: true),
                        ),
                      ),
                      body: _buildMainContent(theme),
                    )
                  : Scaffold(
                      backgroundColor: const Color(0xFFF8F8F8),
                      body: AdminWideShell(
                        sidebar: _buildSidebar(theme),
                        content: _buildMainContent(theme),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar(ThemeData theme, {bool inDrawer = false}) {
    // The sidebar fills the full height of the window at any size: logo on
    // top, the menu scrolling in the middle when the window is short, and the
    // admin tile pinned to the bottom (see AdminSidebarFrame).
    return AdminSidebarFrame(
      width: inDrawer ? double.infinity : 240,
      color: AdminTheme.maroon,
      header: Column(
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
                Expanded(
                  child: Text(
                    'Admin Portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFF5F5F5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
        ],
      ),
      nav: Padding(
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
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          // Admin info at bottom: name, role and the logout icon on one
          // row. The tile opens Admin Accounts; logout has its own target.
          AdminNavFooter(
            onOpenAccount: () => _select(AdminSection.accounts),
            onLogout: () => _confirmAndLogout(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarSection(String label) =>
      AdminNavSection(label, first: label == 'OVERVIEW');

  Widget _sidebarItem(AdminSection section, IconData icon, String label) =>
      AdminNavItem(
        icon: icon,
        label: label,
        selected: _currentSection == section,
        onTap: () => _select(section),
      );
  Widget _buildMainContent(ThemeData theme) {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return AdminMainDashboard(
          theme: theme,
          onViewAllActivity: () => _select(AdminSection.auditLogs),
          onOpenUsers: () => _select(AdminSection.userManagement),
          // There is no separate AI-scan page: scan counts and performance
          // live on Reports & Analytics.
          onOpenAiScans: () => _select(AdminSection.reportsAnalytics),
          // Pending escalations are journal entries where the user said they
          // weren't feeling better, listed on Journal Log Review.
          onOpenEscalations: () => _select(AdminSection.journalLogReview),
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
        return AdminReportsAnalytics(
          onOpenUsers: () => _select(AdminSection.userManagement),
          // AI scans are saved as journal entries, listed on Journal Log
          // Review, which is also where auto-referrals are handled.
          onOpenAiScans: () => _select(AdminSection.journalLogReview),
          onOpenAutoReferrals: () => _select(AdminSection.journalLogReview),
          // The performance figure and its graph are on the Dashboard.
          onOpenPerformance: () => _select(AdminSection.dashboard),
        );
      case AdminSection.auditLogs:
        return const AdminAuditLogs();
      case AdminSection.systemSecurity:
        return AdminSystemSecurity(onLogout: _confirmAndLogout);
      case AdminSection.accounts:
        return const AdminAccounts();
    }
  }
}
