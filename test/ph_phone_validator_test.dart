import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/core/ph_phone_validator.dart';
import 'package:fine_aid/services/firebase/phone_reservation.dart';

void main() {
  phoneTests();
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

// Any 09 prefix and the 08 numbers (Nov 2026): no real SIM is refused.
void phoneTests() {
  group('every SIM', () {
    test('any 09 prefix is accepted, whoever owns it', () {
      for (final p in [
        '902',
        '911',
        '913',
        '914',
        '934',
        '944',
        '969',
        '973',
        '974',
        '981',
        '985',
        '987',
        '988',
        '990',
      ]) {
        expect(
          normalizePhMobileNumber('${p}2468013'),
          '+63${p}2468013',
          reason: p,
        );
      }
    });

    test('the 08 numbers are accepted in every format', () {
      for (final p in ['811', '813', '817', '895', '896', '897', '898']) {
        final number = '${p}2468013';
        expect(normalizePhMobileNumber(number), '+63$number', reason: p);
        expect(normalizePhMobileNumber('0$number'), '+63$number', reason: p);
        expect(normalizePhMobileNumber('+63$number'), '+63$number', reason: p);
        expect(normalizePhMobileNumber('63 $number'), '+63$number', reason: p);
      }
    });

    test('08 prefixes that are not mobile numbers are refused', () {
      for (final p in ['800', '801', '812', '819', '899', '822']) {
        expect(normalizePhMobileNumber('${p}2468013'), isNull, reason: p);
      }
    });

    test('numbers that cannot be real are still refused', () {
      for (final bad in [
        '9999999999',
        '8888888888',
        '9012345678',
        '9876543210',
        '9001234567',
        '912345678',
        '91234567890',
        '7123456789',
      ]) {
        expect(normalizePhMobileNumber(bad), isNull, reason: bad);
      }
    });

    test('the reservation key understands 08 numbers too', () {
      expect(normalizePhone('08132468013'), '+638132468013');
      expect(normalizePhone('+63 895 246 8013'), '+638952468013');
      expect(normalizePhone('0912 345 6781'), '+639123456781');
      expect(normalizePhone('08002468013'), isNull);
    });
  });
}
