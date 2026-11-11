import 'package:fine_aid/features/admin/theme/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The admin's time-range selector (Last 7 days / 30 days / 12 months) shows
/// the chosen segment in gray, wherever it is used.
void main() {
  testWidgets('the chosen segment is gray, the others white', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.theme,
        home: Scaffold(
          body: Center(
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 7, label: Text('Last 7 days')),
                ButtonSegment(value: 30, label: Text('Last 30 days')),
                ButtonSegment(value: 12, label: Text('Last 12 months')),
              ],
              selected: const {30},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    Color? fillOf(String label) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      return material.color;
    }

    expect(fillOf('Last 30 days'), AdminTheme.segmentSelected);
    expect(fillOf('Last 7 days'), Colors.white);
    expect(fillOf('Last 12 months'), Colors.white);
    // Gray: equal red, green and blue (no pink tint).
    final c = AdminTheme.segmentSelected;
    expect(c.r == c.g && c.g == c.b, isTrue);
  });
}
