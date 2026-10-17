import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../admin_config.dart';
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

enum _Level { enforced, partial, off }

class _Protection {
  const _Protection(this.icon, this.title, this.description, this.level);

  final IconData icon;
  final String title;
  final String description;
  final _Level level;
}

/// What this system actually does today. These used to be on/off switches
/// that only flipped local state (and a "Settings saved." message that saved
/// nothing), so they implied controls that never existed. Each row is now a
/// read-only status, worded to match what is really in place — change a row
/// here only when the underlying behaviour really changes.
final _protections = <_Protection>[
  const _Protection(
    Icons.storage_outlined,
    'Data encryption at rest (AES-256)',
    'Managed by Google Cloud: Firestore and Storage encrypt stored data.',
    _Level.enforced,
  ),
  const _Protection(
    Icons.https_outlined,
    'Encryption in transit (HTTPS / TLS)',
    'All traffic between the apps and Firebase uses TLS.',
    _Level.enforced,
  ),
  const _Protection(
    Icons.admin_panel_settings_outlined,
    'Role-based access',
    'Only accounts in the admins collection can use this portal, and '
        'Firestore rules enforce it on every request.',
    _Level.enforced,
  ),
  const _Protection(
    Icons.history_outlined,
    'Audit logging',
    'Admin actions are recorded by the server and cannot be edited or '
        'deleted from the portal; nothing is deleted automatically.',
    _Level.enforced,
  ),
  _Protection(
    Icons.timer_outlined,
    'Idle session timeout',
    'Enabled: ${kAdminIdleTimeout.inMinutes} minutes. An idle admin gets a '
        'warning ${kAdminIdleWarning.inSeconds} seconds before being signed '
        'out.',
    _Level.enforced,
  ),
  const _Protection(
    Icons.lock_clock_outlined,
    'Failed login lockout',
    'The mobile app locks a username for 15 minutes after 5 failed '
        'attempts, but that check runs in the app, not on the server. '
        'Admin sign-in is rate-limited by Firebase Auth.',
    _Level.partial,
  ),
  const _Protection(
    Icons.phonelink_lock_outlined,
    'Two-factor authentication (2FA)',
    'Not set up. Admin accounts sign in with email and password only.',
    _Level.off,
  ),
];

class AdminSystemSecurity extends StatefulWidget {
  /// Runs the dashboard's confirm-then-logout flow.
  final Future<void> Function(BuildContext context) onLogout;

  const AdminSystemSecurity({super.key, required this.onLogout});

  @override
  State<AdminSystemSecurity> createState() => _AdminSystemSecurityState();
}

class _AdminSystemSecurityState extends State<AdminSystemSecurity> {
  late final AdminPageController _pager = AdminPageController(
    FirebaseFirestore.instance
        .collection('auditLogs')
        .orderBy('timestamp', descending: true),
    pageSize: 5,
  );

  final _names = AdminNameLookup(
    collection: 'admins',
    nameOf: (data) =>
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? data['displayName'] as String
        : data['email'] as String?,
  );

  @override
  void initState() {
    super.initState();
    _pager.addListener(_loadNamesForPage);
  }

