import 'package:fine_aid/core/widgets/help_tour_overlay.dart';
import 'package:fine_aid/i18n/tour_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final lang in {
    'English': TourStrings.en,
    'Tagalog': TourStrings.tl,
  }.entries) {
    for (final size in const [Size(360, 640), Size(320, 568), Size(412, 915)]) {
      testWidgets(
        '${lang.key} ${size.width.toInt()}x${size.height.toInt()}: the text '
        'is centered and never overlaps the highlight',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final t = lang.value;
          final keys = List.generate(7, (_) => GlobalKey());
          // Targets at the bottom (nav items), the middle (carousel) and the
          // top corners (profile / settings), like the dashboard.
          final rects = <Rect>[
            Rect.fromLTWH(20, size.height - 70, 90, 56),
            Rect.fromLTWH(140, size.height - 70, 90, 56),
            // The book carousel: upper-middle, ends just under half the screen.
            Rect.fromLTWH(
              24,
              size.height * 0.26,
              size.width - 48,
              size.height * 0.22,
            ),
            Rect.fromLTWH(250, size.height - 70, 90, 56),
            Rect.fromLTWH(size.width - 100, 20, 40, 40),
            Rect.fromLTWH(size.width - 50, 20, 40, 40),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    for (var i = 0; i < rects.length; i++)
                      Positioned.fromRect(
                        rect: rects[i],
                        child: SizedBox(key: keys[i + 1]),
                      ),
                    HelpTourOverlay(
                      steps: [
                        HelpTourStep(
                          title: t.steps[0].title,
                          description: t.steps[0].description,
                        ),
                        for (var i = 1; i < 7; i++)
                          HelpTourStep(
                            targetKey: keys[i],
                            title: t.steps[i].title,
                            description: t.steps[i].description,
                          ),
                      ],
                      skipLabel: t.skipTour,
                      backLabel: t.back,
                      nextLabel: t.next,
                      doneLabel: t.done,
                      onFinished: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // The description does not move: every step has the same band.
          double? fixedTop;
          for (var i = 0; i < 7; i++) {
            final cardFinder = find.byKey(ValueKey(i));
            final card = tester.getRect(cardFinder);
            // The band the text lives in (the card scrolls inside it if a
            // very small screen can't fit it all).
            final band = tester.getRect(
              find
                  .ancestor(
                    of: cardFinder,
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            );
            expect(
              card.center.dx,
              closeTo(size.width / 2, 1),
              reason: 'step $i',
            );
            expect(band.top, greaterThanOrEqualTo(0), reason: 'step $i');
            expect(
              band.bottom,
              lessThanOrEqualTo(size.height),
              reason: 'step $i',
            );
            fixedTop ??= band.top;
            expect(band.top, closeTo(fixedTop, 0.5), reason: 'step $i moved');
            if (i > 0) {
              // The spotlight hole is the target inflated by 10 (+3 ring).
              final hole = rects[i - 1].inflate(13);
              expect(band.overlaps(hole), isFalse, reason: 'step $i overlaps');
            }
            if (i < 6) {
              // Ahem (the test font) draws text far wider than a real font, so
              // the card can scroll here; press Next directly.
              tester
                  .widget<ElevatedButton>(
                    find.widgetWithText(ElevatedButton, t.next),
                  )
                  .onPressed!();
              await tester.pumpAndSettle();
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
