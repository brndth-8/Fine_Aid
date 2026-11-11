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

/// One line of the details pop-up. [muted] values are placeholders such as
/// "Not provided" and are drawn in a lighter grey.
class AdminInfoRow {
  const AdminInfoRow(this.label, this.value, {this.muted = false});
  final String label;
  final String value;
  final bool muted;
}

/// A titled group of rows (PERSONAL INFORMATION, CONTACT, ACCOUNT).
class AdminInfoSection {
  const AdminInfoSection(this.title, this.rows);
  final String title;
  final List<AdminInfoRow> rows;
}

/// The profile grouped for the details pop-up. Anything the user doesn't have
/// reads as a short plain placeholder instead of a blank or "N/A".
List<AdminInfoSection> adminUserInfoSections(
  Map<String, dynamic> data, {
  DateTime? today,
}) {
  AdminInfoRow text(String label, String key) {
    final value = (data[key] as String?)?.trim();
    return value == null || value.isEmpty
        ? AdminInfoRow(label, 'Not provided', muted: true)
        : AdminInfoRow(label, value);
  }

  AdminInfoRow when(String label, String key, {required String empty}) {
    final at = (data[key] as Timestamp?)?.toDate();
    return at == null
        ? AdminInfoRow(label, empty, muted: true)
        : AdminInfoRow(label, DateFormat('MMM d, y · h:mm a').format(at));
  }

  final dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
  final gender = switch (data['gender']) {
    'male' => 'Male',
    'female' => 'Female',
    'other' => 'Other / Prefer not to say',
    _ => null,
  };
  final acknowledgedAt = (data['underageAcknowledgedAt'] as Timestamp?)
      ?.toDate();

  return [
    AdminInfoSection('Personal information', [
      text('First name', 'firstName'),
      text('Last name', 'lastName'),
      dob == null
          ? const AdminInfoRow('Date of birth', 'Not provided', muted: true)
          : AdminInfoRow('Date of birth', DateFormat('MMM d, y').format(dob)),
      // Age is its own row, not part of the date of birth.
      dob == null
          ? const AdminInfoRow('Age', 'Not provided', muted: true)
          : AdminInfoRow('Age', '${calculateAge(dob, today: today)} years old'),
      gender == null
          ? const AdminInfoRow('Gender', 'Not provided', muted: true)
          : AdminInfoRow('Gender', gender),
    ]),
    AdminInfoSection('Contact', [
      text('Email', 'recoveryEmail'),
      text('Phone number', 'phoneNumber'),
    ]),
    AdminInfoSection('Account', [
      text('Username', 'username'),
      // Every profile in users is a registered account; guests have none.
      const AdminInfoRow('Account type', 'Registered'),
      when('Date created', 'createdAt', empty: 'Not provided'),
      when('Last updated', 'updatedAt', empty: 'Not yet updated'),
      data['underageAcknowledged'] != true
          ? const AdminInfoRow(
              'Underage acknowledgment',
              'Not applicable',
              muted: true,
            )
          : AdminInfoRow(
              'Underage acknowledgment',
              acknowledgedAt == null
                  ? 'Acknowledged'
                  : 'Acknowledged on '
                        '${DateFormat('MMM d, y · h:mm a').format(acknowledgedAt)}',
            ),
    ]),
  ];
}

const _maroon = Color(0xFF690000);
const _sectionColor = Color(0xFF8B1A1A);
const _labelBackground = Color(0xFFFBF5F5);
const _labelColor = Color(0xFF6B5B5B);
const _ruleColor = Color(0xFFD5C6C6);
const _mutedColor = Color(0xFFB0A0A0);

String _initials(Map<String, dynamic> data) {
  String first(String key) {
    final v = (data[key] as String?)?.trim() ?? '';
    return v.isEmpty ? '' : v.substring(0, 1).toUpperCase();
  }

  final letters = '${first('firstName')}${first('lastName')}';
  return letters.isNotEmpty ? letters : first('username').padRight(1, '?');
}

/// Opens the user's details pop-up: a header with the name, @username and
/// account status, then the details in labelled tables. By default it lists
/// every stored detail of one user ([adminUserInfoSections]); pass [rows] to
/// show a different set of (label, value) lines in the same style, under
/// [title].
Future<void> showAdminUserInfo(
  BuildContext context,
  Map<String, dynamic> data, {
  String title = 'User details',
  List<(String, String)>? rows,
}) {
  final sections = rows == null
      ? adminUserInfoSections(data)
      : [
          AdminInfoSection(title, [
            for (final (label, value) in rows)
              value == 'N/A'
                  ? AdminInfoRow(label, 'Not provided', muted: true)
                  : AdminInfoRow(label, value),
          ]),
        ];
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _UserInfoDialog(data: data, sections: sections),
  );
}

class _UserInfoDialog extends StatelessWidget {
  const _UserInfoDialog({required this.data, required this.sections});

  final Map<String, dynamic> data;
  final List<AdminInfoSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = (data['firstName'] as String?)?.trim() ?? '';
    final last = (data['lastName'] as String?)?.trim() ?? '';
    final username = (data['username'] as String?)?.trim() ?? '';
    final name = '$first $last'.trim();
    final deactivated = data['deactivated'] == true;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _maroon,
                    child: Text(
                      _initials(data),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'User' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (username.isNotEmpty)
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _labelColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: deactivated
                          ? const Color(0xFFEDEDED)
                          : const Color(0xFFFCE4E4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      deactivated ? 'Deactivated' : 'Registered',
                      style: TextStyle(
                        fontSize: 13,
                        color: deactivated ? Colors.black54 : _maroon,
                      ),
                    ),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final section in sections) ...[
                        const SizedBox(height: 20),
                        Text(
                          section.title.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _sectionColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InfoTable(rows: section.rows),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _maroon,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label on a soft tinted column, value beside it. Every row is one box with
/// its own bottom rule, so the line runs across the whole row (label and value
/// alike) and the tinted label cell fills the row's full height.
class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<AdminInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A clear grid: an outer border, a line under every row and a line
    // between the label and value columns. The lines are dark enough to show
    // on the tinted label column too, even when a row lands on a half pixel.
    return Container(
      key: const ValueKey('admin-info-table'),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: _ruleColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            SizedBox(
              key: ValueKey('admin-info-row-$i'),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        // Each cell draws its own line under itself, so the
                        // tinted label cell can't paint over any of it.
                        decoration: BoxDecoration(
                          color: _labelBackground,
                          border: Border(
                            right: const BorderSide(color: _ruleColor),
                            bottom: i == rows.length - 1
                                ? BorderSide.none
                                : const BorderSide(color: _ruleColor),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          rows[i].label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _labelColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Container(
                        decoration: i == rows.length - 1
                            ? null
                            : const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: _ruleColor),
                                ),
                              ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: SelectableText(
                          rows[i].value,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: rows[i].muted
                                ? _mutedColor
                                : const Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
