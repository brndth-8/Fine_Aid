import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../admin_config.dart';
import '../../admin_security_settings.dart';
import '../../admin_two_step.dart' show watchAdminTwoStepRequired;
import '../widgets/admin_name_lookup.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';
import '../widgets/admin_two_step_card.dart';

/// The idle-timeout duration can only be changed while the timeout switch is
/// OFF: turn it off, pick the length, then turn it back on to use it. Never
/// while the setting is still loading or a save is in progress.
bool idleDurationEditable({
  required bool loaded,
  required bool saving,
  required bool idleEnabled,
}) => loaded && !saving && !idleEnabled;

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
/// nothing). Rows here are read-only because they describe how the platform is
/// built and can't be switched from a page; the one real setting, the idle
/// session timeout, is the interactive row at the top of the card (saved to
/// Firestore and applied by the portal). Change a row here only when the
/// underlying behaviour really changes.
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
    'Admin access needs a server-set "admin" claim on the sign-in account '
        'AND an entry in the admins collection. Neither can be granted from '
        'a browser, and Firestore rules and every admin function check both.',
    _Level.enforced,
  ),
  const _Protection(
    Icons.fact_check_outlined,
    'Admin sign-in monitoring',
    'Admin sign-ins, refused sign-ins by non-admins, and failed attempts on '
        'an admin account are written to the audit log (type LOGIN).',
    _Level.enforced,
  ),
  const _Protection(
    Icons.history_outlined,
    'Audit logging',
    'Admin actions are recorded by the server and cannot be edited or '
        'deleted from the portal; nothing is deleted automatically.',
    _Level.enforced,
  ),
];

