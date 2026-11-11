import 'dart:io';

import 'package:fine_aid/core/widgets/guest_usage_badge.dart';
import 'package:fine_aid/features/camera/screens/assessment_result_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:fine_aid/services/guest_usage_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A guest has 5 AI scans a day. The limit used to be checked only for chat
/// questions, so scanning with the AI camera never stopped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  String today() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  String source(String path) => File(path).readAsStringSync();

  test('five successful uses end the day; a new day starts again', () async {
    SharedPreferences.setMockInitialValues({});
    final usage = GuestUsageService.instance;
    expect(await usage.hasReachedLimit(), isFalse);
    for (var i = 0; i < GuestUsageService.dailyLimit; i++) {
      expect(await usage.hasReachedLimit(), isFalse);
      await usage.recordSuccessfulUse();
    }
    expect(await usage.hasReachedLimit(), isTrue);
    expect(usage.remaining, 0);

    // yesterday's count does not carry over
    SharedPreferences.setMockInitialValues({
      'guest_daily_usage_count': 5,
      'guest_daily_usage_date': '2000-01-01',
    });
    expect(await usage.hasReachedLimit(), isFalse);
    expect(usage.remaining, GuestUsageService.dailyLimit);
  });

  test('the AI camera and the scan itself both use the allowance', () {
    final camera = source('lib/features/camera/screens/ai_camera_screen.dart');
    // checked before the photo is taken, and only for the AI scan
    final gate = camera.indexOf('GuestUsageService.instance.hasReachedLimit()');
    expect(gate, greaterThan(0));
    expect(gate, lessThan(camera.indexOf('takePicture()')));
    expect(camera, contains('showGuestUsageLimitDialog(context)'));

    final result = source(
      'lib/features/camera/screens/assessment_result_screen.dart',
    );
    // checked before the analysis starts; counted only when an answer came back
    expect(
      result,
      contains('isGuest && await GuestUsageService.instance.hasReachedLimit()'),
    );
    expect(
      result,
      contains('if (isGuest && assessment.error == null)'),
    );
  });

  test('the camera shows the "left today" badge for the AI scan only', () {
    final camera = source('lib/features/camera/screens/ai_camera_screen.dart');
    expect(camera, contains("core/widgets/guest_usage_badge.dart"));
    expect(
      camera,
      contains('if (!widget.captureOnly && !_isAnalyzing)'),
    );
    expect(camera, contains('GuestUsageBadge('));
    // the badge sits between the preview and the shutter button
    expect(
      camera.indexOf('_buildCameraPreview(),'),
      lessThan(camera.indexOf('GuestUsageBadge(')),
    );
    expect(
      camera.indexOf('GuestUsageBadge('),
      lessThan(camera.indexOf('onTap: _isCapturing ? null : _handleCapture')),
    );
  });

  testWidgets('the badge shows what is left and counts down after a scan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'guest_daily_usage_count': 2,
      'guest_daily_usage_date': today(),
    });
    // the service is a singleton that an earlier test already used
    await GuestUsageService.instance.refresh();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GuestUsageBadge())),
    );
    await tester.pump();
    expect(find.text('3 of 5 left today (guest)'), findsOneWidget);
    await GuestUsageService.instance.recordSuccessfulUse();
    await tester.pump();
    expect(find.text('2 of 5 left today (guest)'), findsOneWidget);
  });

  testWidgets('a guest who used all 5 scans is stopped before the analysis', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'guest_daily_usage_count': GuestUsageService.dailyLimit,
      'guest_daily_usage_date': today(),
    });
    ConnectivityService().lastKnownOnline = true;
    addTearDown(() => ConnectivityService().lastKnownOnline = null);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppLanguageScope(
        language: AppLanguage.en,
        child: MaterialApp(
          routes: {'/registration': (_) => const SizedBox()},
          home: const Scaffold(body: Text('camera')),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const AssessmentResultScreen(
          imagePath: 'does-not-matter.jpg',
          woundHints: [],
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("Today's Limit Reached"), findsOneWidget);
    // closing the message also closes the result screen (back to where it came from)
    await tester.tap(find.text('OK'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AssessmentResultScreen), findsNothing);
    expect(find.text('camera'), findsOneWidget);
  });
}
