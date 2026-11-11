import 'package:fine_aid/services/ai_scan_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts what it is given; can be made to fail.
class _Store implements AiScanStatsStore {
  final Map<String, int> counters = {};
  bool failing = false;
  int calls = 0;

  @override
  Future<void> add(Map<String, int> deltas) async {
    calls++;
    if (failing) throw Exception('no connection');
    deltas.forEach((k, d) => counters[k] = (counters[k] ?? 0) + d);
  }

  @override
  Future<Map<String, int>> read() async => counters;
}

void main() {
  group('Guest Mode scan counters also go to the shared guest counters', () {
    test(
      'a rating is counted on the phone AND in the shared counters',
      () async {
        final local = _Store();
        final remote = _Store();
        final service = AiScanStatsService(
          storeFactory: () => GuestAiScanStatsStore(local, remote),
        );
        service.recordSuccess();
        service.recordRating(previous: null, current: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        for (final store in [local, remote]) {
          expect(store.counters['total'], 1);
          expect(store.counters['success'], 1);
          expect(store.counters['ratedCorrect'], 1);
        }
      },
    );

    test('changing the answer moves the count in both places', () async {
      final local = _Store();
      final remote = _Store();
      final service = AiScanStatsService(
        storeFactory: () => GuestAiScanStatsStore(local, remote),
      );
      service.recordRating(previous: null, current: true);
      service.recordRating(previous: true, current: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (final store in [local, remote]) {
        expect(store.counters['ratedCorrect'], 0);
        expect(store.counters['ratedWrong'], 1);
      }
    });

    test('a failed shared write never loses the local count', () async {
      final local = _Store();
      final remote = _Store()..failing = true;
      final store = GuestAiScanStatsStore(local, remote);
      await store.add({'total': 1, 'failed': 1});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.calls, 1);
      expect(local.counters, {'total': 1, 'failed': 1});
    });

    test('the guest reads their own counts from the phone', () async {
      final local = _Store()..counters['total'] = 4;
      final remote = _Store()..counters['total'] = 900;
      final store = GuestAiScanStatsStore(local, remote);
      expect(await store.read(), {'total': 4});
    });
  });
}
