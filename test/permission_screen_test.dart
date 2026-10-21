import 'package:fine_aid/features/auth/screens/permission_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The screen's existing checkbox-in-a-card layout trips Flutter's debug-only
// ListTile ink warning (also ignored in language_test.dart); unrelated.
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

  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final calls = <String>[];

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'requestPermissions':
              // 0 = denied. Camera permission code is 1.
              return <int, int>{1: 0};
            case 'checkPermissionStatus':
              return 0;
            case 'openAppSettings':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pump(WidgetTester tester) async {
    _ignoreListTileInkWarning();
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PermissionScreen()));
    await tester.pump();
  }

  testWidgets('there is no "Skip for now" option', (tester) async {
    await pump(tester);
    expect(find.text('Skip for now'), findsNothing);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    // Continue stays disabled until camera access is allowed.
    final button = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
  });

  testWidgets('a refusal shows the message and an Open Settings button, '
      'and does not move on or crash', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera access is turned off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    // Still on this screen, button usable again (no loading spinner stuck).
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PermissionScreen), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(calls, contains('openAppSettings'));
  });
}
