import 'dart:io';
import 'package:fine_aid/data/health_context.dart';
import 'package:fine_aid/services/api/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

OtcSuggestion otc(String name, {OtcSuggestionCategory? c}) => OtcSuggestion(
  name: name,
  ageLimit: '',
  allergyPrecaution: '',
  howToUse: '',
  category: c ?? OtcSuggestionCategory.product,
);

void main() {
  final products = [
    otc('Paracetamol (Biogesic)'),
    otc('Ibuprofen (Advil)'),
    otc('Aspirin'),
    otc('Povidone-iodine (Betadine)'),
    otc('Latex gloves', c: OtcSuggestionCategory.supply),
    otc('Latex-free gloves', c: OtcSuggestionCategory.supply),
    otc('Sterile gauze', c: OtcSuggestionCategory.supply),
  ];
  List<String> names(List<OtcSuggestion> l) => [for (final s in l) s.name];

  group('what the AI is told', () {
    test('conditions, allergies and medicines, in English', () {
      final text = healthContextText(
        {
          'diabetes': true,
          'diabetesType': 'type2',
          'otherCondition': 'Eczema',
          'allergyTypes': ['latex'],
        },
        ['Metformin'],
      )!;
      expect(text, contains('Type 2 Diabetes'));
      expect(text, contains('Eczema'));
      expect(text, contains('Latex'));
      expect(text, contains('Metformin'));
    });

    test('nothing to tell: null', () {
      expect(healthContextText(null, const []), isNull);
      expect(healthContextText(<String, dynamic>{}, const []), isNull);
      expect(healthContextText({'noneOfTheAbove': true}, const []), isNull);
    });

    test('the prompt block asks for different steps and a safe OTC list', () {
      final block = healthContextPromptBlock('Health conditions/allergies: X.');
      expect(block, contains('Health conditions/allergies: X.'));
      expect(block, contains('first_aid_steps'));
      expect(block, contains('otc_options'));
      expect(block, contains('never suggest'));
      expect(block, contains('Do not diagnose'));
    });
  });

  group('OTC products that conflict with a health condition are removed', () {
    test('no condition: nothing is removed', () {
      expect(
        names(
          filterOtcForHealth(products, profile: null, medications: const []),
        ),
        names(products),
      );
      expect(
        names(
          filterOtcForHealth(
            products,
            profile: {'diabetes': true, 'otherCondition': 'Eczema'},
            medications: const ['Metformin'],
          ),
        ),
        names(products),
      );
    });

    test('a bleeding / blood-clotting disorder: no aspirin or NSAIDs', () {
      final kept = names(
        filterOtcForHealth(
          products,
          profile: {'hemophiliaOrBloodDisorders': true},
          medications: const [],
        ),
      );
      expect(kept, isNot(contains('Ibuprofen (Advil)')));
      expect(kept, isNot(contains('Aspirin')));
      expect(kept, contains('Paracetamol (Biogesic)'));
      expect(kept, contains('Povidone-iodine (Betadine)'));
    });

    test('a blood thinner among the medicines does the same', () {
      for (final med in [
        'Warfarin',
        'aspirin 80mg',
        'Clopidogrel',
        'Xarelto',
      ]) {
        final kept = names(
          filterOtcForHealth(products, profile: null, medications: [med]),
        );
        expect(kept, isNot(contains('Aspirin')), reason: med);
        expect(kept, isNot(contains('Ibuprofen (Advil)')), reason: med);
        expect(kept, contains('Paracetamol (Biogesic)'), reason: med);
      }
    });

    test('a latex allergy: nothing made of latex (latex-free is fine)', () {
      final kept = names(
        filterOtcForHealth(
          products,
          profile: {
            'allergyTypes': ['latex'],
          },
          medications: const [],
        ),
      );
      expect(kept, isNot(contains('Latex gloves')));
      expect(kept, contains('Latex-free gloves'));
      expect(kept, contains('Sterile gauze'));
      // the pain relievers are not touched by a latex allergy
      expect(kept, contains('Ibuprofen (Advil)'));
    });
  });

  test('the scan sends the context, filters the OTC list and records it', () {
    final result = File(
      'lib/features/camera/screens/assessment_result_screen.dart',
    ).readAsStringSync();
    expect(result, contains('healthContext: healthContextText('));
    expect(result, contains('filterOtcForHealth('));
    expect(result, contains('Health conditions reported:'));
    final gemini = File(
      'lib/services/api/gemini_service.dart',
    ).readAsStringSync();
    expect(gemini, contains('healthContextPromptBlock(healthContext)'));
  });
}
