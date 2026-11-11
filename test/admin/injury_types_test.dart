import 'package:fine_aid/features/admin/screens/sections/admin_reports_analytics.dart';
import 'package:fine_aid/features/admin/screens/widgets/admin_charts.dart';
import 'package:fine_aid/i18n/journal_entry_strings.dart';
import 'package:fine_aid/services/api/gemini_service.dart' show WoundCategories;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Injury scan types" chart must count every category the app saves.
/// It used to count four manual-entry names, which almost no AI scan uses.
void main() {
  final grouped = <String, String>{
    for (final (label, names) in kInjuryGroups)
      for (final name in names) name: label,
  };

  test('every category the AI scan can save is counted somewhere', () {
    for (final name in WoundCategories.all) {
      // "Unable to Classify" is deliberately left to the catch-all line.
      if (name == WoundCategories.unableToClassify) continue;
      expect(grouped.containsKey(name), isTrue, reason: '$name is not charted');
    }
  });

  test('every category the manual journal form can save is counted too', () {
    for (final name in JournalEntryStrings.en.categoryNames.keys) {
      expect(grouped.containsKey(name), isTrue, reason: '$name is not charted');
    }
  });

  test(
    'no category is counted in two lines (they would be double-counted)',
    () {
      final all = [for (final (_, names) in kInjuryGroups) ...names];
      expect(all.toSet().length, all.length);
    },
  );

  test('a line asks for at most 30 names (the limit of one query)', () {
    for (final (label, names) in kInjuryGroups) {
      expect(names.length, lessThanOrEqualTo(30), reason: label);
    }
  });

  test('the old four-name list missed the AI scan names', () {
    // What the chart used to count (the four manual names, one of which the
    // app never even saves): none of the AI scan names were in it.
    const oldList = {
      'Injury (Wounds/laceration/Abrasion)',
      'Burns',
      'Skin Issues',
      'Animal Bite/Scratch',
    };
    final missed = WoundCategories.all.where((n) => !oldList.contains(n));
    expect(missed.length, WoundCategories.all.length);
  });

  group('the catch-all line', () {
    TrendSeries line(String name, {bool remainder = false}) => TrendSeries(
      name: name,
      color: Colors.red,
      marker: TrendMarker.circle,
      dash: TrendDash.solid,
      remainder: remainder,
    );

    test('shows what the other lines do not: total minus the groups', () {
      final series = [
        line('cuts'),
        line('burns'),
        line('other', remainder: true),
      ];
      // Three days: the groups count 3+1, 0+0 and 2+2 of a total 5, 4, 3.
      final drawn = withRemainders(series, [
        [3, 0, 2],
        [1, 0, 2],
        [5, 4, 3],
      ]);
      expect(drawn[0], [3, 0, 2]);
      expect(drawn[1], [1, 0, 2]);
      expect(drawn[2], [1, 4, 0], reason: 'entries no group claimed');
    });

    test('the lines always add up to every entry', () {
      final series = [line('a'), line('b'), line('rest', remainder: true)];
      final totals = [7, 0, 12];
      final drawn = withRemainders(series, [
        [2, 0, 5],
        [3, 0, 1],
        totals,
      ]);
      for (var day = 0; day < totals.length; day++) {
        expect(drawn[0][day] + drawn[1][day] + drawn[2][day], totals[day]);
      }
    });

    test('never goes below zero if the counts disagree', () {
      final series = [line('a'), line('rest', remainder: true)];
      final drawn = withRemainders(series, [
        [9],
        [4],
      ]);
      expect(drawn[1], [0]);
    });

    test('without a catch-all the counts are unchanged', () {
      final series = [line('a'), line('b')];
      final counts = [
        [1, 2],
        [3, 4],
      ];
      expect(withRemainders(series, counts), counts);
    });
  });
}
