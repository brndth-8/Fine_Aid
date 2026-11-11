import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The "Describe your concern..." bar on the scan result: as wide as the Save
/// to Health Journal and Done buttons, maroon outline, send button at the
/// right edge. (The result screen needs a live AI answer to show, so this
/// checks the widget's definition.)
void main() {
  final source = File(
    'lib/features/camera/screens/assessment_result_screen.dart',
  ).readAsStringSync();
  final start = source.indexOf('Widget _buildFollowUpInputBar(');
  final bar = source.substring(start, source.indexOf('/// The yellow', start));

  test('it fills the same width as the buttons (no screen-width hack)', () {
    expect(bar, contains('width: double.infinity'));
    expect(bar, isNot(contains('MediaQuery')));
    expect(bar, isNot(contains('translationValues')));
    expect(bar, isNot(contains('transform:')));
  });

  test('it has a maroon (primary colour) border', () {
    expect(
      bar,
      contains('Border.all(color: theme.colorScheme.primary, width: 1.5)'),
    );
  });

  test('the send button sits at the right edge with little padding', () {
    expect(bar, contains('EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4)'));
    // the text field takes all the room, the send button comes last
    expect(bar.indexOf('Expanded('), lessThan(bar.indexOf('_buildSendButton(theme)')));
  });
}
