/// Turns an audit-log entry into plain language for an admin: who did what,
/// to whom, with no ids, codes or technical wording. Works on new entries
/// (which carry structured fields) and on older ones (which only have the
/// original text, sometimes with a raw id in it).
///
/// Example: `Admin signed in` by Maria -> "Maria signed in to the admin portal".
String describeAudit(Map<String, dynamic> data, String actor) {
  final raw = ((data['action'] as String?) ?? '').trim();
  final target = _clean(data['targetName'] as String?);
  final who = actor.isEmpty || actor == 'System' ? 'The system' : "'$actor'";
  final reason = data['reason'] as String? ?? '';

  String quoted(RegExp re) => re.firstMatch(raw)?.group(1)?.trim() ?? '';
  final inQuotes = RegExp(r'"([^"]*)"');

  // ---- sign-in and session ------------------------------------------------
  if (raw == 'Admin signed in') {
    return reason == 'authenticator_code'
        ? "$who signed in to the admin portal with an authenticator code"
        : "$who signed in to the admin portal";
  }
  if (raw.startsWith('Admin portal sign-in refused')) {
    return actor.isEmpty || actor == 'System'
        ? 'Someone who is not an admin tried to sign in to the admin portal'
        : "'$actor' is not an admin and was refused entry to the admin portal";
  }
  if (raw == 'Failed admin sign-in attempt') {
    final why = switch (reason) {
      'user_disabled' => 'the account is disabled',
      'too_many_attempts' => 'too many attempts were made',
      'wrong_code' => 'the authenticator code was wrong',
      _ => 'the wrong password was used',
    };
    return "A sign-in to the admin account of '$actor' failed ($why)";
  }
  if (raw.startsWith('Signed out automatically after inactivity')) {
    return '$who was signed out automatically after being inactive';
  }

  // ---- security settings --------------------------------------------------
  final idleOn = RegExp(
    r'^Idle session timeout turned on \((\d+) minutes\)',
  ).firstMatch(raw);
  if (idleOn != null) {
    return '$who turned on automatic sign-out after '
        '${idleOn.group(1)} minutes of inactivity';
  }
  if (raw == 'Idle session timeout turned off') {
    return '$who turned off automatic sign-out for inactive admins';
  }
  final lockOn = RegExp(
    r'^Failed login lockout turned on \((\d+) attempts?, (\d+) minutes\)',
  ).firstMatch(raw);
  if (lockOn != null) {
    return '$who turned on the failed-login lockout: accounts are locked '
        'for ${lockOn.group(2)} minutes after ${lockOn.group(1)} wrong '
        'passwords';
  }
  if (raw == 'Failed login lockout turned off') {
    return '$who turned off the failed-login lockout';
  }

  if (raw == 'Two-step verification turned on for admins') {
    return '$who turned on authenticator codes for every admin sign-in';
  }
  if (raw == 'Two-step verification turned off for admins') {
    return '$who turned off the authenticator code requirement for admins';
  }

  // ---- notifications ------------------------------------------------------
  if (raw.startsWith('Sent notification') && raw.endsWith('to a user')) {
    return "$who sent the notification '${quoted(inQuotes)}' to "
        "${target.isEmpty ? 'one user' : "'$target'"}";
  }
  final toMany = RegExp(
    r'^Sent notification .* to (\d+) users$',
  ).firstMatch(raw);
  if (toMany != null) {
    return "$who sent the notification '${quoted(inQuotes)}' to "
        '${toMany.group(1)} users';
  }
  if (raw.startsWith('Sent notification')) {
    return "$who sent the notification '${quoted(inQuotes)}' to all "
        'registered users';
  }
  final forMany = RegExp(
    r'^Scheduled notification .* for (\d+) users?$',
  ).firstMatch(raw);
  if (forMany != null) {
    final n = int.parse(forMany.group(1)!);
    return "$who scheduled the notification '${quoted(inQuotes)}' for "
        '$n ${n == 1 ? 'user' : 'users'}';
  }
  if (raw.startsWith('Scheduled notification')) {
    return "$who scheduled the notification '${quoted(inQuotes)}'";
  }
  if (raw.startsWith('Edited scheduled notification')) {
    return "$who edited the scheduled notification '${quoted(inQuotes)}'";
  }
  if (raw.startsWith('Cancelled scheduled notification')) {
    return "$who cancelled the scheduled notification '${quoted(inQuotes)}'";
  }

  // ---- content ------------------------------------------------------------
  for (final (prefix, verb) in const [
    ('Created article', 'created'),
    ('Updated article', 'edited'),
    ('Published article', 'published'),
    ('Unpublished article', 'unpublished'),
    ('Deleted article', 'deleted'),
    ('Restored article', 'restored'),
  ]) {
    if (raw.startsWith(prefix)) {
      return "$who $verb the article '${quoted(inQuotes)}'";
    }
  }

  // ---- users --------------------------------------------------------------
  final editedUser = RegExp(r'^Edited user (.+)$').firstMatch(raw);
  if (editedUser != null) {
    final name = _clean(editedUser.group(1));
    final fields = reason.startsWith('fields:')
        ? reason
              .substring(7)
              .split(',')
              .map((f) => _fieldWords[f.trim()] ?? '')
              .where((f) => f.isNotEmpty)
              .toList()
        : <String>[];
    return "$who edited the profile of '${target.isEmpty ? name : target}'"
        '${fields.isEmpty ? '' : ' (changed: ${fields.join(', ')})'}';
  }
  final deact = RegExp(
    r'^(?:Scheduled account deactivation: |Scheduled deactivation of user ")([^"]+?)"?(?: for .*)?$',
  ).firstMatch(raw);
  if (deact != null) {
    return "$who scheduled the deactivation of the account of "
        "'${target.isEmpty ? _clean(deact.group(1)) : target}'";
  }
  final cancelDeact = RegExp(
    r'^Cancelled scheduled deactivation(?: of user "| ?: )?([^"]*)"?$',
  ).firstMatch(raw);
  if (cancelDeact != null) {
    final name = target.isEmpty ? _clean(cancelDeact.group(1)) : target;
    return "$who cancelled the scheduled deactivation of the account of "
        "'$name'";
  }
  final done = RegExp(
    r'^Account deactivated \(scheduled\): (.+)$',
  ).firstMatch(raw);
  if (done != null) {
    return "The account of '${target.isEmpty ? _clean(done.group(1)) : target}'"
        ' was deactivated after its notice period ended';
  }
  final react = RegExp(
    r'^(?:Account reactivated: |Activated user )(.+)$',
  ).firstMatch(raw);
  if (react != null) {
    return "$who reactivated the account of "
        "'${target.isEmpty ? _clean(react.group(1)) : target}'";
  }
  final created = RegExp(r'^Created user "([^"]+)"').firstMatch(raw);
  if (created != null) {
    return "$who created the user account '${_clean(created.group(1))}'";
  }

  // ---- feedback -----------------------------------------------------------
  final from = target.isEmpty ? '' : " from '$target'";
  if (raw == 'Responded to feedback') {
    return '$who replied to a feedback item$from';
  }
  if (raw.startsWith('Resolved feedback') ||
      raw == 'Resolved a feedback item') {
    return '$who marked a feedback item$from as resolved';
  }
  if (raw.startsWith('Reopened feedback') ||
      raw == 'Reopened a feedback item') {
    return '$who reopened a feedback item$from';
  }

  // ---- reports and accounts -----------------------------------------------
  if (raw == 'Exported admin activity report') {
    return '$who downloaded the admin activity report';
  }
  if (raw == 'Exported the audit log') {
    return '$who downloaded the audit log as a PDF';
  }
  if (raw.startsWith('Generated report')) {
    return "$who downloaded the '${quoted(inQuotes)}' report";
  }
  if (raw == 'Viewed Admin Accounts') {
    return '$who viewed the list of admin accounts';
  }
  final pw = RegExp(r'^Sent password reset for (.+)$').firstMatch(raw);
  if (pw != null) {
    return '$who sent a password-reset email to ${_clean(pw.group(1))}';
  }

  // ---- anything else: keep the wording, drop ids and symbols ----------------
  final cleaned = _clean(raw);
  if (cleaned.isEmpty) return '$who did something in the admin portal';
  return '$who: ${cleaned[0].toLowerCase()}${cleaned.substring(1)}';
}

