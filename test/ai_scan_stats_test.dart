import 'package:fine_aid/features/settings/screens/ai_scan_info_screen.dart';
import 'package:fine_aid/i18n/ai_scan_stats_strings.dart';
import 'package:fine_aid/i18n/app_language.dart';
import 'package:fine_aid/services/ai_scan_stats_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements AiScanStatsStore {
  final Map<String, int> counters = {};
  @override
  Future<void> add(Map<String, int> deltas) async =>
      deltas.forEach((k, d) => counters[k] = (counters[k] ?? 0) + d);
  @override
  Future<Map<String, int>> read() async => Map.of(counters);
}

class _BrokenStore implements AiScanStatsStore {
  @override
  Future<void> add(Map<String, int> deltas) => throw StateError('boom');
  @override
  Future<Map<String, int>> read() => throw StateError('boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rates', () {
    test('no scans -> every rate is "no data", never a divide-by-zero', () {
      const stats = AiScanStats();
      expect(stats.successRate, isNull);
      expect(stats.failureRate, isNull);
      expect(stats.accuracyRate, isNull);
      expect(stats.reliability, isNull);
    });

    test('success and failure rate are out of all scans', () {
      const stats = AiScanStats(total: 10, success: 7, failed: 2, noWound: 1);
      expect(stats.successRate, closeTo(70, 0.001));
      expect(stats.failureRate, closeTo(20, 0.001));
    });

    test('accuracy only counts scans the user rated', () {
      const stats = AiScanStats(
        total: 10,
        success: 8,
        ratedCorrect: 3,
        ratedWrong: 1,
      );
      expect(stats.accuracyRate, closeTo(75, 0.001));
      expect(const AiScanStats(total: 5, success: 5).accuracyRate, isNull);
    });

    test('reliability = completed and not marked wrong, out of all scans', () {
      const stats = AiScanStats(
        total: 10,
        success: 8,
        failed: 2,
        ratedWrong: 2,
        ratedCorrect: 1,
      );
      expect(stats.reliability, closeTo(60, 0.001));
    });

    test('reliability never goes below 0', () {
      const stats = AiScanStats(total: 3, success: 1, ratedWrong: 5);
      expect(stats.reliability, 0);
    });

    test('counters read back from storage (negatives ignored)', () {
      final stats = AiScanStats.fromCounters({
        'total': 4,
        'success': 3,
        'failed': 1,
        'failed_timeout': 1,
        'ratedWrong': -2,
      });
      expect(stats.total, 4);
      expect(stats.failedByReason, {ScanFailureReason.timeout: 1});
      expect(stats.ratedWrong, 0);
    });
  });

  group('failure reasons from the error text', () {
    test('maps the usual errors', () {
      expect(
        failureReasonFromError('Exception: Analysis timed out. Try again.'),
        ScanFailureReason.timeout,
      );
      expect(
        failureReasonFromError('SocketException: Failed host lookup'),
        ScanFailureReason.offline,
      );
      expect(
        failureReasonFromError('FormatException: Unexpected character'),
        ScanFailureReason.unreadableResponse,
      );
      expect(
        failureReasonFromError('FileSystemException: Cannot open file'),
        ScanFailureReason.unreadableImage,
      );
      expect(
        failureReasonFromError('Server returned 503'),
        ScanFailureReason.serverError,
      );
    });
  });

