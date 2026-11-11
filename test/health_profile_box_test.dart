import 'package:fine_aid/core/widgets/health_profile_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Map<String, dynamic>? profile, {
    List<String> meds = const [],
    bool tagalog = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HealthProfileBox(
          profile: profile,
          medications: meds,
          tagalog: tagalog,
        ),
      ),
    ),
  );

  testWidgets('a condition that was not in the list is named in the box', (
    tester,
  ) async {
    await show(tester, {'otherCondition': 'Lupus'});
    expect(find.text('Based on Your Health Profile'), findsOneWidget);
    expect(
      find.textContaining('Health conditions noted: Lupus.'),
      findsOneWidget,
    );
    expect(find.textContaining("You've noted Lupus"), findsOneWidget);
  });

  testWidgets('eczema, conditions from the list and medication together', (
    tester,
  ) async {
    await show(
      tester,
      {'diabetes': true, 'diabetesType': 'type2', 'otherCondition': 'Eczema'},
      meds: ['Metformin'],
    );
    expect(find.textContaining('Type 2 Diabetes and Eczema'), findsOneWidget);
    expect(find.text('You are taking Metformin.'), findsOneWidget);
    expect(find.textContaining("You've noted diabetes"), findsOneWidget);
    expect(find.textContaining("You've noted eczema"), findsOneWidget);
  });

  testWidgets('a guest who said "none" gets no box', (tester) async {
    await show(tester, <String, dynamic>{});
    expect(find.byType(Container), findsNothing);
    await show(tester, null);
    expect(find.text('Based on Your Health Profile'), findsNothing);
  });

  testWidgets('medication alone is shown', (tester) async {
    await show(tester, null, meds: ['Paracetamol']);
    expect(find.text('You are taking Paracetamol.'), findsOneWidget);
  });

  testWidgets('Filipino', (tester) async {
    await show(tester, {'otherCondition': 'Lupus'}, tagalog: true);
    expect(find.text('Batay sa Iyong Health Profile'), findsOneWidget);
    expect(
      find.textContaining('Mga kondisyong nabanggit: Lupus.'),
      findsOneWidget,
    );
  });

  test('linesFor is empty when there is nothing to say', () {
    expect(
      HealthProfileBox.linesFor(profile: null, medications: [], tagalog: false),
      isEmpty,
    );
  });
}
