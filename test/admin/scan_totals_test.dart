import 'dart:convert';
import 'dart:io';

import 'package:fine_aid/features/admin/screens/widgets/admin_performance_card.dart';
import 'package:flutter_test/flutter_test.dart';

ScanTotals totals(int total, int failed, int erroneous) =>
    ScanTotals(total, failed, erroneous, DateTime(2026, 10, 23));

void main() {
  group('AI Scan Performance', () {
    test('is 100% when no scan failed or was marked wrong', () {
      expect(totals(40, 0, 0).performance, 100);
    });

    test(
      'is 0% (never NaN or a divide-by-zero) when there are no scans yet',
      () {
        final none = totals(0, 0, 0);
        expect(none.performance, 0);
        expect(none.performance.isNaN, isFalse);
        expect(none.failureRate, 0);
        expect(none.failureRate.isNaN, isFalse);
      },
    );

    test('every percentage stays within 0-100, whatever the counters say', () {
      for (final t in [
        totals(10, 50, 0), // more failures than scans
        totals(10, 0, 50),
        totals(10, 30, 30),
        totals(-5, 3, 3), // a nonsense total
        totals(0, 7, 7),
        totals(1000000, 0, 0),
      ]) {
        expect(t.performance, inInclusiveRange(0, 100), reason: '$t');
        expect(t.failureRate, inInclusiveRange(0, 100), reason: '$t');
      }
      expect(totals(10, 50, 0).failureRate, 100);
      expect(totals(10, 50, 0).performance, 0);
    });

    test(
      'percent() is part / total x 100, clamped, 0 with nothing to divide',
      () {
        expect(ScanTotals.percent(1, 4), 25);
        expect(ScanTotals.percent(0, 4), 0);
        expect(ScanTotals.percent(4, 4), 100);
        expect(ScanTotals.percent(9, 4), 100);
        expect(ScanTotals.percent(-3, 4), 0);
        expect(ScanTotals.percent(3, 0), 0);
        expect(ScanTotals.percent(3, -2), 0);
      },
    );

    test('drops with failed and erroneous scans: successful / total x 100', () {
      expect(totals(40, 4, 0).performance, 90);
      expect(totals(40, 0, 10).performance, 75);
      expect(totals(40, 4, 6).performance, 75);
      expect(totals(40, 4, 6).successful, 30);
    });

    test('never goes below 0% even if the counters disagree', () {
      final odd = totals(10, 8, 8);
      expect(odd.successful, 0);
      expect(odd.performance, 0);
    });

    test('the failure rate is failed / total x 100', () {
      expect(totals(40, 10, 0).failureRate, 25);
    });
  });

  group('errors per day', () {
    test('reports empty only when every day is zero', () {
      final days = [DateTime(2026, 10, 22), DateTime(2026, 10, 23)];
      expect(ScanErrorsByDay(days, [0, 0], [0, 0]).isEmpty, isTrue);
      expect(ScanErrorsByDay(days, [0, 1], [0, 0]).isEmpty, isFalse);
      expect(ScanErrorsByDay(days, [0, 0], [2, 0]).isEmpty, isFalse);
    });
  });

  group('satisfaction', () {
    ScanTotals rated(int satisfied, int notSatisfied) => ScanTotals(
      40,
      0,
      notSatisfied,
      DateTime(2026, 10, 30),
      satisfied: satisfied,
    );

    test('is satisfied / rated x 100, and null with no answers yet', () {
      expect(rated(0, 0).satisfactionRate, isNull);
      expect(rated(9, 1).satisfactionRate, 90);
      expect(rated(0, 4).satisfactionRate, 0);
      expect(rated(3, 1).rated, 4);
    });

    test('a wound type with no answers has no rate; otherwise a share', () {
      expect(const CategorySatisfaction('Burn', 0, 0).rate, isNull);
      expect(const CategorySatisfaction('Burn', 3, 1).rate, 75);
      expect(const CategorySatisfaction('Burn', 3, 1).rated, 4);
    });

    test('a day with only satisfied answers is not an "error" day', () {
      final days = [DateTime(2026, 10, 22), DateTime(2026, 10, 23)];
      expect(
        ScanErrorsByDay(days, [0, 0], [0, 0], satisfied: [2, 5]).isEmpty,
        isTrue,
      );
    });

    test('the app counts a satisfied answer per day, and the rules and '
        'indexes allow it', () {
      expect(
        File('lib/services/ai_scan_stats_service.dart').readAsStringSync(),
        contains("'satisfied': FieldValue.increment(right)"),
      );
      expect(
        File('firestore.rules').readAsStringSync(),
        contains("['day', 'failed', 'erroneous', 'satisfied']"),
      );
      final indexes =
          jsonDecode(File('firestore.indexes.json').readAsStringSync())
              as Map<String, dynamic>;
      final text = jsonEncode(indexes);
      expect(text, contains('"fieldPath":"ratedCorrect"'));
      expect(text, contains('"fieldPath":"resultSatisfied"'));
    });
  });
}
