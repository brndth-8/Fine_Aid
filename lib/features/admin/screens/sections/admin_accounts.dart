import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/admin_shared_widgets.dart';

/// Lists administrator accounts. Never shows a real password or hash —
/// there isn't one to show: Firebase Auth stores and hashes passwords
/// server-side, and the client SDK has no way to read them back. The
/// "Password" row is always the same fixed mask.
class AdminAccounts extends StatefulWidget {
  const AdminAccounts({super.key});

  @override
  State<AdminAccounts> createState() => _AdminAccountsState();
}

class _AdminAccountsState extends State<AdminAccounts> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _adminsStream =
      FirebaseFirestore.instance.collection('admins').snapshots();

  @override
  void initState() {
    super.initState();
    logAdminAction('Viewed Admin Accounts');
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      logAdminAction('Sent password reset for $email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reset email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'Admin Account',
          subtitle: 'Administrator accounts for this portal.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _adminsStream,
            builder: (context, snapshot) {
              final fallback = adminSnapshotFallback(snapshot);
              if (fallback != null) return fallback;

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No admin accounts found.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: docs
                      .map(
                        (doc) => _AdminAccountCard(
                          name: _displayName(doc.id, doc.data()),
                          email: doc.data()['email'] as String? ?? '',
                          onResetPassword: _resetPassword,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _displayName(String uid, Map<String, dynamic> data) {
    final explicit = data['displayName'] as String?;
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    final email = data['email'] as String?;
    if (email != null && email.contains('@')) return email.split('@').first;
    return uid;
  }
}

/// One admin account rendered as a labeled list of fields (Username,
/// Email Address, Password, Action) instead of a table row.
class _AdminAccountCard extends StatelessWidget {
  final String name;
  final String email;
  final ValueChanged<String> onResetPassword;

  const _AdminAccountCard({
    required this.name,
    required this.email,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 16),
          _fieldRow(theme, 'Username', name),
          const Divider(height: 20),
          _fieldRow(
            theme,
            'Email Address',
            email.isEmpty ? '(not on file)' : email,
          ),
          const Divider(height: 20),
          _fieldRow(
            theme,
            'Password',
            null,
            valueWidget: const _MaskedPassword(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: email.isEmpty ? null : () => onResetPassword(email),
              icon: const Icon(Icons.lock_reset, size: 16),
              label: const Text('Reset / Change Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(
    ThemeData theme,
    String label,
    String? value, {
    Widget? valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
          ),
        ),
        Expanded(
          child:
              valueWidget ??
              Text(value ?? '', style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// Always the same fixed-length dot mask — this system has no real
/// password or hash to reveal, so there's nothing to leak by design.
class _MaskedPassword extends StatelessWidget {
  const _MaskedPassword();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Text(
        '••••••••',
        style: TextStyle(color: Colors.black54, letterSpacing: 2),
      ),
    );
  }
}
