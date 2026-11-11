/// Validates and normalizes Philippine mobile numbers for registration.
/// Accepts 9XXXXXXXXX, 09XXXXXXXXX or +639XXXXXXXXX (and the 08 numbers, see
/// below) and normalizes every valid input to +63XXXXXXXXXX for storage, so
/// the rest of the app only ever deals with one format.
library;

// Why there is no list of allowed 09 prefixes any more: the NTC does not
// publish a machine-readable table, carriers receive new prefixes all the
// time, and with number portability a prefix no longer says which network a
// SIM is on. A list therefore kept refusing real SIMs (Smart, Sun, TNT,
// postpaid...). A real number is proven by the SMS code anyway, so every 09
// number is accepted here, and only numbers that cannot be real are refused
// (wrong length, all one digit, keyboard-mash sequences, prefix 900).

/// 09 prefixes (the digits right after the leading 9) that are never mobile
/// numbers.
const Set<String> unusedPhMobilePrefixes = {'900'};

/// The 08 mobile numbers (0811, 0813, 0817, DITO's 0895-0898): the three digits
/// after the leading 8 (these are not 09 numbers, so they are listed).
const Set<String> phEightMobilePrefixes = {
  '811',
  '813',
  '817',
  '895',
  '896',
  '897',
  '898',
};

const String phPhoneErrorMessage =
    'Please enter a valid mobile number (e.g., 9123456789)';

bool _isAllSameDigit(String tenDigits) =>
    RegExp(r'^(\d)\1{9}$').hasMatch(tenDigits);

// Flags "9012345678" (ascending, wrapping 9->0->1...) and "9876543210"
// (descending) style keyboard-mash / placeholder numbers.
bool _isSequential(String tenDigits) {
  var ascending = true;
  var descending = true;
  for (var i = 1; i < tenDigits.length; i++) {
    final prev = int.parse(tenDigits[i - 1]);
    final curr = int.parse(tenDigits[i]);
    if ((curr - prev + 10) % 10 != 1) ascending = false;
    if ((prev - curr + 10) % 10 != 1) descending = false;
  }
  return ascending || descending;
}

/// Whether [tenDigits] (the number without country code or leading 0) can be a
/// real Philippine mobile number: 9XXXXXXXXX (any 09 prefix but the unused
/// ones) or 8XXXXXXXXX with one of [phEightMobilePrefixes].
bool isPlausiblePhMobile(String tenDigits) {
  if (!RegExp(r'^[89]\d{9}$').hasMatch(tenDigits)) return false;
  if (_isAllSameDigit(tenDigits)) return false;
  if (_isSequential(tenDigits)) return false;
  final prefix = tenDigits.substring(0, 3);
  return tenDigits.startsWith('9')
      ? !unusedPhMobilePrefixes.contains(prefix)
      : phEightMobilePrefixes.contains(prefix);
}

/// Returns the normalized "+63XXXXXXXXXX" form of [raw] if it's a plausible
/// Philippine mobile number in one of the accepted input formats, or null if
/// it isn't (wrong shape or a fake pattern).
String? normalizePhMobileNumber(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[\s-]'), '');

  String? tenDigits; // "9XXXXXXXXX" / "8XXXXXXXXX" — no country/trunk prefix
  if (RegExp(r'^\+63[89]\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(3);
  } else if (RegExp(r'^63[89]\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(2);
  } else if (RegExp(r'^0[89]\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(1);
  } else if (RegExp(r'^[89]\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned;
  }
  if (tenDigits == null || !isPlausiblePhMobile(tenDigits)) return null;

  return '+63$tenDigits';
}
