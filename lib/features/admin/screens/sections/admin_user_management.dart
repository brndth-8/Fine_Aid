import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../../../services/firebase/email_reservation.dart';
import '../widgets/admin_pagination.dart';
import '../widgets/admin_shared_widgets.dart';
import '../widgets/admin_user_info.dart';

class AdminUserManagement extends StatefulWidget {
  const AdminUserManagement({super.key});

  @override
  State<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagement> {
  late final AdminPageController _pager = AdminPageController(
    FirebaseFirestore.instance
        .collection('users')
        // Only finished registrations — filtered here in the query so
        // pages and the total count never include half-made accounts.
        .where('registrationComplete', isEqualTo: true)
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

  /// Sends the edited fields to the server, which validates them, keeps the
  /// username and email unique (moving their reservations) and audit-logs
  /// which fields changed. Only fields that differ are sent. Returns the
  /// names of the fields that were saved. Throws a readable message.
  Future<List<String>> _saveProfile(
    String uid,
    Map<String, Object?> changes,
  ) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('updateUserProfile')
          .call<Map<Object?, Object?>>({'uid': uid, 'changes': changes});
      return [...(result.data['updated'] as List? ?? const []).cast<String>()];
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? "Couldn't save the changes (${e.code}).";
    }
  }

  /// Edit dialog: every field an admin may change — username, first and last
  /// name, date of birth, gender, email and phone. (The underage
  /// acknowledgment, registration date and account type are records, not
  /// settings, so they stay read-only in View details.)
  Future<void> _editUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    final username = TextEditingController(text: text('username'));
    final firstName = TextEditingController(text: text('firstName'));
    final lastName = TextEditingController(text: text('lastName'));
    final email = TextEditingController(text: text('recoveryEmail'));
    final phone = TextEditingController(text: text('phoneNumber'));
    DateTime? dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
    final dobOriginal = dob;
    final dobField = TextEditingController(
      text: dob == null ? '' : DateFormat('MMM d, y').format(dob),
    );
    String? gender = const {'male', 'female', 'other'}.contains(data['gender'])
        ? data['gender'] as String
        : null;
    final genderOriginal = gender;
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? error;