/// The two-factor row follows the real setting (appConfig/adminAuth): enforced
/// once admins are required to use an authenticator code, otherwise only
/// available (each admin can enrol, but nobody has to yet).
_Protection _twoStepProtection(bool required) => required
    ? const _Protection(
        Icons.phonelink_lock_outlined,
        'Two-factor authentication (2FA)',
        'Every admin signs in with a code from an authenticator app as well as '
            'their password. The sign-in rules and every admin function check '
            'it.',
        _Level.enforced,
      )
    : const _Protection(
        Icons.phonelink_lock_outlined,
        'Two-factor authentication (2FA)',
        'Available but not required: admins can set up an authenticator app '
            '(Two-step verification card), but can still sign in with just a '
            'password. Switch on "Require a code for every admin" to enforce '
            'it.',
        _Level.partial,
      );

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

  late final Stream<AdminSecuritySettings> _settingsStream =
      AdminSecuritySettings.watch();
  late final Stream<bool> _twoStepStream = watchAdminTwoStepRequired();
  bool _savingSetting = false;
  bool _savingLockout = false;

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
    return StreamBuilder<AdminSecuritySettings>(
      stream: _settingsStream,
      builder: (context, settingsSnap) => StreamBuilder<bool>(
        stream: _twoStepStream,
        builder: (context, twoStepSnap) =>
            _page(context, theme, settingsSnap, twoStepSnap.data),
      ),
    );
  }

  Widget _page(
    BuildContext context,
    ThemeData theme,
    AsyncSnapshot<AdminSecuritySettings> settingsSnap,
    bool? twoStepRequired,
  ) {
    // Null until the saved setting has loaded; the defaults stand in for the
    // banner only, and the controls stay disabled meanwhile.
    final settings = settingsSnap.data ?? AdminSecuritySettings.defaults;
    // The 2FA row joins once its setting has loaded (no flash of "needs
    // attention" before then).
    final protections = [
      ..._protections,
      if (twoStepRequired != null) _twoStepProtection(twoStepRequired),
    ];
    final gaps =
        protections.where((p) => p.level == _Level.off).length +
        (settings.idleTimeoutEnabled ? 0 : 1) +
        (settings.lockoutEnabled ? 0 : 1);
    final partial = protections.where((p) => p.level == _Level.partial).length;

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
                    final protectionsCard = _protectionsCard(
                      theme,
                      settingsSnap,
                      protections,
                    );
                    // Wide: the right column is as tall as the protections
                    // card and Password policy grows to fill what is left, so
                    // there is no blank space under it.
                    Widget sessionColumn({required bool fill}) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sessionCard(context, theme),
                        const SizedBox(height: 16),
                        const AdminTwoStepCard(),
                        const SizedBox(height: 16),
                        if (fill)
                          Expanded(child: _passwordCard(theme))
                        else
                          _passwordCard(theme),
                      ],
                    );
                    final session = sessionColumn(fill: false);
                    if (!wide) {
                      return Column(
                        children: [
                          protectionsCard,
                          const SizedBox(height: 16),
                          session,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: protectionsCard),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: sessionColumn(fill: true)),
                        ],
                      ),
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

  Widget _protectionsCard(
    ThemeData theme,
    AsyncSnapshot<AdminSecuritySettings> settingsSnap,
    List<_Protection> protections,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Security protocols', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'The idle session timeout can be switched here; it is saved and '
            'applies to every admin. The other rows show how the system is '
            'built and are read-only.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _idleTimeoutRow(theme, settingsSnap),
          const Divider(height: 24),
          _lockoutRow(theme, settingsSnap),
          for (final p in protections) ...[
            const Divider(height: 24),
            _protectionRow(theme, p),
          ],
        ],
      ),
    );
  }

  /// The one real setting: switch the idle timeout on/off and pick how long.
  /// The switch always shows the SAVED value (from Firestore); a change is
  /// sent to the server and only reported as done once it has been saved, so
  /// a failure leaves the switch where it was.
  Widget _idleTimeoutRow(
    ThemeData theme,
    AsyncSnapshot<AdminSecuritySettings> snap,
  ) {
    final loaded = snap.hasData;
    final s = snap.data ?? AdminSecuritySettings.defaults;
    final busy = _savingSetting || !loaded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.timer_outlined, size: 22, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Idle session timeout',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                snap.hasError
                    ? "Couldn't load this setting. Try reloading the page."
                    : !loaded
                    ? 'Loading…'
                    : s.idleTimeoutEnabled
                    ? 'On: an idle admin is signed out after ${s.idleTimeoutMinutes} '
                          'minutes, with a warning ${kAdminIdleWarning.inSeconds} '
                          'seconds before.'
                    : 'Off: admins stay signed in until they log out. Pick the '
                          'length below, then switch it back on to use it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: snap.hasError ? Colors.redAccent : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Sign out after', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: s.idleTimeoutMinutes,
                    isDense: true,
                    items: [
                      for (final m in AdminSecuritySettings.allowedMinutes)
                        DropdownMenuItem(value: m, child: Text('$m minutes')),
                    ],
                    // Locked while the timeout is ON: switch it off first.
                    onChanged:
                        idleDurationEditable(
                          loaded: loaded,
                          saving: _savingSetting,
                          idleEnabled: s.idleTimeoutEnabled,
                        )
                        ? (m) => _applySetting(
                            enabled: false,
                            minutes: m ?? s.idleTimeoutMinutes,
                            durationOnly: true,
                          )
                        : null,
                  ),
                ],
              ),
              if (loaded && s.idleTimeoutEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Switch the idle timeout off to change the length.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_savingSetting)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Switch(
                  value: s.idleTimeoutEnabled,
                  onChanged: busy
                      ? null
                      : (on) => _applySetting(
                          enabled: on,
                          minutes: s.idleTimeoutMinutes,
                        ),
                ),
              ],
            ),
            _levelBadge(
              theme,
              loaded && s.idleTimeoutEnabled ? _Level.enforced : _Level.off,
              enforcedLabel: 'Active',
            ),
          ],
        ),
      ],
    );
  }

  /// The failed-login lockout: switch it on/off and choose how many wrong
  /// passwords are allowed and for how long the account is then locked. The
  /// app's sign-in screen reads this setting before every attempt, so what is
  /// saved here is what runs. Like the idle timeout, the switch shows the
  /// SAVED value and a failed save leaves it where it was.
  Widget _lockoutRow(
    ThemeData theme,
    AsyncSnapshot<AdminSecuritySettings> snap,
  ) {
    final loaded = snap.hasData;
    final s = snap.data ?? AdminSecuritySettings.defaults;
    final busy = _savingLockout || !loaded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_clock_outlined, size: 22, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed login lockout',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                snap.hasError
                    ? "Couldn't load this setting. Try reloading the page."
                    : !loaded
                    ? 'Loading…'
                    : s.lockoutEnabled
                    ? 'Active: after ${s.lockoutMaxAttempts} wrong passwords an '
                          'account is locked for ${s.lockoutMinutes} minutes. '
                          "The app's sign-in screen reads this before every "
                          'attempt.'
                    : 'Off: accounts are never locked for wrong passwords.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: snap.hasError ? Colors.redAccent : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lock after', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: s.lockoutMaxAttempts,
                        isDense: true,
                        items: [
                          for (final a
                              in AdminSecuritySettings.allowedLockoutAttempts)
                            DropdownMenuItem(
                              value: a,
                              child: Text('$a wrong passwords'),
                            ),
                        ],
                        onChanged: busy || !s.lockoutEnabled
                            ? null
                            : (a) => _applyLockout(
                                enabled: true,
                                attempts: a ?? s.lockoutMaxAttempts,
                                minutes: s.lockoutMinutes,
                              ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Locked for', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: s.lockoutMinutes,
                        isDense: true,
                        items: [
                          for (final m
                              in AdminSecuritySettings.allowedLockoutMinutes)
                            DropdownMenuItem(
                              value: m,
                              child: Text('$m minutes'),
                            ),
                        ],
                        onChanged: busy || !s.lockoutEnabled
                            ? null
                            : (m) => _applyLockout(
                                enabled: true,
                                attempts: s.lockoutMaxAttempts,
                                minutes: m ?? s.lockoutMinutes,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_savingLockout)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Switch(
                  value: s.lockoutEnabled,
                  onChanged: busy
                      ? null
                      : (on) => _applyLockout(
                          enabled: on,
                          attempts: s.lockoutMaxAttempts,
                          minutes: s.lockoutMinutes,
                        ),
                ),
              ],
            ),
            _levelBadge(
              theme,
              loaded && s.lockoutEnabled ? _Level.enforced : _Level.off,
              enforcedLabel: 'Active',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyLockout({
    required bool enabled,
    required int attempts,
    required int minutes,
  }) async {
    if (_savingLockout) return;
    setState(() => _savingLockout = true);
    String message;
    try {
      final saved = await AdminSecuritySettings.save(
        lockoutEnabled: enabled,
        lockoutMaxAttempts: attempts,
        lockoutMinutes: minutes,
      );
      message = saved.lockoutEnabled
          ? 'Lockout is on: ${saved.lockoutMaxAttempts} wrong passwords lock '
                'an account for ${saved.lockoutMinutes} minutes.'
          : 'Lockout is off.';
    } on FirebaseFunctionsException catch (e) {
      message =
          "Couldn't save the setting: ${e.message ?? e.code}. It was not changed.";
    } catch (_) {
      message = "Couldn't reach the server. The setting was not changed.";
    }
    if (!mounted) return;
    setState(() => _savingLockout = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _applySetting({
    required bool enabled,
    required int minutes,
    bool durationOnly = false,
  }) async {
    if (_savingSetting) return;
    setState(() => _savingSetting = true);
    String message;
    try {
      final saved = await AdminSecuritySettings.save(
        idleTimeoutEnabled: enabled,
        idleTimeoutMinutes: minutes,
      );
      message = saved.idleTimeoutEnabled
          ? 'Idle timeout is on: admins are signed out after ${saved.idleTimeoutMinutes} '
                'minutes of inactivity.'
          : durationOnly
          ? 'Length saved: ${saved.idleTimeoutMinutes} minutes. The idle '
                'timeout is still off; switch it on to use it.'
          : 'Idle timeout is off.';
    } on FirebaseFunctionsException catch (e) {
      message =
          "Couldn't save the setting: ${e.message ?? e.code}. It was not changed.";
    } catch (_) {
      message = "Couldn't reach the server. The setting was not changed.";
    }
    if (!mounted) return;
    setState(() => _savingSetting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _levelBadge(
    ThemeData theme,
    _Level level, {
    String enforcedLabel = 'Enforced',
  }) {
    final (label, color, icon) = switch (level) {
      _Level.enforced => (enforcedLabel, Colors.green, Icons.lock_outline),
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
          // One horizontal scroll for header + rows so a phone keeps the
          // columns readable instead of squeezing them.
          AdminHScroll(
            minWidth: 640,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                                    (doc.data()['timestamp'] as Timestamp?) ==
                                            null
                                        ? ''
                                        : fmt.format(
                                            (doc.data()['timestamp']
                                                    as Timestamp)
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
