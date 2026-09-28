// Shared password strength rules, used everywhere a new password is set
// (Registration, Forgot Password reset, Edit Profile) so the requirements
// and their wording are identical across the app.

// A short denylist of the most common/weak passwords — not exhaustive (no
// external breach-list dependency), just enough to block the obvious ones
// a strength meter alone wouldn't catch (eg "Password1" passes every other
// rule below but is one of the most-breached passwords in existence).
const List<String> _commonPasswords = [
  'password',
  'password1',
  'password123',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty123',
  'qwertyui',
  'letmein1',
  'welcome1',
  'admin123',
  'iloveyou',
  'abc12345',
  '87654321',
  'changeme',
];

class PasswordRequirement {
  final String label;
  final bool Function(String) isMet;
  const PasswordRequirement(this.label, this.isMet);
}

final List<PasswordRequirement> passwordRequirements = [
  PasswordRequirement('At least 8 characters', (p) => p.length >= 8),
  PasswordRequirement(
    'At least 1 uppercase letter',
    (p) => RegExp(r'[A-Z]').hasMatch(p),
  ),
  PasswordRequirement(
    'At least 1 lowercase letter',
    (p) => RegExp(r'[a-z]').hasMatch(p),
  ),
  PasswordRequirement('At least 1 number', (p) => RegExp(r'[0-9]').hasMatch(p)),
  PasswordRequirement(
    'At least 1 special character',
    (p) => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\];/\\`~]').hasMatch(p),
  ),
];

bool isCommonPassword(String password) =>
    _commonPasswords.contains(password.toLowerCase());

/// Form-field validator: returns the first unmet requirement's message, or
/// null when the password satisfies every rule.
String? validatePasswordStrength(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  for (final requirement in passwordRequirements) {
    if (!requirement.isMet(value)) {
      return '${requirement.label} required';
    }
  }
  if (isCommonPassword(value)) {
    return 'This password is too common. Please choose another';
  }
  return null;
}
