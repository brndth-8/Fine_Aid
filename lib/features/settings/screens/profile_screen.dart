import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/health_profile_summary.dart';
import '../../../i18n/app_language.dart';
import '../../../i18n/checklist_strings.dart';
import '../../../i18n/profile_strings.dart';
import '../../../i18n/registration_strings.dart';
import '../../../services/local_profile_photo.dart';
import '../../auth/screens/health_checklist_screen.dart';
import 'edit_profile_screen.dart';

const Color _maroon = Color(0xFF780000);
const Color _pageBackground = Color(0xFFEDEDED);
const Color _iconCircle = Color(0xFFFCE4E8);

/// One line of the Profile card: an icon, a small label and its value.
class ProfileRow {
  final IconData icon;
  final String label;
  final String value;
  const ProfileRow(this.icon, this.label, this.value);
}

/// "+639058171544" -> "0905 817 1544" (the way people write a local number).
/// Anything that is not a +63 mobile number is returned as it was saved.
String formatPhoneForDisplay(String saved) {
  final digits = saved.replaceAll(RegExp(r'[^0-9]'), '');
  final local = digits.startsWith('63') && digits.length == 12
      ? '0${digits.substring(2)}'
      : digits;
  if (local.length != 11 || !local.startsWith('0')) return saved;
  return '${local.substring(0, 4)} ${local.substring(4, 7)} '
      '${local.substring(7)}';
}

/// What the account details card shows, from the user's saved record: the
/// details collected at sign-up. Anything missing (an older account) reads
/// "Not provided". The email is the one the person entered; the internal
/// sign-in address is never shown.
List<ProfileRow> profileAccountRows(
  Map<String, dynamic> data,
  ProfileStrings s,
  RegistrationStrings r,
) {
  String text(String key) => (data[key] as String?)?.trim() ?? '';
  String orMissing(String value) => value.isEmpty ? s.notProvided : value;

  final fullName = [
    text('firstName'),
    text('lastName'),
  ].where((p) => p.isNotEmpty).join(' ');
  final dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
  final phone = text('phoneNumber');

  return [
    ProfileRow(Icons.person_outline, s.fullName, orMissing(fullName)),
    ProfileRow(Icons.person_outline, s.username, orMissing(text('username'))),
    ProfileRow(
      Icons.phone,
      s.phone,
      orMissing(phone.isEmpty ? '' : formatPhoneForDisplay(phone)),
    ),
    ProfileRow(Icons.mail, s.email, orMissing(text('recoveryEmail'))),
    ProfileRow(
      Icons.cake,
      s.birthday,
      dob == null ? s.notProvided : DateFormat('MM / dd / yyyy').format(dob),
    ),
    ProfileRow(Icons.wc, s.gender, switch (data['gender']) {
      'male' => r.genderMale,
      'female' => r.genderFemale,
      'other' => r.genderOther,
      _ => s.notProvided,
    }),
  ];
}

/// What the Health Profile card shows: the saved conditions and medications
/// in readable words. [profile] is null when no health profile was saved.
List<ProfileRow> profileHealthRows(
  Map<String, dynamic>? profile,
  ProfileStrings s,
  ChecklistStrings c,
  String andWord,
) {
  if (profile == null) {
    return [
      ProfileRow(Icons.medical_services_outlined, s.conditions, s.notSet),
      ProfileRow(Icons.medication_outlined, s.medications, s.notSet),
    ];
  }
  final conditions = profileConditionLabels(profile, c);
  final medications = profileMedications(profile);
  return [
    ProfileRow(
      Icons.medical_services_outlined,
      s.conditions,
      conditions.isEmpty ? s.none : joinWithAnd(conditions, andWord),
    ),
    ProfileRow(
      Icons.medication_outlined,
      s.medications,
      medications.isEmpty ? s.none : joinWithAnd(medications, andWord),
    ),
  ];
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ProfileStrings.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Column(
        children: [
          _TopBar(title: s.title),
          Expanded(
            child: user == null
                ? Center(child: Text(s.notSignedIn))
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _ProfileBody(data: snapshot.data!.data() ?? {});
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _maroon,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
              // Keeps the title centred.
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfileBody({required this.data});

  void _edit(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  Future<void> _editHealthProfile(
    BuildContext context,
    Map<String, dynamic> profile,
  ) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HealthChecklistScreen(initialProfile: profile),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ProfileStrings.of(context);
    final tagalog = AppLanguageScope.isTagalog(context);
    final r = tagalog ? RegistrationStrings.tl : RegistrationStrings.en;
    final c = tagalog ? ChecklistStrings.tl : ChecklistStrings.en;
    final andWord = tagalog ? 'at' : 'and';

    final username = (data['username'] as String?)?.trim() ?? '';
    final photoUrl = data['profilePhotoUrl'] as String?;
    final localPath = LocalProfilePhoto().path;
    final ImageProvider? image = localPath != null
        ? FileImage(File(localPath))
        : (photoUrl != null ? NetworkImage(photoUrl) : null);
    final health = data['healthProfile'] as Map<String, dynamic>?;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                // The photo, with a camera badge: tapping opens Edit Profile,
                // where the photo is changed.
                GestureDetector(
                  onTap: () => _edit(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 68,
                        backgroundColor: Colors.white,
                        backgroundImage: image,
                        child: image == null
                            ? const Icon(
                                Icons.person,
                                size: 72,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _maroon,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.photo_camera,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  username,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.accountProfile,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                _DetailsCard(rows: profileAccountRows(data, s, r)),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      s.healthProfile,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                _DetailsCard(
                  rows: profileHealthRows(health, s, c, andWord),
                  action: health == null
                      ? null
                      : TextButton(
                          onPressed: () => _editHealthProfile(context, health),
                          child: Text(
                            s.update,
                            style: const TextStyle(color: _maroon),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.edit),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(96, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card of rows, each with a pink icon circle, a small grey label and
/// a bold value, separated by thin lines.
class _DetailsCard extends StatelessWidget {
  final List<ProfileRow> rows;
  final Widget? action;
  const _DetailsCard({required this.rows, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade400),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _iconCircle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(rows[i].icon, color: _maroon, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          rows[i].value,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
