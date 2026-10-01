/// Validates and normalizes Philippine mobile numbers for registration.
/// Accepts 9XXXXXXXXX, 09XXXXXXXXX, or +639XXXXXXXXX and normalizes every
/// valid input to +639XXXXXXXXX for storage, so the rest of the app only
/// ever deals with one format.
library;

// 3-digit mobile prefixes (the digits right after the leading 9) actually
// allocated to a PH mobile carrier, per published Globe/Smart/Sun/DITO
// numbering. Not exhaustive of every future allocation — add a prefix here
// if a real number is ever wrongly rejected.
const Set<String> knownPhMobilePrefixes = {
  // Globe/TM
  '905', '906', '915', '916', '917', '926', '927', '935', '936', '937',
  '945', '953', '954', '955', '956', '957', '965', '966', '967', '975',
  '976', '977', '978', '979', '995', '996', '997',
  // Smart/TNT
  '907', '908', '909', '910', '912', '918', '919', '920', '921', '928',
  '929', '930', '938', '939', '946', '947', '948', '949', '950', '951',
  '961', '963', '968', '970', '989', '998', '999',
  // Sun (merged into Smart; legacy numbers still active)
  '922', '923', '924', '925', '931', '932', '933', '940', '941', '942',
  '943',
  // DITO
  '991', '992', '993', '994',
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

/// Returns the normalized "+639XXXXXXXXX" form of [raw] if it's a
/// plausible Philippine mobile number in one of the three accepted input
/// formats, or null if it isn't (wrong shape, fake pattern, or a prefix
/// not allocated to a known carrier).
String? normalizePhMobileNumber(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[\s-]'), '');

  String? tenDigits; // "9XXXXXXXXX" — no country/trunk prefix
  if (RegExp(r'^\+639\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(3);
  } else if (RegExp(r'^639\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(2);
  } else if (RegExp(r'^09\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned.substring(1);
  } else if (RegExp(r'^9\d{9}$').hasMatch(cleaned)) {
    tenDigits = cleaned;
  }
  if (tenDigits == null) return null;

  if (_isAllSameDigit(tenDigits)) return null;
  if (_isSequential(tenDigits)) return null;
  if (!knownPhMobilePrefixes.contains(tenDigits.substring(0, 3))) {
    return null;
  }

  return '+63$tenDigits';
}
