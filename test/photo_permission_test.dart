import 'package:fine_aid/core/photo_permission.dart';
import 'package:fine_aid/features/journal/screens/new_entry_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/photo_strings.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGateway extends PhotoPermissionGateway {
  PermissionStatus status;
  final PermissionStatus afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  _FakeGateway(this.status, {this.afterRequest = PermissionStatus.granted});

  @override
  Future<PermissionStatus> cameraStatus() async => status;

  @override
  Future<PermissionStatus> requestCamera() async {
    requests++;
    status = afterRequest;
    return afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

void _ignoreListTileInkWarning() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains(
      'ListTile background color or ink splashes may be invisible',
    )) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = PhotoStrings.en;
  late bool? result;
  late bool finished;

  Future<void> run(
    WidgetTester tester,
    PhotoSource source, {
    AppLanguage language = AppLanguage.en,
  }) async {
    result = null;
    finished = false;
    await tester.pumpWidget(
      AppLanguageScope(
        language: language,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await ensurePhotoPermission(context, source);
                  finished = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => photoPermissionGateway = PhotoPermissionGateway());

  group('camera permission', () {
    testWidgets('already granted: no dialog, proceeds', (tester) async {
      final gateway = _FakeGateway(PermissionStatus.granted);
      photoPermissionGateway = gateway;
      await run(tester, PhotoSource.camera);
      expect(finished, isTrue);
      expect(result, isTrue);
      expect(find.text(en.cameraAccessTitle), findsNothing);
      expect(gateway.requests, 0);
    });

    testWidgets('explains first, then asks, then proceeds when granted', (
      tester,
    ) async {
      final gateway = _FakeGateway(PermissionStatus.denied);
      photoPermissionGateway = gateway;
      await run(tester, PhotoSource.camera);

      expect(find.text(en.cameraAccessTitle), findsOneWidget);
      expect(gateway.requests, 0, reason: 'explanation comes before the ask');

      await tester.tap(find.text(en.continueLabel));
      await tester.pumpAndSettle();
      expect(gateway.requests, 1);
      expect(result, isTrue);
    });

    testWidgets('"Not now" never shows the system request', (tester) async {
      final gateway = _FakeGateway(PermissionStatus.denied);
      photoPermissionGateway = gateway;
      await run(tester, PhotoSource.camera);
      await tester.tap(find.text(en.notNow));
      await tester.pumpAndSettle();
      expect(gateway.requests, 0);
      expect(result, isFalse);
    });

    testWidgets('denied: clear message with an Open Settings button', (
      tester,
    ) async {
      final gateway = _FakeGateway(
        PermissionStatus.denied,
        afterRequest: PermissionStatus.denied,
      );
      photoPermissionGateway = gateway;
      await run(tester, PhotoSource.camera);
      await tester.tap(find.text(en.continueLabel));
      await tester.pumpAndSettle();

      expect(find.text(en.cameraDeniedTitle), findsOneWidget);
      expect(find.text(en.cameraDeniedBody), findsOneWidget);

      await tester.tap(find.text(en.openSettings));
      await tester.pumpAndSettle();
      expect(gateway.settingsOpened, 1);
      expect(result, isFalse);
    });

    testWidgets('blocked for good: goes straight to the Settings message', (
      tester,
    ) async {
      final gateway = _FakeGateway(PermissionStatus.permanentlyDenied);
      photoPermissionGateway = gateway;
      await run(tester, PhotoSource.camera);
      expect(find.text(en.cameraAccessTitle), findsNothing);
      expect(find.text(en.cameraDeniedTitle), findsOneWidget);
      expect(gateway.requests, 0);

      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('the dialogs are available in Tagalog', (tester) async {
      photoPermissionGateway = _FakeGateway(PermissionStatus.denied);
      await run(tester, PhotoSource.camera, language: AppLanguage.tl);
      expect(find.text(PhotoStrings.tl.cameraAccessTitle), findsOneWidget);
      expect(find.text(en.cameraAccessTitle), findsNothing);
    });
  });

  group('gallery access', () {
    testWidgets('explained the first time, then goes straight through', (
      tester,
    ) async {
      await run(tester, PhotoSource.gallery);
      expect(find.text(en.galleryAccessTitle), findsOneWidget);
      await tester.tap(find.text(en.continueLabel));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await run(tester, PhotoSource.gallery);
      expect(find.text(en.galleryAccessTitle), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('declining the explanation does not open the gallery', (
      tester,
    ) async {
      await run(tester, PhotoSource.gallery);
      await tester.tap(find.text(en.notNow));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('Health Journal "Add Image"', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    testWidgets('offers Take photo and Upload image', (tester) async {
      _ignoreListTileInkWarning();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: NewEntryScreen()));
      await tester.pumpAndSettle();
      // guest warning on entry
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.addImage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(find.text(en.takePhoto), findsOneWidget);
      expect(find.text(en.uploadImage), findsOneWidget);
    });
  });

  test('every photo string is translated', () {
    expect(PhotoStrings.tl.takePhoto, isNot(en.takePhoto));
    expect(PhotoStrings.tl.cameraDeniedBody, isNot(en.cameraDeniedBody));
    expect(PhotoStrings.tl.galleryAccessBody, isNot(en.galleryAccessBody));
    expect(PhotoStrings.tl.retake, isNot(en.retake));
  });
}
