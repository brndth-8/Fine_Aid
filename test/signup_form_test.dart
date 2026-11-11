import 'package:fine_aid/core/ph_phone_validator.dart';
import 'package:fine_aid/features/auth/screens/registration_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'date_boxes_helpers.dart';

TextEditingValue _format(String text, {int? cursor}) =>
    const PhPhoneDigitsFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phone field input filter', () {
    test('only digits survive (letters, spaces, symbols removed)', () {
      expect(_format('ab12-3 4(5)+6').text, '123456');
      expect(_format('abc').text, '');
    });

    test('a pasted local number loses its leading 0', () {
      expect(_format('09123456789').text, '9123456789');
      expect(_format('009171234567').text, '9171234567');
    });

    test('a pasted +63 number keeps just the 10 digits', () {
      expect(_format('+63 917 123 4567').text, '9171234567');
      expect(_format('639171234567').text, '9171234567');
    });

    test('input is capped at exactly 10 digits', () {
      expect(_format('91712345678999').text, '9171234567');
    });

    test(
      'typing "63" alone is left alone (not mistaken for a country code)',
      () {
        expect(_format('63').text, '63');
      },
    );

    test('the caret stays put after characters are removed', () {
      final v = _format('09171', cursor: 5);
      expect(v.text, '9171');
      expect(v.selection.baseOffset, 4);
    });

    test('+63 plus the typed digits is the exact format the backend gets', () {
      expect(normalizePhMobileNumber('+639171234567'), '+639171234567');
    });
  });

  group('Sign Up screen', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pump();
    }

    // The form has two pages. Page 1 (Basic information): first name, last
    // name, date of birth, age (read-only); personal(i) indexes those.
    // Page 2 (Account details): username, phone, email, password, confirm;
    // field(i) indexes those.
    Finder field(int i) => find.byType(TextFormField).at(i);
    Finder personal(int i) => find.byType(TextFormField).at(i);
    Future<void> type(WidgetTester t, int i, String text) async {
      await t.enterText(field(i), text);
      await t.pump();
    }

    Finder signUp() => find.widgetWithText(ElevatedButton, 'Sign Up');
    bool enabled(WidgetTester t) =>
        t.widget<ElevatedButton>(signUp()).onPressed != null;

    // First name, last name, date of birth (through the date picker) and
    // gender — all valid, as an adult.
    Future<void> fillPersonal(
      WidgetTester t, {
      String dob = '01152000',
      String gender = 'Male',
    }) async {
      await t.enterText(personal(0), 'Juan');
      await t.enterText(personal(1), 'Dela Cruz');
      await t.pump();
      await t.ensureVisible(personal(2));
      await t.tap(personal(2));
      await t.pumpAndSettle();
      await enterDate(t, 'start', dob);
      await t.pump();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text(gender).last);
      await t.pumpAndSettle();
    }

    Finder nextButton() => find.widgetWithText(ElevatedButton, 'Next');

    // Page 1 -> page 2.
    Future<void> goNext(WidgetTester t) async {
      await t.ensureVisible(nextButton());
      await t.tap(nextButton());
      await t.pumpAndSettle();
    }

    // The sign-up screen already on its Account details page.
    Future<void> pumpAccount(WidgetTester t) async {
      await pump(t);
      await fillPersonal(t);
      await goNext(t);
    }

    Future<void> fillAllValid(WidgetTester t) async {
      await fillPersonal(t);
      await goNext(t);
      await type(t, 0, 'juan_dela.cruz');
      await type(t, 1, '9171234567');
      await type(t, 2, 'Str0ng!Pass');
      await type(t, 3, 'Str0ng!Pass');
    }

    testWidgets('REQ 1: the button starts disabled and gray, with no errors '
        'shown before the user touches anything', (tester) async {
      await pumpAccount(tester);
      expect(enabled(tester), isFalse);
      expect(find.text('Phone number is required'), findsNothing);
      expect(find.text('Username is required'), findsNothing);
      expect(find.text('Password is required'), findsNothing);
      final style = tester.widget<ElevatedButton>(signUp()).style!;
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        Colors.grey.shade300,
      );
      expect(
        style.foregroundColor!.resolve({WidgetState.disabled}),
        Colors.grey.shade600,
      );
    });

    testWidgets('Part 2: red asterisks on required labels, the Sign Up button '
        'has a gray outline, and the phone placeholder is smaller', (
      tester,
    ) async {
      await pump(tester);
      final error = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme.error;

      List<TextSpan> stars() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan)
          .whereType<TextSpan>()
          .expand((s) => s.children ?? const <InlineSpan>[])
          .whereType<TextSpan>()
          .where((c) => c.text == ' *')
          .toList();

      // Page 1: first name, last name, date of birth, gender (age is
      // read-only, so it has no asterisk).
      expect(stars().length, 4);
      expect(stars().every((c) => c.style?.color == error), isTrue);
      expect(find.text('* Required'), findsNothing);

      // Page 2, Phone number by default: username, phone, password, confirm
      // (the email field is hidden).
      await fillPersonal(tester);
      await goNext(tester);
      expect(stars().length, 4);
      expect(stars().every((c) => c.style?.color == error), isTrue);

      expect(find.text('Login here', findRichText: true), findsNothing);

      final btn = tester.widget<ElevatedButton>(signUp()).style!;
      expect(btn.side!.resolve({})!.color, isNot(Colors.transparent));

      final phone = tester.widget<TextField>(
        find.descendant(of: field(1), matching: find.byType(TextField)),
      );
      expect(phone.decoration!.hintStyle!.fontSize, 12);

      // Email method: the email replaces the phone, so it is still four
      // (username, email, password, confirm).
      await tester.tap(find.text('Email').first);
      await tester.pump();
      expect(stars().length, 4);
    });

    testWidgets('REQ 1: a blank phone keeps the button disabled even when '
        'every other field is valid', (tester) async {
      await pump(tester);
      await fillPersonal(tester);
      await goNext(tester);
      await type(tester, 0, 'juan_dela.cruz');
      await type(tester, 2, 'Str0ng!Pass');
      await type(tester, 3, 'Str0ng!Pass');
      expect(enabled(tester), isFalse);
    });

    testWidgets('REQ 1: the button enables only when all fields are valid', (
      tester,
    ) async {
      await pump(tester);
      await fillAllValid(tester);
      expect(enabled(tester), isTrue);

      // Break one field again -> disabled again.
      await type(tester, 1, '91712');
      expect(enabled(tester), isFalse);
    });

    testWidgets(
      'the Age field is read-only and filled from the date of birth',
      (tester) async {
        await pump(tester);
        await fillPersonal(tester); // born 2000-01-15
        final age = tester.widget<TextField>(
          find.descendant(of: personal(3), matching: find.byType(TextField)),
        );
        expect(age.readOnly, isTrue);
        final expected =
            DateTime.now().year -
            2000 -
            (DateTime.now().isBefore(DateTime(DateTime.now().year, 1, 15))
                ? 1
                : 0);
        expect(age.controller!.text, '$expected');
      },
    );

    testWidgets('under 18: a modal that cannot be dismissed must be '
        'acknowledged before registering', (tester) async {
      await pump(tester);
      final now = DateTime.now();
      // 17: under 18 (the supervision notice) but not under 16 (a separate
      // notice, shown as soon as the birthdate is entered)
      final young = DateTime(now.year - 17, now.month, now.day);
      final dob =
          '${young.month.toString().padLeft(2, '0')}'
          '${young.day.toString().padLeft(2, '0')}${young.year}';
      await fillPersonal(tester, dob: dob);
      await goNext(tester);
      await type(tester, 0, 'juan_dela.cruz');
      await type(tester, 1, '9171234567');
      await type(tester, 2, 'Str0ng!Pass');
      await type(tester, 3, 'Str0ng!Pass');
      expect(enabled(tester), isTrue);

      await tester.ensureVisible(signUp());
      await tester.tap(signUp());
      await tester.pumpAndSettle();

      expect(
        find.text('Underage Access & Supervision Disclaimer'),
        findsOneWidget,
      );
      expect(find.text('I Acknowledge & Proceed'), findsOneWidget);

      // Tapping outside and the back button do not close it.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Underage Access & Supervision Disclaimer'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text('Underage Access & Supervision Disclaimer'),
        findsOneWidget,
      );
    });

    testWidgets('pages: Basic information first, with Next disabled until it '
        'is valid; Account details after', (tester) async {
      await pump(tester);
      expect(find.text('Step 1 of 2 · Basic information'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsNothing);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);

      await fillPersonal(tester);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);

      await goNext(tester);
      expect(find.text('Step 2 of 2 · Account details'), findsOneWidget);
      expect(find.text('First Name'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
      expect(signUp(), findsOneWidget);
    });

    testWidgets('pages: Back returns to page 1 with what was typed kept', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2 · Basic information'), findsOneWidget);
      expect(find.text('Juan'), findsOneWidget);
      expect(find.text('Dela Cruz'), findsOneWidget);
      expect(find.text('01/15/2000'), findsOneWidget);
    });

    testWidgets('REQ 1: mismatched confirm password keeps it disabled', (
      tester,
    ) async {
      await pump(tester);
      await fillAllValid(tester);
      await type(tester, 3, 'Different1!');
      expect(enabled(tester), isFalse);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('REQ 2: specific "required" messages appear after the user '
        'leaves a blank field', (tester) async {
      await pumpAccount(tester);

      await tester.tap(field(1)); // focus phone
      await tester.pump();
      expect(find.text('Phone number is required'), findsNothing); // not yet

      await tester.tap(field(2)); // move to password -> phone loses focus
      await tester.pump();
      expect(find.text('Phone number is required'), findsOneWidget);

      await tester.tap(field(0)); // password loses focus
      await tester.pump();
      expect(find.text('Password is required'), findsOneWidget);

      await tester.tap(field(2)); // username loses focus
      await tester.pump();
      expect(find.text('Username is required'), findsOneWidget);
    });

    testWidgets('REQ 2: invalid-format messages appear as the user types', (
      tester,
    ) async {
      await pumpAccount(tester);

      await type(tester, 1, '91712');
      expect(
        find.text('Phone number must be exactly 10 digits'),
        findsOneWidget,
      );

      await type(tester, 2, 'x'); // password
      await type(tester, 3, 'y'); // confirm
      expect(find.text('Passwords do not match'), findsOneWidget);

      // Email method: its own format check (the phone field is gone).
      await tester.tap(find.text('Email').first);
      await tester.pump();
      await type(tester, 1, 'not-an-email');
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Phone number must be exactly 10 digits'), findsNothing);
    });

    testWidgets('REQ 2: confirm password blank -> its own required message', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.tap(field(3));
      await tester.pump();
      await tester.tap(field(0));
      await tester.pump();
      expect(find.text('Confirm password is required'), findsOneWidget);
    });

    testWidgets('REQ 2: existing carrier/fake-number check still applies to '
        '10 digits', (tester) async {
      await pumpAccount(tester);
      await type(tester, 1, '9999999999'); // 10 digits but a fake pattern
      expect(find.text(phPhoneErrorMessage), findsOneWidget);
      expect(find.text('Phone number must be exactly 10 digits'), findsNothing);
    });

    testWidgets('either-or: Phone number shows only the phone field, Email '
        'shows only the email field', (tester) async {
      await pumpAccount(tester);
      Finder hint(String text) => find.widgetWithText(TextFormField, text);
      // Phone number (the default): phone field, no email field.
      expect(find.text('+63'), findsOneWidget);
      expect(hint('Email Address'), findsNothing);

      await tester.tap(find.text('Email').first);
      await tester.pump();
      expect(hint('Email Address'), findsOneWidget);
      expect(find.text('+63'), findsNothing);
      expect(find.text('Phone Number'), findsNothing);

      await tester.tap(find.text('Phone number').first);
      await tester.pump();
      expect(find.text('+63'), findsOneWidget);
      expect(hint('Email Address'), findsNothing);
    });

    testWidgets('either-or: with Phone number chosen, no email is needed', (
      tester,
    ) async {
      await pump(tester);
      await fillAllValid(tester);
      expect(enabled(tester), isTrue); // phone filled, no email at all
    });

    testWidgets('either-or: with Email chosen, only a valid email is needed '
        '(no phone)', (tester) async {
      await pump(tester);
      await fillPersonal(tester);
      await goNext(tester);
      await type(tester, 0, 'juan_dela.cruz');
      await tester.tap(find.text('Email').first);
      await tester.pump();
      await type(tester, 2, 'Str0ng!Pass');
      await type(tester, 3, 'Str0ng!Pass');
      expect(enabled(tester), isFalse); // the email is still blank

      await type(tester, 1, 'not-an-email');
      expect(enabled(tester), isFalse); // wrong format

      await type(tester, 1, 'juan@example.com');
      expect(enabled(tester), isTrue); // no phone was ever needed
    });

    testWidgets('switching methods clears the one that is hidden', (
      tester,
    ) async {
      await pump(tester);
      await fillAllValid(tester); // phone 9171234567 typed
      await tester.tap(find.text('Email').first);
      await tester.pump();
      await type(tester, 1, 'juan@example.com');

      // back to Phone number: the email is gone, the phone starts empty
      await tester.tap(find.text('Phone number').first);
      await tester.pump();
      final phone = tester.widget<TextField>(
        find.descendant(of: field(1), matching: find.byType(TextField)),
      );
      expect(phone.controller!.text, isEmpty);
      expect(enabled(tester), isFalse); // the phone is required again

      // and to Email again: the earlier email was not kept
      await tester.tap(find.text('Email').first);
      await tester.pump();
      final email = tester.widget<TextField>(
        find.descendant(of: field(1), matching: find.byType(TextField)),
      );
      expect(email.controller!.text, isEmpty);
    });

    testWidgets('REQ 3: the checklist shows all five rules, live', (
      tester,
    ) async {
      await pumpAccount(tester);
      for (final label in const [
        'At least 8 characters',
        'At least 1 uppercase letter',
        'At least 1 lowercase letter',
        'At least 1 number',
        'At least 1 special character',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await type(tester, 2, 'abc'); // only lowercase met
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await type(tester, 2, 'Abcdef1!'); // all five met
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));

      await type(tester, 2, 'abcdefgh'); // length + lowercase
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets('REQ 3: the button stays disabled until every password rule '
        'is met', (tester) async {
      await pump(tester);
      await fillPersonal(tester);
      await goNext(tester);
      await type(tester, 0, 'juan_dela.cruz');
      await type(tester, 1, '9171234567');

      for (final weak in const [
        'shor1!A', // 7 characters
        'alllowercase1!',
        'ALLUPPERCASE1!',
        'NoNumbers!!',
        'NoSpecial123',
      ]) {
        await type(tester, 2, weak);
        await type(tester, 3, weak);
        expect(enabled(tester), isFalse, reason: weak);
      }

      await type(tester, 2, 'Str0ng!Pass');
      await type(tester, 3, 'Str0ng!Pass');
      expect(enabled(tester), isTrue);
    });

    testWidgets('REQ 4: a fixed +63 prefix is shown and is not part of the '
        'editable text', (tester) async {
      await pumpAccount(tester);
      expect(find.text('+63'), findsOneWidget);
      await type(tester, 1, '9171234567');
      final controller = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller!;
      expect(controller.text, '9171234567'); // no "+63" in the value
    });

    testWidgets('REQ 4: letters, spaces and symbols cannot be typed or '
        'pasted', (tester) async {
      await pumpAccount(tester);
      await type(tester, 1, 'a9b1 7-1(2)+3');
      final controller = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller!;
      expect(
        controller.text,
        '91712'
        '3',
      );
    });

    testWidgets('REQ 4: input is limited to 10 digits and a leading 0 is '
        'dropped', (tester) async {
      await pumpAccount(tester);
      await type(tester, 1, '09171234567899');
      final controller = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller!;
      expect(controller.text, '9171234567');
      expect(controller.text.length, 10);
    });

    testWidgets('REQ 4: 10 digits is valid, fewer is not', (tester) async {
      await pump(tester);
      await fillAllValid(tester);
      expect(enabled(tester), isTrue);
      await type(tester, 1, '917123456'); // 9 digits
      expect(enabled(tester), isFalse);
      expect(
        find.text('Phone number must be exactly 10 digits'),
        findsOneWidget,
      );
    });
  });
}
