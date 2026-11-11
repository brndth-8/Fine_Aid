import 'package:fine_aid/features/admin/screens/sections/admin_feedback.dart';
import 'package:fine_aid/features/admin/screens/sections/admin_system_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('suggested feedback reply', () {
    test('is the thank-you text', () {
      expect(
        kFeedbackReplyTemplate,
        'Thank you very much for taking the time to share your feedback! We '
        'truly appreciate it and are glad to hear from you.',
      );
    });

    test('can be sent as it is: not blank and within the limit', () {
      expect(adminFeedbackResponseProblem(kFeedbackReplyTemplate), isNull);
      expect(kFeedbackReplyTemplate.length, lessThan(adminFeedbackResponseMax));
    });
  });

  group('idle session timeout length', () {
    test('can be changed only while the switch is off', () {
      expect(
        idleDurationEditable(loaded: true, saving: false, idleEnabled: false),
        isTrue,
      );
      expect(
        idleDurationEditable(loaded: true, saving: false, idleEnabled: true),
        isFalse,
        reason: 'locked while the timeout is on',
      );
    });

    test('is locked while loading or saving, whatever the switch says', () {
      expect(
        idleDurationEditable(loaded: false, saving: false, idleEnabled: false),
        isFalse,
      );
      expect(
        idleDurationEditable(loaded: true, saving: true, idleEnabled: false),
        isFalse,
      );
    });
  });
}
