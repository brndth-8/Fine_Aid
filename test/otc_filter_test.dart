import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/services/otc_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OtcFilterService', () {
    test(
      'a wound question never surfaces Betadine Feminine Wash, even '
      'alongside a valid suggestion',
      () async {
        final result = await OtcFilterService.instance.filter([
          'Betadine Feminine Wash',
          'povidone-iodine antiseptic solution for minor cuts',
        ]);

        expect(
          result.any((s) => s.toLowerCase().contains('feminine')),
          isFalse,
        );
        expect(
          result,
          contains('povidone-iodine antiseptic solution for minor cuts'),
        );
      },
    );

    test('allows povidone-iodine antiseptic solution for a minor cut', () async {
      final result = await OtcFilterService.instance.filter([
        'povidone-iodine antiseptic solution for minor cuts',
      ]);

      expect(
        result,
        equals(['povidone-iodine antiseptic solution for minor cuts']),
      );
    });

    test(
      'rejects a denylisted product even when it also contains an '
      'allowlist keyword',
      () async {
        final result = await OtcFilterService.instance.filter([
          'antiseptic mouthwash for oral care',
        ]);
        expect(result, isEmpty);
      },
    );

    test('rejects a suggestion that matches no allowlist category', () async {
      final result = await OtcFilterService.instance.filter([
        'a scented candle for relaxation',
      ]);
      expect(result, isEmpty);
    });

    test('drops blank entries and "none"', () async {
      final result = await OtcFilterService.instance.filter([
        '',
        '   ',
        'none',
      ]);
      expect(result, isEmpty);
    });

    test('keeps other allowlisted categories', () async {
      final result = await OtcFilterService.instance.filter([
        'an antibiotic ointment with bacitracin for minor scrapes',
        'a cold pack for the swelling',
        'hydrocortisone cream for the itching',
      ]);
      expect(result.length, 3);
    });

    test('empty input returns empty output', () async {
      final result = await OtcFilterService.instance.filter(const []);
      expect(result, isEmpty);
    });
  });
}
