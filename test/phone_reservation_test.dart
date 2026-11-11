import 'package:fine_aid/i18n/registration_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/services/firebase/phone_reservation.dart';
import 'package:fine_aid/services/firebase/registration_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every usual way of writing a number is the same reservation key', () {
    const key = '+639171234567';
    for (final raw in [
      '+639171234567',
      '+63 917 123 4567',
      '09171234567',
      '9171234567',
      '0917-123-4567',
      ' 63 9171234567 ',
    ]) {
      expect(normalizePhone(raw), key, reason: raw);
    }
  });

  test('anything that is not a 10-digit PH mobile number has no key', () {
    for (final raw in ['', '12345', '+6321234567', '7123456789', '8001234567', 'abc']) {
      expect(normalizePhone(raw), isNull, reason: raw);
    }
  });

  test('a taken phone number has its own message in both languages', () {
    expect(
      RegistrationStrings.en.messageFor(RegistrationError.phoneTaken),
      'This phone number is already registered.',
    );
    expect(
      RegistrationStrings.tl.messageFor(RegistrationError.phoneTaken),
      isNot(RegistrationStrings.en.phoneTaken),
    );
    expect(ScreenText.tl.phoneTaken, isNot(ScreenText.en.phoneTaken));
    expect(ScreenText.en.phoneTaken, contains('phone number'));
  });
}
