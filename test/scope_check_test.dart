import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/core/scope_check.dart';

void main() {
  group('looksObviouslyOutOfScope', () {
    test('"I have a cough" is refused', () {
      expect(looksObviouslyOutOfScope('I have a cough'), isTrue);
    });

    test('"I have diabetes, what should I eat?" is refused', () {
      expect(
        looksObviouslyOutOfScope('I have diabetes, what should I eat?'),
        isTrue,
      );
    });

    test('"I have a cut on my finger" is in scope', () {
      expect(looksObviouslyOutOfScope('I have a cut on my finger'), isFalse);
    });

    test(
      'borderline case: "My cut is red and I have a fever" stays in scope',
      () {
        expect(
          looksObviouslyOutOfScope('My cut is red and I have a fever'),
          isFalse,
        );
      },
    );

    test('follow-up "Also, I have a wet cough" is refused on its own', () {
      expect(looksObviouslyOutOfScope('Also, I have a wet cough'), isTrue);
    });

    test('a plain wound question about a rash is in scope', () {
      expect(looksObviouslyOutOfScope('Is this rash dangerous?'), isFalse);
    });

    test('an unrelated chronic-illness question is refused', () {
      expect(
        looksObviouslyOutOfScope('What should I do about my hypertension?'),
        isTrue,
      );
    });

    test('small talk with no keyword match falls through to the AI', () {
      expect(looksObviouslyOutOfScope('Hello, how are you?'), isFalse);
    });
  });

  group('isRefusalReply', () {
    test('matches the exact refusal message', () {
      expect(isRefusalReply(outOfScopeRefusalMessage), isTrue);
    });

    test('matches with surrounding whitespace', () {
      expect(isRefusalReply('  $outOfScopeRefusalMessage  '), isTrue);
    });

    test('does not match an ordinary answer', () {
      expect(isRefusalReply('Clean the wound with running water.'), isFalse);
    });
  });
}
