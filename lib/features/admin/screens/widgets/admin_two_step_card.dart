import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../admin_two_step.dart';
import '../../theme/admin_theme.dart';
import 'admin_shared_widgets.dart';

/// System Security card for two-step verification: set up (or remove) the
/// signed-in admin's authenticator app, and switch on "require it for every
/// admin". The switch can only be turned on by an admin who is signed in with
/// a code right now (the server checks too), so nobody can lock themselves out.
class AdminTwoStepCard extends StatefulWidget {
  const AdminTwoStepCard({super.key});

  @override
  State<AdminTwoStepCard> createState() => _AdminTwoStepCardState();
}

class _AdminTwoStepCardState extends State<AdminTwoStepCard> {
  late final Stream<bool> _requiredStream = watchAdminTwoStepRequired();

  List<MultiFactorInfo>? _factors; // null until loaded
  bool _withCode = false; // this sign-in used an authenticator code
  bool _loadFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final factors = await enrolledAuthenticators(user);
      final token = await user.getIdTokenResult();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _withCode = signedInWithAuthenticator(token.claims);
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setUp() async {
    if (_busy) return;
    setState(() => _busy = true);
    final enrolled = await showAuthenticatorSetup(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (enrolled) {
      await _load();
      if (!mounted) return;
      await adminConfirm(
        context,
        title: 'Authenticator app set up',
        message:
            'From your next sign-in you will be asked for a code from the '
            'app. Sign out and back in once now to check that it works; you '
            'can then require it for every admin.',
        confirmLabel: 'OK',
      );
    }
  }

  Future<void> _remove(bool required) async {
    final factors = _factors;
    if (_busy || factors == null || factors.isEmpty) return;
    if (required) {
      _say('Stop requiring it for admins before removing your authenticator.');
      return;
    }
    final ok = await adminConfirm(
      context,
      title: 'Remove your authenticator app?',
      message:
          'You will sign in with just your password until you set one up '
          'again.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.currentUser!.multiFactor.unenroll(
        factorUid: factors.first.uid,
      );
      await _load();
      if (mounted) _say('Authenticator app removed.');
    } catch (e) {
      if (mounted) _say(describeTwoStepError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRequired(bool on) async {
    if (_busy) return;
    final ok = await adminConfirm(
      context,
      title: on ? 'Require a code for every admin?' : 'Stop requiring a code?',
      message: on
          ? 'Every admin will have to set up an authenticator app and sign '
                'in with its code. Until they do, the portal stays closed to '
                'them (they are walked through the set-up). You are signed in '
                'with a code, so you stay in.'
          : 'Admins will be able to sign in with just their password again.',
      confirmLabel: on ? 'Require' : 'Stop requiring',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await setAdminTwoStepRequired(on);
      if (mounted) {
        _say(
          on
              ? 'A code is now required for every admin.'
              : 'No longer required.',
        );
      }
    } catch (e) {
      if (mounted) _say(describeTwoStepError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factors = _factors;
    final enrolled = factors != null && factors.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: StreamBuilder<bool>(
        stream: _requiredStream,
        initialData: false,
        builder: (context, snap) {
          final required = snap.data ?? false;
          // On: only with a code in hand. Off: always allowed (to undo it).
          final canSwitch = !_busy && (required || (enrolled && _withCode));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Two-step verification', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sign in with a code from an authenticator app as well as '
                'your password.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 14),
              if (_loadFailed)
                Row(
                  children: [
                    const Expanded(
                      child: Text("Couldn't check your authenticator app."),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )
              else if (factors == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      enrolled ? Icons.check_circle : Icons.info_outline,
                      size: 18,
                      color: enrolled ? Colors.green.shade600 : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        enrolled
                            ? 'Your authenticator app is set up.'
                            : 'Your authenticator app is not set up.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (enrolled)
                      TextButton(
                        onPressed: _busy ? null : () => _remove(required),
                        child: const Text('Remove'),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.maroon,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _busy ? null : _setUp,
                        child: const Text('Set up'),
                      ),
                  ],
                ),
              const Divider(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Require a code for every admin',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          required
                              ? 'On. Every admin signs in with a code.'
                              : !enrolled
                              ? 'Set up your own authenticator app first.'
                              : !_withCode
                              ? 'Sign out and sign in with your code first, '
                                    'then you can switch this on.'
                              : 'Off. Other admins would have to set up an '
                                    'authenticator app at their next sign-in.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: required,
                    onChanged: canSwitch ? _setRequired : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
