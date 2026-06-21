import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'dart:io';
import '../../../services/local_profile_photo.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profile',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final photoPath = LocalProfilePhoto().path;
                      return CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: photoPath != null
                            ? FileImage(File(photoPath))
                            : null,
                        child: photoPath == null
                            ? const Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.grey,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: user == null
                  ? const Center(child: Text('Not signed in'))
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final data = snapshot.data!.data() ?? {};
                        final username = data['username'] as String? ?? '';
                        final verificationMethod =
                            data['verificationMethod'] as String? ?? 'email';
                        final contact = verificationMethod == 'phone'
                            ? (data['phoneNumber'] as String? ?? '')
                            : (data['email'] as String? ?? '');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Username', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Contact Information',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              contact,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EditProfileScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
