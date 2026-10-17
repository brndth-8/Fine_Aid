import 'dart:convert';
import 'dart:io';

import 'package:fine_aid/core/widgets/first_aid_step_image.dart';
import 'package:fine_aid/data/first_aid_step_images.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/step_image_strings.dart';
import 'package:fine_aid/i18n/voice_strings.dart';
import 'package:fine_aid/services/voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1x1 transparent PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// An asset bundle that holds only the files it is given.
class _FakeBundle extends CachingAssetBundle {
  final Map<String, Uint8List> files;
  _FakeBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final manifest = <String, Object>{
        for (final path in files.keys)
          path: <Object>[
            <String, Object>{'asset': path},
          ],
      };
      return const StandardMessageCodec().encodeMessage(manifest)!;
    }
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('voice: speech language', () {
    test('Tagalog picks a Filipino locale when the phone has one', () {
      final choice = chooseSpeechLocale([
        'en_US',
        'fil_PH',
        'es_ES',
      ], tagalog: true);
      expect(choice.id, 'fil_PH');
      expect(choice.usedFallback, isFalse);
      expect(chooseSpeechLocale(['tl-PH'], tagalog: true).id, 'tl-PH');
    });

    test('Tagalog without a Tagalog voice falls back and says so', () {
      final choice = chooseSpeechLocale(['en_US', 'es_ES'], tagalog: true);
      expect(choice.id, isNull);
      expect(choice.usedFallback, isTrue);
      expect(chooseSpeechLocale([], tagalog: true).usedFallback, isTrue);
    });

    test('English prefers en_US and never reports a fallback', () {
      expect(
        chooseSpeechLocale(['fil_PH', 'en_US'], tagalog: false).id,
        'en_US',
      );
      final other = chooseSpeechLocale(['en_GB'], tagalog: false);
      expect(other.id, isNull);
      expect(other.usedFallback, isFalse);
    });

    test('the voice messages exist in both languages', () {
      expect(
        VoiceStrings.tl.tagalogUnavailable,
        isNot(VoiceStrings.en.tagalogUnavailable),
      );
      expect(
        VoiceStrings.tl.couldNotStart,
        isNot(VoiceStrings.en.couldNotStart),
      );
      expect(VoiceStrings.tl.couldNotPlay, isNot(VoiceStrings.en.couldNotPlay));
      expect(
        VoiceStrings.tl.backgroundStopped,
        isNot(VoiceStrings.en.backgroundStopped),
      );
    });
  });

  group('step images: which image goes with which step', () {
    test('the example steps from the design map to their pictures', () {
      expect(
        firstAidStepImageKey(
          'Clean hands thoroughly before managing the wound.',
        ),
        'wash_hands',
      );
      expect(
        firstAidStepImageKey(
          'Gently rinse the affected area with mild soap and clean running '
          'water to remove any loose debris.',
        ),
        'rinse_water',
      );
      expect(
        firstAidStepImageKey(
          'Pat the area dry gently with a clean cloth or sterile gauze.',
        ),
        'pat_dry',
      );
      expect(
        firstAidStepImageKey(
          'Apply a sterile non-stick dressing over the affected area to '
          'protect it from friction and contamination.',
        ),
        'apply_dressing',
      );
      expect(
        firstAidStepImageKey(
          'Change the dressing daily or whenever it becomes wet or dirty, '
          'and monitor for signs of infection such as spreading redness.',
        ),
        'change_dressing',
      );
    });

    test('only the action part counts, not the "why"', () {
      // The reason mentions "washes", "hands" etc. but the step is a rinse.
      expect(
        firstAidStepImageKey(
          'During: Rinse the scrape gently under clean running water. — '
          'Washes out dirt and keeps germs from your hands.',
        ),
        'rinse_water',
      );
      expect(
        firstAidStepImageKey(
          'Before: Wash your hands with soap and water. — Keeps germs out.',
        ),
        'wash_hands',
      );
    });

    test('other kinds', () {
      expect(
        firstAidStepImageKey('Apply gentle pressure with clean gauze.'),
        'apply_pressure',
      );
      expect(
        firstAidStepImageKey('Apply an antiseptic if available.'),
        'apply_antiseptic',
      );
      expect(
        firstAidStepImageKey('Apply a cold compress wrapped in cloth.'),
        'cold_compress',
      );
      expect(
        firstAidStepImageKey('Cool the burn under cool running water.'),
        'cool_burn',
      );
      expect(
        firstAidStepImageKey('Elevate the area above heart level.'),
        'elevate',
      );
    });

    test('the newer kinds', () {
      expect(
        firstAidStepImageKey('Do not pour alcohol or hydrogen peroxide on it.'),
        'avoid_harsh_product',
      );
      expect(
        firstAidStepImageKey(
          'Do not put butter, oil, toothpaste, or petroleum jelly on a burn.',
        ),
        'avoid_harsh_product',
      );
      expect(
        firstAidStepImageKey('Avoid touching or picking at the wound.'),
        'avoid_touching',
      );
      expect(
        firstAidStepImageKey('Do not pop any blisters that form.'),
        'avoid_touching',
      );
      expect(
        firstAidStepImageKey('Apply a thin layer of ointment if available.'),
        'apply_ointment',
      );
      expect(
        firstAidStepImageKey('Monitor the area for changes over the next day.'),
        'monitor_the_area',
      );
      expect(
        firstAidStepImageKey('Watch for signs of infection such as pus.'),
        'watch_infection',
      );
      expect(
        firstAidStepImageKey(
          'Go to the nearest emergency room right away if you feel faint.',
        ),
        'call_emergency',
      );
    });

    test(
      'a warning kind only applies to a step that starts with a "do not"',
      () {
        // This step mentions alcohol but is about applying an antiseptic.
        expect(
          firstAidStepImageKey(
            'Apply an antiseptic if available. Do not pour alcohol on the cut.',
          ),
          'apply_antiseptic',
        );
      },
    );

    test('every picture file in the folder has a step kind, and back', () {
      final onDisk = Directory('assets/images/first_aid')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.png'))
          .map((n) => n.substring(0, n.length - 4))
          .toSet();
      expect(onDisk, firstAidStepImageKeys.toSet());
    });

    test('a step that is none of these has no image', () {
      expect(firstAidStepImageKey('Seek medical advice soon.'), isNull);
      expect(firstAidStepImageKey('Take a deep breath and stay calm.'), isNull);
      // "advice" must not be read as "ice"
      expect(firstAidStepImageKey('Follow the advice of your doctor.'), isNull);
    });

    test('the file for each kind: assets/images/first_aid/<kind>.png', () {
      expect(
        firstAidStepImagePath('wash_hands'),
        'assets/images/first_aid/wash_hands.png',
      );
      for (final key in firstAidStepImageKeys) {
        expect(firstAidStepImagePath(key), endsWith('$key.png'));
        // every kind has a description in both languages
        expect(StepImageStrings.en.descriptions[key], isNotNull, reason: key);
        expect(StepImageStrings.tl.descriptions[key], isNotNull, reason: key);
        expect(
          StepImageStrings.tl.descriptions[key],
          isNot(StepImageStrings.en.descriptions[key]),
        );
      }
    });
  });

  group('step images: the slot on screen', () {
    Future<void> pump(
      WidgetTester tester,
      String? key,
      Map<String, Uint8List> files, {
      AppLanguage language = AppLanguage.en,
    }) async {
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(
            home: DefaultAssetBundle(
              bundle: _FakeBundle(files),
              child: Scaffold(
                body: Row(
                  children: [
                    FirstAidStepImage(imageKey: key),
                    const Expanded(child: Text('Step text')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no image for the step: nothing is drawn, no gap', (
      tester,
    ) async {
      await pump(tester, null, {});
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(FirstAidStepImage)), Size.zero);
      expect(tester.getTopLeft(find.text('Step text')).dx, 0);
    });

    testWidgets('the file is not in the app: nothing is drawn, no gap', (
      tester,
    ) async {
      await pump(tester, 'wash_hands', {});
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(FirstAidStepImage)), Size.zero);
      expect(tester.getTopLeft(find.text('Step text')).dx, 0);
    });

    testWidgets('the file is there: shown, square, with a description', (
      tester,
    ) async {
      await pump(tester, 'wash_hands', {
        'assets/images/first_aid/wash_hands.png': _png,
      });
      expect(find.byType(Image), findsOneWidget);
      final box = tester.getSize(find.byType(Image));
      expect(box.width, box.height);
      expect(box.width, inInclusiveRange(52, 76));
      expect(
        find.bySemanticsLabel(StepImageStrings.en.describe('wash_hands')),
        findsOneWidget,
      );
    });

    testWidgets('the description follows the language', (tester) async {
      await pump(tester, 'wash_hands', {
        'assets/images/first_aid/wash_hands.png': _png,
      }, language: AppLanguage.tl);
      expect(
        find.bySemanticsLabel(StepImageStrings.tl.describe('wash_hands')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(StepImageStrings.en.describe('wash_hands')),
        findsNothing,
      );
    });

    testWidgets('a broken image file hides the slot instead of crashing', (
      tester,
    ) async {
      await pump(tester, 'wash_hands', {
        'assets/images/first_aid/wash_hands.png': Uint8List.fromList([1, 2, 3]),
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FirstAidStepImage)), Size.zero);
    });
  });
}
