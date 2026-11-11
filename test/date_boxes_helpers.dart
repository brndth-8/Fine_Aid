import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The date picker's date is three boxes (month, day, year). These helpers
/// type into and read from them. [name] is "start" or "end".
Future<void> enterDate(WidgetTester tester, String name, String text) async {
  final digits = text.replaceAll('/', '');
  String part(int from, int to) => digits.length <= from
      ? ''
      : digits.substring(from, digits.length < to ? digits.length : to);
  Future<void> put(String box, String value) =>
      tester.enterText(find.byKey(ValueKey('$name-field-$box')), value);
  await put('mm', part(0, 2));
  await put('dd', part(2, 4));
  await put('yyyy', part(4, 8));
}

/// What the three boxes show, as "MM/DD/YYYY" ("" when all are empty).
String shownDate(WidgetTester tester, String name) {
  String box(String b) => tester
      .widget<TextField>(find.byKey(ValueKey('$name-field-$b')))
      .controller!
      .text;
  final parts = [box('mm'), box('dd'), box('yyyy')];
  return parts.every((p) => p.isEmpty) ? '' : parts.join('/');
}
