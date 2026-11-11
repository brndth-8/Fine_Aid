import 'package:fine_aid/core/widgets/help_tour_launcher.dart';
import 'package:fine_aid/features/dashboard/first_aid_kit_screen.dart';
import 'package:fine_aid/features/dashboard/screens/dashboard_screen.dart';
import 'package:fine_aid/features/settings/screens/feedback_screen.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/i18n/offline_strings.dart';
import 'package:fine_aid/services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  void phone(WidgetTester tester, {double h = 2400}) {
    tester.view.physicalSize = Size(900, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void offline(bool value) {
    ConnectivityService().lastKnownOnline = !value;
    addTearDown(() => ConnectivityService().lastKnownOnline = null);
  }

  Widget app(AppLanguage l, Widget home) => AppLanguageScope(
    language: l,
    child: MaterialApp(home: home),
  );

  group('D1. Health Kit notice when offline', () {
    for (final l in AppLanguage.values) {
      testWidgets('${l.name}: shown first, then the kit', (tester) async {
        offline(true);
        phone(tester);
        final s = l == AppLanguage.tl ? OfflineStrings.tl : OfflineStrings.en;
        await tester.pumpWidget(app(l, const FirstAidKitScreen()));
        await tester.pumpAndSettle();
        expect(find.text(s.kitNoticeBody), findsOneWidget);
        // only the button closes it
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text(s.kitNoticeBody), findsOneWidget);
        await tester.tap(find.text(s.understood));
        await tester.pumpAndSettle();
        expect(find.text(s.kitNoticeBody), findsNothing);
        expect(find.byType(FirstAidKitScreen), findsOneWidget);
      });
    }

    testWidgets('online: no notice', (tester) async {
      offline(false);
      phone(tester);
      await tester.pumpWidget(app(AppLanguage.en, const FirstAidKitScreen()));
      await tester.pumpAndSettle();
      expect(find.text(OfflineStrings.en.kitNoticeBody), findsNothing);
    });

    test('the exact English wording; Filipino differs', () {
      expect(
        OfflineStrings.en.kitNoticeBody,
        'This is only for users with no recognized health conditions. If you '
        'have a specific medical condition, we advise you to seek '
        'professional help to ensure you receive specialized care.',
      );
      expect(
        OfflineStrings.tl.kitNoticeBody,
        isNot(OfflineStrings.en.kitNoticeBody),
      );
      expect(OfflineStrings.tl.understood, isNot(OfflineStrings.en.understood));
    });
  });

  group('D2. Help Tour in Offline Mode: first time only', () {
    // The dashboard keeps timers running: close it before the test ends.
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    }

    Future<void> openDashboard(WidgetTester tester) async {
      phone(tester, h: 1800);
      await tester.pumpWidget(app(AppLanguage.en, const DashboardScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('the first offline visit starts the tour by itself', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      offline(true);
      await openDashboard(tester);
      expect(find.byTooltip('Skip Tour'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('offline_help_tour_seen'), isTrue);
      await close(tester);
    });

    testWidgets('later offline visits do not', (tester) async {
      SharedPreferences.setMockInitialValues({'offline_help_tour_seen': true});
      offline(true);
      await openDashboard(tester);
      expect(find.byTooltip('Skip Tour'), findsNothing);
      await close(tester);
    });

    testWidgets('Replay Help Tour still starts it, offline', (tester) async {
      SharedPreferences.setMockInitialValues({'offline_help_tour_seen': true});
      offline(true);
      await openDashboard(tester);
      expect(find.byTooltip('Skip Tour'), findsNothing);
      HelpTourLauncher.instance.requestTour();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Skip Tour'), findsOneWidget);
      await close(tester);
    });
  });

  group('D3. Feedback rating when offline', () {
    testWidgets('the stars are disabled, like the text box', (tester) async {
      offline(true);
      phone(tester, h: 1600);
      await tester.pumpWidget(app(AppLanguage.en, const FeedbackScreen()));
      await tester.pumpAndSettle();
      final stars = find.widgetWithIcon(IconButton, Icons.star_border);
      expect(stars, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(tester.widget<IconButton>(stars.at(i)).onPressed, isNull);
      }
      await tester.tap(stars.at(2), warnIfMissed: false);
      await tester.pump();
      expect(find.byIcon(Icons.star), findsNothing); // nothing got rated
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('online the stars work', (tester) async {
      offline(false);
      phone(tester, h: 1600);
      await tester.pumpWidget(app(AppLanguage.en, const FeedbackScreen()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.star_border).at(2),
      );
      await tester.pump();
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });
  });
}