    String? nameRule(String? v, String label) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null; // untouched / not set
      return RegExp(r"^[\p{L}][\p{L} .'\-]*$", unicode: true).hasMatch(t)
          ? null
          : '$label: letters, spaces, - \' . only';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDob() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: dob ?? DateTime(now.year - 18, now.month, now.day),
              firstDate: DateTime(1900),
              lastDate: DateUtils.dateOnly(now),
            );
            if (picked == null) return;
            setDialogState(() {
              dob = picked;
              dobField.text = DateFormat('MMM d, y').format(picked);
              error = null;
            });
          }

          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            // Send only what changed.
            final changes = <String, Object?>{};
            void diff(String key, String now, String before) {
              if (now.trim() != before) changes[key] = now.trim();
            }

            diff('username', username.text, text('username'));
            diff('firstName', firstName.text, text('firstName'));
            diff('lastName', lastName.text, text('lastName'));
            diff('phone', phone.text, text('phoneNumber'));
            if (normalizeEmail(email.text) !=
                normalizeEmail(text('recoveryEmail'))) {
              changes['email'] = email.text.trim();
            }
            if (dob != null && dob != dobOriginal) {
              changes['dateOfBirthMs'] = dob!.millisecondsSinceEpoch;
            }
            if (gender != null && gender != genderOriginal) {
              changes['gender'] = gender;
            }
            if (changes.isEmpty) {
              Navigator.of(dialogContext).pop();
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final saved = await _saveProfile(doc.id, changes);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _snack(
                saved.isEmpty ? 'Nothing needed saving.' : 'User updated.',
              );
            } catch (e) {
              setDialogState(() {
                saving = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            title: Text('Edit ${data['username'] ?? 'user'}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          helperText:
                              'Changing it changes what they sign in with.',
                        ),
                        validator: (v) =>
                            RegExp(
                              r'^[A-Za-z0-9_.]{3,30}$',
                            ).hasMatch((v ?? '').trim())
                            ? null
                            : '3-30 characters: letters, numbers, _ and .',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: firstName,
                              decoration: const InputDecoration(
                                labelText: 'First name',
                              ),
                              validator: (v) => nameRule(v, 'First name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lastName,
                              decoration: const InputDecoration(
                                labelText: 'Last name',
                              ),
                              validator: (v) => nameRule(v, 'Last name'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dobField,
                        readOnly: true,
                        onTap: saving ? null : pickDob,
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          suffixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other / Prefer not to say'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setDialogState(() => gender = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                        ),
                        onChanged: (_) {
                          if (error != null) setDialogState(() => error = null);
                        },
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          return RegExp(
                                r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$',
                              ).hasMatch(t)
                              ? null
                              : 'Enter a valid email';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          helperText: 'e.g. +63 917 123 4567',
                        ),
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
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    for (final c in [username, firstName, lastName, email, phone, dobField]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const AdminHeader(
          title: 'User management',
          subtitle:
              'View, modify, or deactivate user accounts as needed for security or policy compliance.',
        ),
        Expanded(
          child: AdminPagedList(
            controller: _pager,
            builder: (context, docs) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(adminIsNarrow(context) ? 16 : 24),
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
                          AdminHScroll(
                            minWidth: 900,
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
                                      _tableHeader(context, 'Name', flex: 2),
                                      _tableHeader(context, 'Email', flex: 3),
                                      _tableHeader(context, 'Account type'),
                                      _tableHeader(context, 'Created'),
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
                                  // The user's real (recovery) email. The `email`
                                  // field is only the generated sign-in address
                                  // (username@fineaid.app), which isn't useful here.
                                  final email =
                                      (data['recoveryEmail'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? data['recoveryEmail'] as String
                                      : 'N/A';
                                  final fullName =
                                      '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                          .trim();
                                  final displayName = fullName.isEmpty
                                      ? username
                                      : fullName;
                                  final ts = data['createdAt'] as Timestamp?;
                                  final joined = ts != null
                                      ? DateFormat(
                                          'MMM d, y',
                                        ).format(ts.toDate())
                                      : 'N/A';
                                  // Deactivated outright, or past its scheduled date
                                  // (the app already blocks sign-in at that point;
                                  // the hourly job just catches the flag up).
                                  final deactivateAt =
                                      (data['deactivateAt'] as Timestamp?)
                                          ?.toDate();
                                  final isDeactivated =
                                      data['deactivated'] == true ||
                                      (deactivateAt != null &&
                                          !deactivateAt.isAfter(
                                            DateTime.now(),
                                          ));
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
                                                    backgroundColor: theme
                                                        .colorScheme
                                                        .primary,
                                                    child: Text(
                                                      displayName.isNotEmpty
                                                          ? displayName[0]
                                                                .toUpperCase()
                                                          : '?',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          displayName,
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                        ),
                                                        if (fullName.isNotEmpty)
                                                          Text(
                                                            username,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                email,
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                            // Every profile in `users` is a registered
                                            // account; guests have no account to list.
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Registered',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: Colors
                                                              .blue
                                                              .shade800,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                joined,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: Colors.black87,
                                                    ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
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
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isDeactivated
                                                        ? 'Inactive'
                                                        : isScheduled
                                                        ? 'Deactivates ${DateFormat('MMM d').format(deactivateAt)}'
                                                        : 'Active',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: isDeactivated
                                                              ? Colors
                                                                    .grey
                                                                    .shade700
                                                              : isScheduled
                                                              ? Colors
                                                                    .orange
                                                                    .shade800
                                                              : Colors
                                                                    .green
                                                                    .shade800,
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
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: isDeactivated
                                                                ? Colors
                                                                      .green
                                                                      .shade800
                                                                : isScheduled
                                                                ? Colors
                                                                      .orange
                                                                      .shade800
                                                                : Colors
                                                                      .red
                                                                      .shade700,
                                                          ),
                                                    ),
                                                  ),
                                                  // View details / Edit. There is no
                                                  // Delete: the admin portal has no
                                                  // way to delete accounts.
                                                  PopupMenuButton<String>(
                                                    tooltip: 'More actions',
                                                    icon: const Icon(
                                                      Icons.more_vert,
                                                      size: 18,
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'details') {
                                                        showAdminUserInfo(
                                                          context,
                                                          data,
                                                        );
                                                      } else if (value ==
                                                          'edit') {
                                                        _editUser(doc, data);
                                                      }
                                                    },
                                                    itemBuilder: (_) => const [
                                                      PopupMenuItem(
                                                        value: 'details',
                                                        child: Text(
                                                          'View details',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text('Edit'),
                                                      ),
                                                    ],
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
                              ],
                            ),
                          ),
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
