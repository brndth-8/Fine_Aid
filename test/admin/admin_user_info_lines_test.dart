import 'dart:ui' as ui;

import 'package:fine_aid/features/admin/screens/widgets/admin_user_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the details pop-up and reads real pixels: the line under every row
/// must be visible in the tinted label column as well as the value column,
/// and the two columns must be divided by a line.
void main() {
  testWidgets('row lines run across the label and value columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdminUserInfo(context, const {
                  'username': 'maria',
                  'firstName': 'Maria',
                  'lastName': 'Santos',
                }),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int red(double x, double y) =>
        data.getUint8(((y.round()) * image.width + x.round()) * 4);

    // The tinted label background is 0xFB and white is 0xFF; a line must pull
    // a pixel clearly below that (even half-blended onto a pixel boundary).
    const visible = 0xEE;
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('admin-info-row-'),
    );
    expect(rows, findsWidgets);

    var checked = 0;
    for (final element in rows.evaluate().take(5)) {
      final rect = tester.getRect(find.byWidget(element.widget));
      final labelX = rect.left + 24;
      final valueX = rect.right - 24;
      int darkest(double x) => [
        for (var dy = -2.0; dy <= 1.0; dy++) red(x, rect.bottom + dy),
      ].reduce((a, b) => a < b ? a : b);
      expect(darkest(labelX), lessThan(visible), reason: 'label column line');
      expect(darkest(valueX), lessThan(visible), reason: 'value column line');

      // A vertical line between the label and value columns.
      final midY = rect.center.dy;
      final divider = [
        for (
          var x = rect.left + rect.width * 0.3;
          x < rect.left + rect.width * 0.55;
          x++
        )
          red(x, midY),
      ].reduce((a, b) => a < b ? a : b);
      expect(divider, lessThan(visible), reason: 'column divider');
      checked++;
    }
    expect(checked, 5);
  });
}
