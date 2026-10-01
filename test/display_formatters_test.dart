import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/core/display_formatters.dart';
import 'package:fine_aid/services/api/gemini_service.dart' show TriageLevel;

void main() {
  group('triageDisplayLabel', () {
    test('urgentCare -> "Urgent Care"', () {
      expect(triageDisplayLabel(TriageLevel.urgentCare), 'Urgent Care');
    });

    test('selfCare -> "Self Care"', () {
      expect(triageDisplayLabel(TriageLevel.selfCare), 'Self Care');
    });

    test('firstAid -> "First Aid"', () {
      expect(triageDisplayLabel(TriageLevel.firstAid), 'First Aid');
    });

    test('emergency -> "Emergency"', () {
      expect(triageDisplayLabel(TriageLevel.emergency), 'Emergency');
    });

    test('unknown falls back to Title Case of the enum name, no crash', () {
      expect(triageDisplayLabel(TriageLevel.unknown), 'Unknown');
    });

    test('displayName extension matches the function', () {
      expect(
        TriageLevel.urgentCare.displayName,
        triageDisplayLabel(TriageLevel.urgentCare),
      );
    });
  });

  group('woundTypeDisplayLabel', () {
    test('burn -> "Burn"', () {
      expect(woundTypeDisplayLabel('burn'), 'Burn');
    });

    test('puncture_wound -> "Puncture Wound"', () {
      expect(woundTypeDisplayLabel('puncture_wound'), 'Puncture Wound');
    });
  });

  group('titleCaseFromCode', () {
    test('an unknown camelCase value never shows raw code', () {
      expect(titleCaseFromCode('someNewValue'), 'Some New Value');
    });

    test('empty string does not crash', () {
      expect(titleCaseFromCode(''), '');
    });

    test('snake_case is split and title-cased', () {
      expect(titleCaseFromCode('see_a_doctor'), 'See A Doctor');
    });
  });
}
