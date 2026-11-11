import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for verifying a new phone number (Edit Profile), English + Tagalog.
class PhoneOtpStrings {
  final String title;
  final String body; // uses {number}
  final String codeHint;
  final String verify;
  final String cancel;
  final String resend;
  final String resendIn; // uses {s}
  final String incorrect;
  final String expired;
  final String tooMany;
  final String failed;
  final String couldNotSend;

  const PhoneOtpStrings({
    required this.title,
    required this.body,
    required this.codeHint,
    required this.verify,
    required this.cancel,
    required this.resend,
    required this.resendIn,
    required this.incorrect,
    required this.expired,
    required this.tooMany,
    required this.failed,
    required this.couldNotSend,
  });

  static PhoneOtpStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String bodyFor(String number) => body.replaceFirst('{number}', number);
  String resendInFor(int seconds) => resendIn.replaceFirst('{s}', '$seconds');

  static const en = PhoneOtpStrings(
    title: 'Verify your new number',
    body: 'We sent a 6-digit code to {number}. Enter it to confirm the change.',
    codeHint: 'Enter code',
    verify: 'Verify',
    cancel: 'Cancel',
    resend: 'Resend code',
    resendIn: 'Resend in {s}s',
    incorrect: 'Incorrect code. Please try again.',
    expired: 'Code has expired. Please request a new one.',
    tooMany: 'Too many failed attempts. Please request a new code.',
    failed: 'Verification failed. Please try again.',
    couldNotSend: 'Could not send the code. Please try again.',
  );

  static const tl = PhoneOtpStrings(
    title: 'I-verify ang bago mong numero',
    body:
        'Nagpadala kami ng 6-digit na code sa {number}. Ilagay ito para '
        'kumpirmahin ang pagbabago.',
    codeHint: 'Ilagay ang code',
    verify: 'I-verify',
    cancel: 'Kanselahin',
    resend: 'Ipadala muli ang code',
    resendIn: 'Magpadala muli sa {s}s',
    incorrect: 'Maling code. Pakisubukan muli.',
    expired: 'Nag-expire na ang code. Humiling ng bago.',
    tooMany: 'Napakaraming maling pagsubok. Humiling ng bagong code.',
    failed: 'Nabigo ang pag-verify. Pakisubukan muli.',
    couldNotSend: 'Hindi maipadala ang code. Pakisubukan muli.',
  );
}
