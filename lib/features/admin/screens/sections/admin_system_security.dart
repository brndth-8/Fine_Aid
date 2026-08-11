import 'package:flutter/material.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminSystemSecurity extends StatefulWidget {
  final Future<void> Function(BuildContext context) onLogout;

  const AdminSystemSecurity({super.key, required this.onLogout});

  @override
  State<AdminSystemSecurity> createState() => _AdminSystemSecurityState();
}

class _AdminSystemSecurityState extends State<AdminSystemSecurity> {
  bool _encryption = true;
  bool _tls = true;
  bool _twoFa = true;
  bool _sessionTimeout = true;
  bool _loginLockout = true;
  bool _auditRetention = true;
  final _sessionTimeoutController = TextEditingController(text: '30');
  final _maxSessionsController = TextEditingController(text: '1');

  @override
  void dispose() {
    _sessionTimeoutController.dispose();
    _maxSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'System security management',
          subtitle:
              'Overview core security settings including data encryption protocols and session management.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Security Status: Good. All critical protocols are active.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security protocols',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _securityToggle(
                              theme,
                              'Data encryption (AES-256)',
                              'Encrypts all personal and health-related data at rest',
                              _encryption,
                              (v) => setState(() => _encryption = v),
                            ),
                            _securityToggle(
                              theme,
                              'TLS / HTTPS in transit',
                              'Secures all data transmitted between app and server',
                              _tls,
                              (v) => setState(() => _tls = v),
                            ),
                            _securityToggle(
                              theme,
                              'Two-factor authentication (2FA)',
                              'Required for all admin portal logins',
                              _twoFa,
                              (v) => setState(() => _twoFa = v),
                            ),
                            _securityToggle(
                              theme,
                              'Auto session timeout',
                              'Logs out inactive users to prevent unauthorized access',
                              _sessionTimeout,
                              (v) => setState(() => _sessionTimeout = v),
                            ),
                            _securityToggle(
                              theme,
                              'Failed login lockout',
                              'Locks account after 5 consecutive failed attempts',
                              _loginLockout,
                              (v) => setState(() => _loginLockout = v),
                            ),
                            _securityToggle(
                              theme,
                              'Audit log retention (12 months)',
                              'Maintains complete records of all system activities',
                              _auditRetention,
                              (v) => setState(() => _auditRetention = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Session management',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Session timeout (minutes)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _sessionTimeoutController,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Max concurrent sessions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _maxSessionsController,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Settings saved.'),
                                      ),
                                    );
                                  },
                                  child: const Text('Save settings'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security summary',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                _summaryRow('Last login', 'Today'),
                                _summaryRow('Active sessions', '1 / 1'),
                                _summaryRow('Failed logins today', '0'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => widget.onLogout(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Force logout all sessions',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _securityToggle(
    ThemeData theme,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
