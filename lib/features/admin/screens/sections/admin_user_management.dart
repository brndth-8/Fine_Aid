import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../services/firebase/auth_service.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminUserManagement extends StatefulWidget {
  const AdminUserManagement({super.key});

  @override
  State<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagement> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots();

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
    final normalizedUsername = username.trim().toLowerCase();

    final taken = await AuthService().isUsernameTaken(normalizedUsername);
    if (taken) {
      throw 'That username is already taken.';
    }

    final generatedEmail = '$normalizedUsername@fineaid.app';

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
        'username': username.trim(),
        'email': generatedEmail,
        'phoneNumber': phoneNumber,
        'verificationMethod': 'phone',
        'createdAt': FieldValue.serverTimestamp(),
        'phoneVerified': false,
        'onboardingComplete': false,
        'createdByAdmin': true,
      });
      await secondaryFirestore
          .collection('usernames')
          .doc(normalizedUsername)
          .set({'email': generatedEmail, 'uid': uid});

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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snapshot) {
              final fallback = adminSnapshotFallback(snapshot);
              if (fallback != null) return fallback;

              final docs = snapshot.data!.docs;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'All users (${docs.length} total)',
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
                                _tableHeader(context, 'Status'),
                                _tableHeader(context, 'Actions'),
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
                            final isDeactivated = data['deactivated'] == true;

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
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDeactivated
                                                ? Colors.grey.shade100
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isDeactivated
                                                ? 'Inactive'
                                                : 'Active',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: isDeactivated
                                                      ? Colors.grey.shade700
                                                      : Colors.green.shade800,
                                                ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
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
                                              onPressed: () {
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(doc.id)
                                                    .update({
                                                      'deactivated':
                                                          !isDeactivated,
                                                    });
                                                logAdminAction(
                                                  isDeactivated
                                                      ? 'Activated user $username'
                                                      : 'Deactivated user $username',
                                                  type: 'UPDATE',
                                                );
                                              },
                                              child: Text(
                                                isDeactivated
                                                    ? 'Activate'
                                                    : 'Deactivate',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: isDeactivated
                                                          ? Colors
                                                                .green
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
