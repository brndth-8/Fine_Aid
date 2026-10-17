import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Screen-reader descriptions of the First Aid step images, English +
/// Tagalog, one per step kind (see data/first_aid_step_images.dart). Review
/// the Tagalog before release.
class StepImageStrings {
  final Map<String, String> descriptions;
  final String fallback;

  const StepImageStrings({required this.descriptions, required this.fallback});

  static StepImageStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String describe(String key) => descriptions[key] ?? fallback;

  static const en = StepImageStrings(
    fallback: 'Illustration of this first aid step',
    descriptions: {
      'change_dressing': 'Illustration of changing a wound dressing',
      'wash_hands': 'Illustration of washing hands',
      'cool_burn': 'Illustration of cooling a burn under running water',
      'rinse_water': 'Illustration of rinsing a wound with running water',
      'pat_dry': 'Illustration of patting the skin dry with clean gauze',
      'apply_pressure': 'Illustration of pressing gently on a wound',
      'apply_antiseptic': 'Illustration of applying antiseptic to a wound',
      'cold_compress': 'Illustration of a cold compress wrapped in cloth',
      'apply_dressing': 'Illustration of covering a wound with a dressing',
      'elevate': 'Illustration of raising an injured limb',
      'rest': 'Illustration of resting the injured area',
      'watch_infection': 'Illustration of checking a wound for infection',
      'monitor_the_area': 'Illustration of keeping an eye on the injured area',
      'apply_ointment': 'Illustration of applying ointment to a wound',
      'avoid_touching': 'Illustration of not touching or picking at a wound',
      'avoid_harsh_product':
          'Illustration of not using harsh products on a wound',
      'call_emergency': 'Illustration of calling emergency services',
    },
  );

  static const tl = StepImageStrings(
    fallback: 'Larawan ng hakbang na ito sa first aid',
    descriptions: {
      'change_dressing': 'Larawan ng pagpapalit ng takip ng sugat',
      'wash_hands': 'Larawan ng paghuhugas ng kamay',
      'cool_burn': 'Larawan ng pagpapalamig ng paso sa umaagos na tubig',
      'rinse_water': 'Larawan ng pagbabanlaw ng sugat sa umaagos na tubig',
      'pat_dry':
          'Larawan ng marahang pagtuyo ng balat gamit ang malinis na gasa',
      'apply_pressure': 'Larawan ng marahang pagpisil sa sugat',
      'apply_antiseptic': 'Larawan ng paglalagay ng antiseptic sa sugat',
      'cold_compress': 'Larawan ng malamig na compress na nakabalot sa tela',
      'apply_dressing': 'Larawan ng pagtatakip ng sugat gamit ang dressing',
      'elevate': 'Larawan ng pagtataas ng nasugatang bahagi ng katawan',
      'rest': 'Larawan ng pagpapahinga sa nasugatang bahagi',
      'watch_infection': 'Larawan ng pagsusuri ng sugat para sa impeksyon',
      'monitor_the_area': 'Larawan ng pagbabantay sa nasugatang bahagi',
      'apply_ointment': 'Larawan ng paglalagay ng ointment sa sugat',
      'avoid_touching': 'Larawan ng hindi paghawak o pagkalikot sa sugat',
      'avoid_harsh_product':
          'Larawan ng hindi paggamit ng matatapang na produkto sa sugat',
      'call_emergency': 'Larawan ng pagtawag sa emergency services',
    },
  );
}
