import 'dart:convert';

import 'package:fine_aid/core/widgets/evaluation_card.dart';
import 'package:fine_aid/services/export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _pages(List<int> pdf) => RegExp(
  r'/Type\s*/Page(?!s)',
).allMatches(latin1.decode(pdf, allowInvalid: true)).length;

Future<List<int>> _build({String? evaluation, String description = 'Cut'}) =>
    ExportService().buildEntryPdf(
      title: 'Cut on finger',
      description: description,
      classification: 'Injury',
      createdAt: DateTime(2026, 10, 18),
      monitoredDays: 3,
      evaluation: evaluation,
    );

void main() {
  test('the log exports with an Evaluation, blank, or very long', () async {
    expect(_pages(await _build(evaluation: 'Recorded as Injury.')), 1);
    // No evaluation: still a valid one-page log.
    expect(_pages(await _build(evaluation: null)), 1);
    expect(_pages(await _build(evaluation: '   ')), 1);
    // A very long Evaluation (and description) wraps and flows onto more
    // pages instead of overflowing or throwing.
    final long = List.filled(
      400,
      'This is a long evaluation sentence.',
    ).join(' ');
    expect(
      _pages(await _build(evaluation: long, description: long)),
      greaterThan(1),
    );
  });

  testWidgets('the Evaluation card has a border', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EvaluationCard(data: {'classification': 'Injury'}),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(EvaluationCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final deco = box.decoration! as BoxDecoration;
    expect(deco.border, isNotNull);
    expect(deco.borderRadius, BorderRadius.circular(16));
  });
}
