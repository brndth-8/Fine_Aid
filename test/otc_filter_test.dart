import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/services/otc_filter_service.dart';
import 'package:fine_aid/services/api/gemini_service.dart' show OtcSuggestion;

OtcSuggestion _sugg(
  String name, {
  String ageLimit = 'Adults and children 12 years and above',
  String allergyPrecaution = 'Do not use if allergic to this ingredient',
  String howToUse = 'Apply as directed on the package label',
}) => OtcSuggestion(
  name: name,
  ageLimit: ageLimit,
  allergyPrecaution: allergyPrecaution,
  howToUse: howToUse,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OtcFilterService', () {
    test('a wound question never surfaces Betadine Feminine Wash, even '
        'alongside a valid suggestion', () async {
      final result = await OtcFilterService.instance.filter([
        _sugg('Betadine Feminine Wash'),
        _sugg('Povidone-iodine (Betadine Antiseptic Solution)'),
      ]);

      expect(
        result.any((s) => s.name.toLowerCase().contains('feminine')),
        isFalse,
      );
      expect(
        result.map((s) => s.name),
        contains('Povidone-iodine (Betadine Antiseptic Solution)'),
      );
    });

    test(
      'allows povidone-iodine antiseptic solution for a minor cut',
      () async {
        final result = await OtcFilterService.instance.filter([
          _sugg('Povidone-iodine (Betadine Antiseptic Solution)'),
        ]);

        expect(result, hasLength(1));
        expect(
          result.single.name,
          'Povidone-iodine (Betadine Antiseptic Solution)',
        );
      },
    );

    test(
      'keeps the age limit, allergy precaution, and how-to-use details',
      () async {
        final result = await OtcFilterService.instance.filter([
          _sugg(
            'Iodine (Betadine)',
            ageLimit: 'Adults and children 2 years and above',
            allergyPrecaution: 'Do not use if allergic to iodine',
            howToUse: 'Apply a small amount on the wound 1-2 times daily',
          ),
        ]);

        expect(result, hasLength(1));
        final kept = result.single;
        expect(kept.ageLimit, 'Adults and children 2 years and above');
        expect(kept.allergyPrecaution, 'Do not use if allergic to iodine');
        expect(
          kept.howToUse,
          'Apply a small amount on the wound 1-2 times daily',
        );
      },
    );

    test('rejects a denylisted product even when it also contains an '
        'allowlist keyword', () async {
      final result = await OtcFilterService.instance.filter([
        _sugg('Antiseptic mouthwash for oral care'),
      ]);
      expect(result, isEmpty);
    });

    test('rejects a suggestion that matches no allowlist category', () async {
      final result = await OtcFilterService.instance.filter([
        _sugg('A scented candle for relaxation'),
      ]);
      expect(result, isEmpty);
    });

    test('drops entries with a blank or "none" name', () async {
      final result = await OtcFilterService.instance.filter([
        _sugg(''),
        _sugg('   '),
        _sugg('none'),
      ]);
      expect(result, isEmpty);
    });

    test('keeps other allowlisted categories, including gloves', () async {
      final result = await OtcFilterService.instance.filter([
        _sugg('Antibiotic ointment with bacitracin (Bactroban)'),
        _sugg('Cold pack'),
        _sugg('Hydrocortisone cream'),
        _sugg('Disposable gloves'),
      ]);
      expect(result.length, 4);
    });

    test('empty input returns empty output', () async {
      final result = await OtcFilterService.instance.filter(const []);
      expect(result, isEmpty);
    });
  });
}