  group('counting scans', () {
    late _MemoryStore store;
    late AiScanStatsService service;

    setUp(() {
      store = _MemoryStore();
      service = AiScanStatsService(storeFactory: () => store);
    });

    test('a successful scan adds to total and successful', () async {
      service.recordSuccess();
      final stats = await service.load();
      expect(stats.total, 1);
      expect(stats.success, 1);
      expect(stats.failed, 0);
    });

    test('a failed scan adds to total and failed, with its reason', () async {
      service.recordFailure(ScanFailureReason.timeout);
      service.recordFailure(ScanFailureReason.offline);
      service.recordFailure(ScanFailureReason.timeout);
      final stats = await service.load();
      expect(stats.total, 3);
      expect(stats.failed, 3);
      expect(stats.success, 0);
      expect(stats.failedByReason, {
        ScanFailureReason.timeout: 2,
        ScanFailureReason.offline: 1,
      });
    });

    test('"no wound found" is counted, but is not a failure', () async {
      service.recordNoWound();
      final stats = await service.load();
      expect(stats.total, 1);
      expect(stats.noWound, 1);
      expect(stats.failed, 0);
      expect(stats.success, 0);
    });

    test('a rating is counted once, and changing it moves the count', () async {
      service.recordSuccess();
      service.recordRating(previous: null, current: true);
      expect((await service.load()).ratedCorrect, 1);

      service.recordRating(previous: true, current: false);
      var stats = await service.load();
      expect(stats.ratedCorrect, 0);
      expect(stats.ratedWrong, 1);

      // taking the answer back
      service.recordRating(previous: false, current: null);
      stats = await service.load();
      expect(stats.ratedCorrect, 0);
      expect(stats.ratedWrong, 0);
    });

    test('nothing stored about the photo or the person', () async {
      service.recordSuccess();
      service.recordFailure(ScanFailureReason.serverError);
      for (final key in store.counters.keys) {
        expect(
          key,
          anyOf(
            'total',
            'success',
            'failed',
            'noWound',
            'ratedCorrect',
            'ratedWrong',
            startsWith('failed_'),
          ),
        );
      }
    });

    test('a storage problem never breaks a scan', () async {
      final broken = AiScanStatsService(storeFactory: _BrokenStore.new);
      expect(() => broken.recordSuccess(), returnsNormally);
      expect(
        () => broken.recordFailure(ScanFailureReason.timeout),
        returnsNormally,
      );
      expect((await broken.load()).total, 0);
    });
  });

  group('device-only storage (not signed in)', () {
    test('counts add up and survive reading back', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalAiScanStatsStore();
      await store.add({'total': 1, 'success': 1});
      await store.add({'total': 1, 'failed': 1, 'failed_offline': 1});
      final stats = AiScanStats.fromCounters(await store.read());
      expect(stats.total, 2);
      expect(stats.success, 1);
      expect(stats.failedByReason, {ScanFailureReason.offline: 1});
    });
  });

  group('About the AI scan screen', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    Future<void> pump(
      WidgetTester tester,
      AiScanStatsService service, {
      AppLanguage language = AppLanguage.en,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppLanguageScope(
          language: language,
          child: MaterialApp(home: AiScanInfoScreen(service: service)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no scans yet: "No data yet", no crash', (tester) async {
      await pump(
        tester,
        AiScanStatsService(storeFactory: () => _MemoryStore()),
      );
      final s = AiScanStatsStrings.en;
      expect(find.text(s.screenTitle), findsOneWidget);
      expect(
        find.text(s.noDataYet),
        findsNWidgets(3),
      ); // reliability, success, failure
      expect(find.text(s.noFeedbackYet), findsOneWidget); // accuracy
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    });

    testWidgets('shows the counters, rates and failure reasons', (
      tester,
    ) async {
      final store = _MemoryStore()
        ..counters.addAll({
          'total': 4,
          'success': 2,
          'failed': 1,
          'failed_timeout': 1,
          'noWound': 1,
          'ratedCorrect': 1,
        });
      await pump(tester, AiScanStatsService(storeFactory: () => store));
      final s = AiScanStatsStrings.en;
      expect(find.text('50.0%'), findsNWidgets(2)); // reliability + success
      expect(find.text('25.0%'), findsOneWidget); // failure rate
      expect(find.text('100.0%'), findsOneWidget); // accuracy of rated
      expect(find.text(s.reasons[ScanFailureReason.timeout]!), findsOneWidget);
    });

    testWidgets('is available in Tagalog', (tester) async {
      await pump(
        tester,
        AiScanStatsService(storeFactory: () => _MemoryStore()),
        language: AppLanguage.tl,
      );
      expect(find.text(AiScanStatsStrings.tl.screenTitle), findsOneWidget);
      expect(find.text(AiScanStatsStrings.tl.noDataYet), findsNWidgets(3));
    });
  });

  test('every scan-stats string is translated', () {
    final en = AiScanStatsStrings.en;
    final tl = AiScanStatsStrings.tl;
    expect(tl.screenTitle, isNot(en.screenTitle));
    expect(tl.feedbackQuestion, isNot(en.feedbackQuestion));
    expect(tl.noDataYet, isNot(en.noDataYet));
    for (final reason in ScanFailureReason.values) {
      expect(tl.reasons[reason], isNotNull);
      expect(tl.reasons[reason], isNot(en.reasons[reason]));
    }
  });
}