  @override
  void dispose() {
    _pager.removeListener(_loadNamesForPage);
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadNamesForPage() async {
    final changed = await _names.ensure(
      _pager.docs.map((d) => auditActorUid(d.data())),
    );
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaps = _protections.where((p) => p.level == _Level.off).length;
    final partial = _protections.where((p) => p.level == _Level.partial).length;

    return Column(
      children: [
        const AdminHeader(
          title: 'System security',
          subtitle:
              'What protects this system today, your current session, and recent admin activity.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statusBanner(theme, gaps, partial),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final protections = _protectionsCard(theme);
                    final session = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sessionCard(context, theme),
                        const SizedBox(height: 16),
                        _passwordCard(theme),
                      ],
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          protections,
                          const SizedBox(height: 16),
                          session,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: protections),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: session),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _activityCard(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _statusBanner(ThemeData theme, int gaps, int partial) {
    final attention = gaps > 0 || partial > 0;
    final color = attention ? Colors.orange : Colors.green;
    final message = attention
        ? 'Security status: needs attention — $gaps protection'
              '${gaps == 1 ? '' : 's'} not enabled'
              '${partial > 0 ? ' and $partial only partly in place' : ''}.'
        : 'Security status: all listed protections are in place.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(
            attention ? Icons.info_outline : Icons.check_circle,
            color: color.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _protectionsCard(ThemeData theme) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Security protocols', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Read-only. These reflect how the system is built, not settings '
            'that can be switched here.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _protections.length; i++) ...[
            if (i > 0) const Divider(height: 24),
            _protectionRow(theme, _protections[i]),
          ],
        ],
      ),
    );
  }

  Widget _protectionRow(ThemeData theme, _Protection p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(p.icon, size: 22, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.description,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _levelBadge(theme, p.level),
      ],
    );
  }

  Widget _levelBadge(ThemeData theme, _Level level) {
    final (label, color, icon) = switch (level) {
      _Level.enforced => ('Enforced', Colors.green, Icons.lock_outline),
      _Level.partial => ('Partial', Colors.orange, Icons.rule),
      _Level.off => ('Not enabled', Colors.grey, Icons.block),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.shade800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(BuildContext context, ThemeData theme) {
    final user = FirebaseAuth.instance.currentUser;
    final fmt = DateFormat('MMM d, y · h:mm a');
    String when(DateTime? d) => d == null ? '—' : fmt.format(d.toLocal());

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your session', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _summaryRow(theme, 'Signed in as', user?.email ?? '—'),
          _summaryRow(
            theme,
            'Last sign-in',
            when(user?.metadata.lastSignInTime),
          ),
          _summaryRow(
            theme,
            'Account created',
            when(user?.metadata.creationTime),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => widget.onLogout(context),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Log out of this session'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
          const SizedBox(height: 6),
          Text(
            'Other devices stay signed in until they log out themselves.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _passwordCard(ThemeData theme) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Password policy', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admin passwords must be at least 8 characters '
                  '(checked when an admin sets a new password).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent admin activity',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'The latest recorded admin actions. The full history is under Audit Logs.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                _th(theme, 'Date & time', flex: 2),
                _th(theme, 'User', flex: 2),
                _th(theme, 'Type', flex: 1),
                _th(theme, 'Details', flex: 4),
              ],
            ),
          ),
          const Divider(height: 1),
          ListenableBuilder(
            listenable: _pager,
            builder: (context, _) {
              if (_pager.error != null && _pager.docs.isEmpty) {
                return SizedBox(
                  height: 160,
                  child: AdminPageError(
                    error: _pager.error!,
                    onRetry: _pager.retry,
                  ),
                );
              }
              if (_pager.loading && _pager.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_pager.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No admin activity recorded yet.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              final fmt = DateFormat('MMM d, y h:mm a');
              return Column(
                children: [
                  for (final doc in _pager.docs) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              (doc.data()['timestamp'] as Timestamp?) == null
                                  ? ''
                                  : fmt.format(
                                      (doc.data()['timestamp'] as Timestamp)
                                          .toDate(),
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _actor(doc.data()),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _typePill(
                                theme,
                                doc.data()['type'] as String? ?? 'UPDATE',
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              doc.data()['action'] as String? ?? '',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  AdminPager(controller: _pager),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _actor(Map<String, dynamic> data) => auditActorLabel(data, _names);

  Widget _typePill(ThemeData theme, String type) {
    final color =
        {
          'CREATE': Colors.green,
          'UPDATE': Colors.blue,
          'DELETE': Colors.red,
          'LOGIN': Colors.purple,
        }[type] ??
        Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }

  Widget _th(ThemeData theme, String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}
