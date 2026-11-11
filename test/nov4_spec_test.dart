import 'dart:io';
import 'package:fine_aid/core/widgets/assessment_questions.dart';
import 'package:fine_aid/features/journal/screens/day_entries_screen.dart';
import 'package:fine_aid/i18n/assessment_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('3. Edit Profile edits every detail', () {
    final edit = source(
      'lib/features/settings/screens/edit_profile_screen.dart',
    );

    test('first name, last name, phone, birthday and gender can be edited', () {
      for (final piece in [
        '_firstNameController',
        '_lastNameController',
        '_phoneController',
        '_dobController',
        'DropdownButtonFormField<String>',
        "'firstName'",
        "'lastName'",
        "'phoneNumber': '+63",
        "'dateOfBirth'",
        "'gender'",
      ]) {
        expect(edit, contains(piece), reason: piece);
      }
    });

    test('they are checked with the Sign Up rules before saving', () {
      expect(edit, contains('normalizePhMobileNumber('));
      expect(edit, contains('PhPhoneDigitsFormatter'));
      expect(edit, contains('_validateName('));
      expect(edit, contains('_validateDob('));
      expect(edit, contains('_personalDetailsChanged'));
    });
  });

  group('4. The date under the calendar follows the month on view', () {
    test('the same day of the next or previous month', () {
      expect(
        dateInMonth(DateTime(2026, 10, 25), DateTime(2026, 11)),
        DateTime(2026, 11, 25),
      );
      expect(
        dateInMonth(DateTime(2026, 1, 15), DateTime(2025, 12)),
        DateTime(2025, 12, 15),
      );
    });

    test('a shorter month takes its last day', () {
      expect(
        dateInMonth(DateTime(2026, 1, 31), DateTime(2026, 2)),
        DateTime(2026, 2, 28),
      );
      expect(
        dateInMonth(DateTime(2028, 3, 31), DateTime(2028, 2)),
        DateTime(2028, 2, 29), // a leap year
      );
    });

    test('the arrows and the swipe all go through it', () {
      final text = source(
        'lib/features/journal/screens/day_entries_screen.dart',
      );
      expect(text, contains('changeMonth(-1)'));
      expect(text, contains('changeMonth(1)'));
      expect(text, contains('dateInMonth(_selectedDate, _displayedMonth)'));
    });
  });

  group('5. Change password', () {
    final edit = source(
      'lib/features/settings/screens/edit_profile_screen.dart',
    );

    test('the error reads "Current password is incorrect"', () {
      expect(
        ScreenText.en.incorrectCurrentPassword,
        'Current password is incorrect',
      );
      expect(edit, contains('incorrectCurrentPassword'));
    });

    test('no Verify button: the current password is checked on save', () {
      expect(edit, isNot(contains('_handleVerifyCurrentPassword')));
      expect(edit, isNot(contains('_currentPasswordVerified')));
      expect(edit, contains('_currentPasswordIsRight()'));
      // checked before anything is saved
      expect(
        edit.indexOf('_currentPasswordIsRight()'),
        lessThan(edit.indexOf('runTransaction')),
      );
    });

    test('no padlock icon', () {
      expect(edit, isNot(contains('Icons.lock')));
    });
  });

  group('6. Image validation', () {
    final gemini = GeminiService();

    String reply({
      String blurry = 'no',
      String dark = 'no',
      String cropped = 'no',
      String unrecognizable = 'no',
      String fake = 'no',
      String wound = 'yes',
    }) =>
        'BLURRY: $blurry\nTOO_DARK: $dark\nCROPPED: $cropped\n'
        'UNRECOGNIZABLE: $unrecognizable\nFAKE_IMAGE: $fake\n'
        'WOUND_DETECTED: $wound\nARTIFICIAL_MARK_LIKELY: no\n'
        'CONFIDENCE: high\nWOUND_COUNT: 1\nWOUND_1: a scrape on the knee\n'
        'WOUND_1_BOX: 100,100,500,500';

    test('a clear photo of a real wound passes', () {
      final r = gemini.parseDetectionResponse(reply());
      expect(r.freePassResult, FreePassResult.pass);
      expect(r.checkFailed, isFalse);
    });

    test('blurry, too dark, cropped and unrecognisable are all "unclear"', () {
      for (final r in [
        gemini.parseDetectionResponse(reply(blurry: 'yes')),
        gemini.parseDetectionResponse(reply(dark: 'yes')),
        gemini.parseDetectionResponse(reply(cropped: 'yes')),
        gemini.parseDetectionResponse(reply(unrecognizable: 'yes')),
      ]) {
        expect(r.isUnclear, isTrue);
        expect(r.freePassResult, FreePassResult.fail);
      }
    });

    test('a fake picture (drawing, render, AI image) is stopped', () {
      final r = gemini.parseDetectionResponse(reply(fake: 'yes'));
      expect(r.looksFake, isTrue);
      expect(r.freePassResult, FreePassResult.fail);
    });

    test('a reply that cannot be read is not let through', () {
      for (final text in ['', 'sorry, I cannot help', '{"oops": true}']) {
        final r = gemini.parseDetectionResponse(text);
        expect(r.checkFailed, isTrue, reason: text);
        expect(r.freePassResult, FreePassResult.fail, reason: text);
      }
    });

    test('screenshots, photos of a screen and scars are accepted', () {
      final service = source('lib/services/api/gemini_service.dart');
      expect(service, contains('Never reject an '));
      expect(service, contains('only because it is a screenshot'));
      expect(service, isNot(contains('looks like a screenshot')));
      expect(service, isNot(contains('a stock photo')));
      expect(service, contains('scar'));
      // a fake picture reuses the existing "no real wound" message
      final camera = source(
        'lib/features/camera/screens/ai_camera_screen.dart',
      );
      expect(
        camera,
        contains('_showNoWoundDialog(artificialMarkSuspected: true)'),
      );
    });

    test('a failed check stops the scan, with a message and a retry', () {
      final service = source('lib/services/api/gemini_service.dart');
      expect(service, contains('checkFailed: true'));
      final camera = source(
        'lib/features/camera/screens/ai_camera_screen.dart',
      );
      expect(camera, contains('detection.checkFailed'));
      expect(camera, contains('detection.looksFake'));
      expect(camera, contains('detection.isUnclear'));
      expect(
        ScreenText.en.imageUnclearBody,
        'Image is unclear. Please retake the photo in good lighting.',
      );
    });
  });

  group('7. After the scan, Back goes to the Dashboard', () {
    test('the camera is replaced by the result, not left under it', () {
      final camera = source(
        'lib/features/camera/screens/ai_camera_screen.dart',
      );
      final from = camera.indexOf('Future<void> _processImage');
      final body = camera.substring(
        from,
        camera.indexOf('void _goToOfflineKit'),
      );
      expect(body, contains('Navigator.pushReplacement('));
      expect(body, isNot(contains('Navigator.push(')));
    });
  });

  group('9. Skin issue: animal or insect', () {
    final a = AssessmentStrings.en;

    Future<void> start(
      WidgetTester tester,
      void Function(AssessmentAnswers?) done,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  done(await askAssessmentQuestions(context, skinIssue: true)),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('it is asked first, before the pain and itch scales', (
      tester,
    ) async {
      await start(tester, (_) {});
      expect(find.text(a.skinAnimalQuestion), findsOneWidget);
      expect(find.text(a.painYesNoTitle), findsNothing);
    });

    testWidgets('No: on to the pain question as usual', (tester) async {
      await start(tester, (_) {});
      await tester.tap(find.text(a.no));
      await tester.pumpAndSettle();
      expect(find.text(a.painYesNoTitle), findsOneWidget);
    });

    testWidgets('Yes, animal bite: doctor advice, nothing else is asked', (
      tester,
    ) async {
      AssessmentAnswers? answers;
      await start(tester, (r) => answers = r);
      await tester.tap(find.text(a.yes));
      await tester.pumpAndSettle();
      expect(find.text(a.animalTypeTitle), findsOneWidget);
      await tester.tap(find.text(a.animalTypeBite));
      await tester.pumpAndSettle();
      expect(answers?.animalBite, isTrue);
      expect(find.text(a.painYesNoTitle), findsNothing);
    });

    testWidgets('Yes, insect: care, red flags, disclaimer, then the scales', (
      tester,
    ) async {
      await start(tester, (_) {});
      await tester.tap(find.text(a.yes));
      await tester.pumpAndSettle();
      await tester.tap(find.text(a.animalTypeInsect));
      await tester.pumpAndSettle();
      expect(find.text(a.insectCareTitle), findsOneWidget);
      for (final step in a.insectCareSteps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(find.text(a.insectRedFlagsTitle), findsOneWidget);
      for (final flag in a.insectRedFlags) {
        expect(find.textContaining(flag), findsOneWidget);
      }
      expect(find.text(a.guidanceDisclaimer), findsOneWidget);

      await tester.tap(find.text(a.continueButton));
      await tester.pumpAndSettle();
      expect(find.text(a.painYesNoTitle), findsOneWidget);
    });

    test('the result screen ends the scan with advice for a bite', () {
      final screen = source(
        'lib/features/camera/screens/assessment_result_screen.dart',
      );
      expect(screen, contains('answers?.animalBite == true'));
      expect(screen, contains('a.animalBiteAdvice'));
    });
  });
}