/// The short plain-text "Action" for an entry (no colour, no codes).
String auditActionLabel(Map<String, dynamic> data) {
  final raw = ((data['action'] as String?) ?? '').toLowerCase();
  final type = (data['type'] as String?) ?? 'UPDATE';
  if (type == 'LOGIN') {
    if (raw.contains('failed') || raw.contains('refused')) {
      return 'Sign-in refused';
    }
    if (raw.contains('signed out')) return 'Signed out';
    return 'Signed in';
  }
  return switch (type) {
    'CREATE' => 'Created',
    'DELETE' => 'Deleted',
    _ => 'Updated',
  };
}

const _fieldWords = {
  'username': 'username',
  'firstName': 'first name',
  'lastName': 'last name',
  'dateOfBirth': 'date of birth',
  'gender': 'gender',
  'email': 'email',
  'phoneNumber': 'phone number',
};

/// Removes raw ids (Firestore document ids are 20 letters/digits, sign-in
/// uids 28), leftover technical brackets and doubled spaces.
String _clean(String? text) {
  var t = (text ?? '').trim();
  t = t.replaceAll(RegExp(r'\b[A-Za-z0-9]{28}\b'), '');
  t = t.replaceAll(
    RegExp(r'\b(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{20}\b'),
    '',
  );
  t = t.replaceAll(RegExp(r'\(\s*\)'), '').replaceAll(RegExp(r'\s{2,}'), ' ');
  return t.trim();
}
