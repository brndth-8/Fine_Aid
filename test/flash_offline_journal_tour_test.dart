import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fine_aid/core/widgets/help_tour_overlay.dart';
import 'package:fine_aid/core/widgets/pain_scale_dialog.dart';
import 'package:fine_aid/data/journal_evaluation.dart';
import 'package:fine_aid/features/auth/screens/login_screen.dart';
import 'package:fine_aid/features/camera/screens/ai_camera_screen.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/assessment_strings.dart';
import 'package:fine_aid/i18n/evaluation_strings.dart';
import 'package:fine_aid/i18n/help_content_en.dart';
import 'package:fine_aid/i18n/help_content_tl.dart';
import 'package:fine_aid/i18n/help_document.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:fine_aid/i18n/screen_text_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A camera that records what it was asked to do, in order.
class _FakeCamera extends CameraPlatform with MockPlatformInterfaceMixin {
  final calls = <String>[];

  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      StreamController<CameraClosingEvent>.broadcast().stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      StreamController<CameraErrorEvent>.broadcast().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      StreamController<DeviceOrientationChangedEvent>.broadcast().stream;

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      calls.add('flash:${mode.name}');

  @override
  Future<XFile> takePicture(int cameraId) async {
    calls.add('takePicture');
    return XFile('missing_photo.jpg');
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async => calls.add('dispose');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  String source(String path) => File(path).readAsStringSync();

  group('1. The flashlight never stays on', () {
    late _FakeCamera camera;
    late CameraPlatform previous;

    setUp(() {
      previous = CameraPlatform.instance;
      camera = _FakeCamera();
      CameraPlatform.instance = camera;
    });
    tearDown(() => CameraPlatform.instance = previous);

    Future<void> openCamera(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiCameraScreen(captureOnly: true),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> torchOn(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Turn flashlight on'));
      await tester.pumpAndSettle();
      expect(camera.calls, contains('flash:torch'));
      expect(find.byTooltip('Turn flashlight off'), findsOneWidget);
    }

    testWidgets('it goes off once the photo is taken', (tester) async {
      await openCamera(tester);
      await torchOn(tester);

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      final afterPhoto = camera.calls.sublist(
        camera.calls.indexOf('takePicture'),
      );
      expect(afterPhoto, contains('flash:off'));
    });

    testWidgets('it goes off when the app goes to the background, and the '
        'button shows it', (tester) async {
      await openCamera(tester);
      await torchOn(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(camera.calls.last, 'flash:off');
      // (no frames are drawn while the app is in the background)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Turn flashlight on'), findsOneWidget);
    });

    testWidgets('it goes off before the camera is released when the screen '
        'is left', (tester) async {
      await openCamera(tester);
      await torchOn(tester);

      Navigator.of(tester.element(find.byType(AiCameraScreen))).pop();
      await tester.pumpAndSettle();

      final off = camera.calls.lastIndexOf('flash:off');
      final disposed = camera.calls.indexOf('dispose');
      expect(off, greaterThan(camera.calls.lastIndexOf('flash:torch')));
      expect(disposed, greaterThan(off), reason: camera.calls.toString());
    });

    testWidgets('with the flashlight off nothing extra is sent', (
      tester,
    ) async {
      await openCamera(tester);
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(camera.calls, isNot(contains('flash:off')));
      expect(camera.calls, isNot(contains('flash:torch')));
    });
  });

  group('2. Health Journal opens offline', () {
    test('a photo that cannot load shows a placeholder, never an error', () {
      for (final path in [
        'lib/features/journal/screens/journal_list_screen.dart',
        'lib/features/journal/screens/entry_detail_screen.dart',
      ]) {
        final text = source(path);
        final images = RegExp(r'Image\.network\(').allMatches(text).length;
        final handled = RegExp(r'errorBuilder:').allMatches(text).length;
        expect(handled, greaterThanOrEqualTo(images), reason: path);
      }
    });

    testWidgets('a broken photo link draws the placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Image.network(
            'http://invalid.invalid/photo.jpg',
            errorBuilder: (_, _, _) => const Icon(Icons.cloud_off_outlined),
          ),
        ),
      );
      // (the test binding answers every request with an error)
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  group('3. Itchiness scale in the Add Entry form', () {
    Future<void> open(
      WidgetTester tester, {
      AppLanguage l = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 5200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: l,
          child: const MaterialApp(home: NewEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ScreenText.forLanguage(l).continueAsGuest));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String key) async {
      final names = JournalEntryStrings.en.categoryNames;
      await tester.tap(find.text(names[key]!).first);
      await tester.pumpAndSettle();
      // the info pop-up: Confirm
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(confirm.first);
      await tester.pumpAndSettle();
    }

    final itchTitle = find.text(AssessmentStrings.en.itchTitle);

    testWidgets('only a Skin Issues entry gets the itchiness scale, after '
        'the pain scale', (tester) async {
      await open(tester);
      expect(itchTitle, findsNothing);

      await pick(tester, 'Burns');
      expect(itchTitle, findsNothing);

      await pick(tester, 'Skin Issues');
      expect(itchTitle, findsOneWidget);
      expect(find.byType(PainScaleSelector), findsNWidgets(2));
      // pain first, then itchiness
      final pain = tester.getTopLeft(find.byType(PainScaleSelector).first);
      final itch = tester.getTopLeft(find.byType(PainScaleSelector).last);
      expect(itch.dy, greaterThan(pain.dy));

      // the category tiles are above the pain scale
      final category = tester.getTopLeft(
        find.text(JournalEntryStrings.en.categoryHeading),
      );
      expect(category.dy, lessThan(pain.dy));

      // choosing another category takes it away again
      await pick(tester, 'Scratch');
      expect(itchTitle, findsNothing);
      expect(find.byType(PainScaleSelector), findsOneWidget);
    });

    testWidgets('the itchiness scale uses the app language', (tester) async {
      await open(tester, l: AppLanguage.tl);
      await tester.tap(
        find.text(JournalEntryStrings.tl.categoryNames['Skin Issues']!).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text(AssessmentStrings.tl.itchTitle), findsOneWidget);
      expect(find.text(AssessmentStrings.en.itchTitle), findsNothing);
    });

    test('the entry saves the itchiness, and old entries still work', () {
      final text = source('lib/features/journal/screens/new_entry_screen.dart');
      expect(text, contains("if (_isSkinIssue) 'itchScore': _itchScore,"));
      expect(text, contains('strings.itchRequired'));
      expect(
        JournalEntryStrings.tl.itchRequired,
        isNot(JournalEntryStrings.en.itchRequired),
      );
    });

    test('the saved itchiness is shown in the entry\'s Evaluation', () {
      Map<String, dynamic> entry({Object? itch}) => {
        'classification': 'Skin Issues',
        'painScore': 2,
        'painScaleMax': 5,
        'itchScore': ?itch,
      };
      final withItch = buildJournalEvaluation(entry(itch: 4), tagalog: false)!;
      expect(withItch, contains('Reported itchiness: 4/5 (Severe).'));
      final tl = buildJournalEvaluation(entry(itch: 4), tagalog: true)!;
      expect(tl, contains('Iniulat na antas ng pangangati: 4/5'));
      expect(
        EvaluationStrings.tl.itchFormat,
        isNot(EvaluationStrings.en.itchFormat),
      );
      // an older entry has none: no itchiness sentence, and no error
      final old = buildJournalEvaluation(entry(), tagalog: false)!;
      expect(old, isNot(contains('itchiness')));
    });
  });

  group('4. The landing page checks the connection first', () {
    Future<void> openLanding(
      WidgetTester tester, {
      required Future<bool> Function() isOnline,
      AppLanguage l = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget page(String name) => Scaffold(body: Center(child: Text(name)));
      await tester.pumpWidget(
        AppLanguageScope(
          language: l,
          child: MaterialApp(
            home: LoginScreen(isOnline: isOnline),
            routes: {
              '/login-form': (_) => page('LOGIN FORM'),
              '/registration': (_) => page('SIGN UP FORM'),
              '/dashboard': (_) => page('DASHBOARD'),
            },
          ),
        ),
      );
      await tester.pump();
    }

    final en = ScreenText.en;

    for (final label in [
      ScreenText.en.logIn,
      ScreenText.en.createAccount,
      ScreenText.en.continueAsGuest,
    ]) {
      testWidgets('offline: "$label" shows the prompt first, and goes in only '
          'after Proceed to Offline Mode', (tester) async {
        await openLanding(tester, isOnline: () async => false);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        // the prompt, and nothing opened yet
        expect(find.text(en.offlineTitle), findsOneWidget);
        expect(find.text(en.offlineEntryBody), findsOneWidget);
        expect(find.text(en.proceedOffline), findsOneWidget);
        expect(find.text(en.tryAgain), findsOneWidget);
        for (final p in ['LOGIN FORM', 'SIGN UP FORM', 'DASHBOARD']) {
          expect(find.text(p), findsNothing, reason: p);
        }

        // confirming enters Offline Mode (the app's offline home)
        await tester.tap(find.text(en.proceedOffline));
        await tester.pumpAndSettle();
        expect(find.text('DASHBOARD'), findsOneWidget);
      });
    }

    testWidgets('closing the prompt does nothing', (tester) async {
      await openLanding(tester, isOnline: () async => false);
      await tester.tap(find.text(en.continueAsGuest));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the prompt
      await tester.pumpAndSettle();
      expect(find.text(en.offlineTitle), findsNothing);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text(en.logIn), findsOneWidget); // still on the landing page
    });

    testWidgets('Try Again while still offline says so and keeps the prompt', (
      tester,
    ) async {
      await openLanding(tester, isOnline: () async => false);
      await tester.tap(find.text(en.logIn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();
      expect(find.text(en.stillOffline), findsOneWidget);
      expect(find.text(en.offlineTitle), findsOneWidget);
    });

    testWidgets('Try Again with the internet back does what was tapped', (
      tester,
    ) async {
      var online = false;
      await openLanding(tester, isOnline: () async => online);
      await tester.tap(find.text(en.createAccount));
      await tester.pumpAndSettle();
      online = true;
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();
      expect(find.text(en.offlineTitle), findsNothing);
      expect(find.text('SIGN UP FORM'), findsOneWidget);
    });

    testWidgets('online: the buttons work at once, no prompt', (tester) async {
      await openLanding(tester, isOnline: () async => true);
      await tester.tap(find.text(en.logIn));
      await tester.pumpAndSettle();
      expect(find.text(en.offlineTitle), findsNothing);
      expect(find.text('LOGIN FORM'), findsOneWidget);
    });

    testWidgets('a broken connection check never locks anyone out', (
      tester,
    ) async {
      await openLanding(tester, isOnline: () async => throw Exception('x'));
      await tester.tap(find.text(en.continueAsGuest));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('the prompt is in Tagalog too', (tester) async {
      await openLanding(tester, isOnline: () async => false, l: AppLanguage.tl);
      await tester.tap(find.text(ScreenText.tl.continueAsGuest));
      await tester.pumpAndSettle();
      expect(find.text(ScreenText.tl.offlineTitle), findsOneWidget);
      expect(find.text(ScreenText.tl.proceedOffline), findsOneWidget);
      expect(find.text(ScreenText.tl.tryAgain), findsOneWidget);
    });

    test('someone already inside who loses internet is not affected', () {
      // The gate is only on the landing page's three buttons; the dashboard's
      // own offline handling is unchanged.
      final dashboard = source(
        'lib/features/dashboard/screens/dashboard_screen.dart',
      );
      expect(dashboard, contains('if (!_isOnline)'));
      expect(dashboard, isNot(contains('enterOnlineOrOffline')));
      expect(
        source('lib/features/auth/screens/login_screen.dart'),
        contains('enterOnlineOrOffline('),
      );
    });
  });

  group('5. Help tour: Skip Tour is a close (x) in the corner', () {
    testWidgets('the x ends the tour; there is no Skip button', (tester) async {
      var finished = 0;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HelpTourOverlay(
                  steps: const [
                    HelpTourStep(title: 'Welcome', description: 'one'),
                    HelpTourStep(title: 'Two', description: 'two'),
                    HelpTourStep(title: 'Three', description: 'three'),
                  ],
                  skipLabel: 'Skip Tour',
                  onFinished: () => finished++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // not a text button any more
      expect(find.text('Skip Tour'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Skip Tour'), findsNothing);
      // the x sits in the top-right corner of the card, and says what it does
      final x = find.byTooltip('Skip Tour');
      expect(x, findsOneWidget);
      final card = tester.getRect(find.byKey(const ValueKey(0)));
      final xCenter = tester.getCenter(x);
      expect(xCenter.dx, greaterThan(card.center.dx));
      expect(xCenter.dy, lessThan(card.center.dy));
      expect(card.contains(xCenter), isTrue);

      // the rest of the card is as before: the step counter and Next
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Next'), findsOneWidget);

      // tapping it ends the tour, as Skip did
      await tester.tap(x);
      await tester.pump();
      expect(finished, 1);
    });

    testWidgets('the last step has Done and no x, as before', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HelpTourOverlay(
                  steps: const [
                    HelpTourStep(title: 'A', description: 'a'),
                    HelpTourStep(title: 'B', description: 'b'),
                  ],
                  onFinished: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Skip Tour'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);
    });
  });

  group('6. References: Doctor review is its own section', () {
    for (final (name, section) in [
      ('English', helpReferencesEn),
      ('Tagalog', helpReferencesTl),
    ]) {
      test('$name: the Doctor review follows its own heading, after the '
          'verified sources', () {
        final blocks = section.blocks;
        final groups = [
          for (var i = 0; i < blocks.length; i++)
            if (blocks[i] is HelpGroup) i,
        ];
        // WHO, PRC, MIMS, DOH, and the Doctor review: five groups
        expect(groups.length, 5);
        final doctor = groups.last;
        expect(blocks[doctor - 1], isA<HelpHeading>());
        // the four sources are still together, ahead of that heading
        expect(groups.sublist(0, 4), [
          groups[0],
          groups[0] + 1,
          groups[0] + 2,
          groups[0] + 3,
        ]);
        expect(doctor - 1, groups[3] + 1);
      });
    }

    test('the English heading and group names match the design', () {
      final heading = helpReferencesEn.blocks
          .whereType<HelpHeading>()
          .map((h) => h.text)
          .toList();
      expect(heading, contains('Medical Review and Clinical Governance'));
      final groups = helpReferencesEn.blocks.whereType<HelpGroup>().toList();
      expect(
        groups.last.title,
        'Doctor-Reviewed Content & Clinical Governance',
      );
      expect(groups.length, 5);
    });
  });
}
