import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/age_utils.dart';

/// The personal details shown in the Admin panel's user info view, as
/// (label, value) rows. A user who signed up before these fields existed
/// (or was added by an admin) shows "N/A" for the ones they don't have.
List<(String, String)> adminUserInfoRows(
  Map<String, dynamic> data, {
  DateTime? today,
}) {
  const na = 'N/A';
  String text(String key) {
    final value = (data[key] as String?)?.trim();
    return (value == null || value.isEmpty) ? na : value;
  }

  final dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
  String when(String key) {
    final at = (data[key] as Timestamp?)?.toDate();
    return at == null ? na : DateFormat('MMM d, y h:mm a').format(at);
  }

  final acknowledgedAt = when('underageAcknowledgedAt');
  final gender = switch (data['gender']) {
    'male' => 'Male',
    'female' => 'Female',
    'other' => 'Other / Prefer not to say',
    _ => na,
  };

  return [
    ('Username', text('username')),
    ('First Name', text('firstName')),
    ('Last Name', text('lastName')),
    ('Email', text('recoveryEmail')),
    ('Phone number', text('phoneNumber')),
    ('Date of Birth', dob == null ? na : DateFormat('MMM d, y').format(dob)),
    ('Age', dob == null ? na : '${calculateAge(dob, today: today)}'),
    ('Gender', gender),
    // Every profile in users is a registered account; guests have none.
    ('Account type', 'Registered'),
    ('Date created', when('createdAt')),
    ('Last updated', when('updatedAt')),
    (
      'Underage acknowledgment',
      data['underageAcknowledged'] != true
          ? na
          : acknowledgedAt == na
          ? 'Acknowledged'
          : 'Acknowledged on $acknowledgedAt',
    ),
  ];
}

/// Opens the user info pop-up for one user document's data.
Future<void> showAdminUserInfo(
  BuildContext context,
  Map<String, dynamic> data,
) {
  final theme = Theme.of(context);
  final rows = adminUserInfoRows(data);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('User info'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
