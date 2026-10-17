import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../../../../services/firebase/auth_service.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminUserManagement extends StatefulWidget {
  const AdminUserManagement({super.key});

  @override
  State<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagement> {
  late final AdminPageController _pager = AdminPageController(
    FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true),
  );

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // Users with a deactivate/cancel/activate request in flight, so a second
  // tap can't start a duplicate one.
  final Set<String> _busyUsers = {};

  /// Must match DEACTIVATION_GRACE_DAYS in functions/index.js (the server
  /// decides the real date; this only words the confirmation).
  static const int _graceDays = 7;

  String _longDate(DateTime d) => DateFormat('MMMM d, y').format(d);

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _confirmDeactivate(String uid, String username) async {
    if (_busyUsers.contains(uid)) return;
    setState(() => _busyUsers.add(uid));
    try {
      final approx = DateTime.now().add(const Duration(days: _graceDays));
      final confirmed = await adminConfirm(
        context,
        title: 'Deactivate account?',
        message:
            '$username will be notified in the app now and will lose access in '
            '$_graceDays days (around ${_longDate(approx)}). '
            'Their data will not be deleted.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed) return;
      await _scheduleDeactivation(uid, username);
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  /// Notice first, schedule second — done together server-side, so if the
  /// notice can't be sent nothing is scheduled and the admin can retry.
  Future<void> _scheduleDeactivation(String uid, String username) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('scheduleAccountDeactivation')
          .call<Map<Object?, Object?>>({'uid': uid});
      final when = DateTime.fromMillisecondsSinceEpoch(
        (result.data['deactivateAt'] as num).toInt(),
      );
      if (result.data['alreadyScheduled'] == true) {
        _snack('$username is already scheduled for ${_longDate(when)}.');
        return;
      }
      // The audit entry is written by the function, in the same transaction
      // as the notice and the schedule.
      _snack(
        '$username was notified. Deactivation is scheduled for '
        '${_longDate(when)}.',
      );
    } on FirebaseFunctionsException catch (e) {
      _snack(
        'Could not schedule the deactivation: ${e.message ?? e.code}. '
        'Nothing was changed.',
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _scheduleDeactivation(uid, username),
        ),
      );
    } catch (_) {
      _snack(
        'Could not reach the server. Nothing was changed.',
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _scheduleDeactivation(uid, username),
        ),
      );
    }
  }

  Future<void> _cancelDeactivation(String uid, String username) async {
    if (_busyUsers.contains(uid)) return;
    setState(() => _busyUsers.add(uid));
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelAccountDeactivation')
          .call<Map<Object?, Object?>>({'uid': uid});
      _snack(
        'Deactivation cancelled. $username was told their account stays active.',
      );
    } on FirebaseFunctionsException catch (e) {
      _snack('Could not cancel: ${e.message ?? e.code}');
    } catch (_) {
      _snack('Could not reach the server. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  Future<void> _activate(String uid, String username) async {
    if (_busyUsers.contains(uid)) return;
    setState(() => _busyUsers.add(uid));
    try {
      // Deactivation disables the user's sign-in account, so it has to be
      // re-enabled there too, not just on the profile. The function does both
      // and writes the audit entry.
      await FirebaseFunctions.instance
          .httpsCallable('reactivateAccount')
          .call<Map<Object?, Object?>>({'uid': uid});
      _snack('$username can sign in again.');
    } on FirebaseFunctionsException catch (e) {
      _snack('Could not activate $username: ${e.message ?? e.code}');
    } catch (_) {
      _snack('Could not reach the server. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  Future<void> _editUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    final emailController = TextEditingController(
      text: data['email'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: data['phoneNumber'] as String? ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${data['username'] ?? 'user'}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
        'email': emailController.text.trim(),
        'phoneNumber': phoneController.text.trim(),
      });
      logAdminAction('Edited user ${data['username'] ?? doc.id}');
    }
    emailController.dispose();
    phoneController.dispose();
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates the Auth account on a throwaway secondary [FirebaseApp]
  /// instance instead of the default one — calling
  /// createUserWithEmailAndPassword on the default app signs the caller in
  /// as the newly created user, which would kick the admin out of their own
  /// session.
  Future<void> _createUserAccount({
    required String username,
    required String phoneNumber,
    required String password,
  }) async {
    final exactUsername = username.trim();

    final taken = await AuthService().isUsernameTaken(exactUsername);
    if (taken) {
      throw 'That username is already taken.';
    }

    // The generated Auth email just needs to be a valid, stable address —
    // lowercasing it here is unrelated to username case-sensitivity, which
    // is enforced by the `usernames` doc ID below.
    final generatedEmail = '${exactUsername.toLowerCase()}@fineaid.app';

    final secondaryApp = await Firebase.initializeApp(
      name: 'admin_create_user_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: generatedEmail,
        password: password,
      );
      final uid = credential.user!.uid;

      final secondaryFirestore = FirebaseFirestore.instanceFor(
        app: secondaryApp,
      );
      await secondaryFirestore.collection('users').doc(uid).set({
        'username': exactUsername,
        'email': generatedEmail,
        'phoneNumber': phoneNumber,
        'verificationMethod': 'phone',
        'createdAt': FieldValue.serverTimestamp(),
        'phoneVerified': false,
        'onboardingComplete': false,
        'createdByAdmin': true,
      });
      await secondaryFirestore.collection('usernames').doc(exactUsername).set({
        'email': generatedEmail,
        'uid': uid,
        'usernameExact': exactUsername,
      });

      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    logAdminAction('Created user "$username"', type: 'CREATE');
  }

  Future<void> _addUser() async {
    final usernameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController(
      text: _generateTempPassword(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add user'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      helperText: 'Share this with the user directly.',
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        error = null;
                      });
                      try {
                        await _createUserAccount(
                          username: usernameController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          password: passwordController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'User "${usernameController.text.trim()}" created.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          error = e.toString();
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AdminHeader(
          title: 'User management',
          subtitle:
              'View, modify, or deactivate user accounts as needed for security or policy compliance.',
          action: ElevatedButton.icon(
            onPressed: _addUser,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add user'),
          ),
        ),
        Expanded(
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'All users (${_pager.total ?? docs.length} total)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                _tableHeader(context, 'User', flex: 2),
                                _tableHeader(context, 'Email', flex: 3),
                                _tableHeader(context, 'Joined'),
                                _tableHeader(context, 'Status', flex: 2),
                                _tableHeader(context, 'Actions', flex: 2),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...docs.map((doc) {
                            final data = doc.data();
                            final username =
                                data['username'] as String? ?? 'Unknown';
                            final email = data['email'] as String? ?? '';
                            final ts = data['createdAt'] as Timestamp?;
                            final joined = ts != null
                                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                                : '';
                            // Deactivated outright, or past its scheduled date
                            // (the app already blocks sign-in at that point;
                            // the hourly job just catches the flag up).
                            final deactivateAt =
                                (data['deactivateAt'] as Timestamp?)?.toDate();
                            final isDeactivated =
                                data['deactivated'] == true ||
                                (deactivateAt != null &&
                                    !deactivateAt.isAfter(DateTime.now()));
                            final isScheduled =
                                !isDeactivated && deactivateAt != null;
                            final busy = _busyUsers.contains(doc.id);

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              child: Text(
                                                username.isNotEmpty
                                                    ? username[0].toUpperCase()
                                                    : '?',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              username,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          email,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          joined,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDeactivated
                                                  ? Colors.grey.shade100
                                                  : isScheduled
                                                  ? Colors.orange.shade50
                                                  : Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isDeactivated
                                                  ? 'Inactive'
                                                  : isScheduled
                                                  ? 'Deactivates ${DateFormat('MMM d').format(deactivateAt)}'
                                                  : 'Active',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: isDeactivated
                                                        ? Colors.grey.shade700
                                                        : isScheduled
                                                        ? Colors.orange.shade800
                                                        : Colors.green.shade800,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  _editUser(doc, data),
                                              child: Text(
                                                'Edit',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.black,
                                                    ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => isDeactivated
                                                        ? _activate(
                                                            doc.id,
                                                            username,
                                                          )
                                                        : isScheduled
                                                        ? _cancelDeactivation(
                                                            doc.id,
                                                            username,
                                                          )
                                                        : _confirmDeactivate(
                                                            doc.id,
                                                            username,
                                                          ),
                                              child: Text(
                                                busy
                                                    ? 'Working…'
                                                    : isDeactivated
                                                    ? 'Activate'
                                                    : isScheduled
                                                    ? 'Cancel'
                                                    : 'Deactivate',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: isDeactivated
                                                          ? Colors
                                                                .green
                                                                .shade800
                                                          : isScheduled
                                                          ? Colors
                                                                .orange
                                                                .shade800
                                                          : Colors.red.shade700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                          AdminPager(controller: _pager),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(BuildContext context, String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.black),
      ),
    );
  }
}
