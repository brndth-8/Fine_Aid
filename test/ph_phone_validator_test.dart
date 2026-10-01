import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/core/ph_phone_validator.dart';

void main() {
  group('normalizePhMobileNumber', () {
    test('accepts a valid 10-digit number and normalizes it', () {
      expect(normalizePhMobileNumber('9123456789'), '+639123456789');
    });

    test('accepts 09XXXXXXXXX and normalizes it', () {
      expect(normalizePhMobileNumber('09123456789'), '+639123456789');
    });

    test('accepts +639XXXXXXXXX and normalizes it', () {
      expect(normalizePhMobileNumber('+639123456789'), '+639123456789');
    });

    test('rejects a number that does not start with 9', () {
      expect(normalizePhMobileNumber('1234567897'), isNull);
    });

    test('rejects all-same-digit numbers', () {
      expect(normalizePhMobileNumber('9999999999'), isNull);
    });

    test('rejects ascending sequential numbers', () {
      expect(normalizePhMobileNumber('9012345678'), isNull);
    });

    test('rejects descending sequential numbers', () {
      expect(normalizePhMobileNumber('9876543210'), isNull);
    });

    test('rejects a prefix not allocated to a known PH carrier', () {
      // 900 is not an allocated mobile prefix.
      expect(normalizePhMobileNumber('9001234567'), isNull);
    });

    test('rejects the wrong number of digits', () {
      expect(normalizePhMobileNumber('912345678'), isNull);
      expect(normalizePhMobileNumber('91234567890'), isNull);
    });
  });
}
