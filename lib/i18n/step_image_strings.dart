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
      'prepare_clean_warm_water_and_a_soft_towel_1':
          'Illustration of a basin of warm water and a soft towel',
      'wash_the_affected_are_and_remove_surface_debris_1':
          'Illustration of washing a wound under running water to remove dirt',
      'protect_the_face_from_direct_sunlight_1':
          'Illustration of shading the face from the sun',
      'consult_a_doctor_for_formal_evaluation_1':
          'Illustration of a doctor examining an injured arm',
      'Apply_mild_fragrance_free_moisturizer_1':
          'Illustration of a jar of fragrance-free moisturizer being applied',
      'consult_a_doctor_if_not_better_1':
          'Illustration of a doctor in a mask next to a calendar and a rash',
      'gather_gauze_or_cloth_1':
          'Illustration of a pack of sterile gauze or a clean cloth',
      'keep_track_of_changes_1':
          'Illustration of a calendar and a magnifying glass over a rash',
      'air_dry_do_not_rub_1':
          'Illustration of skin left to air-dry, with a towel crossed out',
      'check_what_you_see_1':
          'Illustration of a magnifying glass over a rash and its types',
      'keep_area_dry_1':
          'Illustration of keeping the skin dry, with a water drop crossed out',
      'cool_damp_cloth_1':
          'Illustration of a cool, damp cloth held on the skin',
      'sterile_gauze_cover_1':
          'Illustration of sterile gauze placed over the skin',
      'gauze_or_clean_towel_1': 'Illustration of gauze or a clean towel',
      'warning_signs_to_watch_1':
          'Illustration of warning signs: pus, swelling and fever',
      'blisters_seek_care_1':
          'Illustration of blisters and an arrow pointing to a hospital',
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
      'prepare_clean_warm_water_and_a_soft_towel_1':
          'Larawan ng palanggana ng maligamgam na tubig at malambot na tuwalya',
      'wash_the_affected_are_and_remove_surface_debris_1':
          'Larawan ng paghuhugas ng sugat sa umaagos na tubig para alisin ang '
          'dumi',
      'protect_the_face_from_direct_sunlight_1':
          'Larawan ng pagtatakip sa mukha mula sa araw',
      'consult_a_doctor_for_formal_evaluation_1':
          'Larawan ng doktor na sumusuri sa nasugatang braso',
      'Apply_mild_fragrance_free_moisturizer_1':
          'Larawan ng paglalagay ng moisturizer na walang pabango',
      'consult_a_doctor_if_not_better_1':
          'Larawan ng doktor na may mask sa tabi ng kalendaryo at pantal',
      'gather_gauze_or_cloth_1':
          'Larawan ng pakete ng sterile na gasa o malinis na tela',
      'keep_track_of_changes_1':
          'Larawan ng kalendaryo at magnifying glass sa ibabaw ng pantal',
      'air_dry_do_not_rub_1':
          'Larawan ng balat na hinahayaang matuyo sa hangin, may ekis ang tuwalya',
      'check_what_you_see_1':
          'Larawan ng magnifying glass sa ibabaw ng pantal at ng mga uri nito',
      'keep_area_dry_1':
          'Larawan ng pagpapanatiling tuyo ng balat, may ekis ang patak ng tubig',
      'cool_damp_cloth_1':
          'Larawan ng malamig at basang tela na nakadampi sa balat',
      'sterile_gauze_cover_1':
          'Larawan ng sterile na gasa na nakatakip sa balat',
      'gauze_or_clean_towel_1': 'Larawan ng gasa o malinis na tuwalya',
      'warning_signs_to_watch_1':
          'Larawan ng mga babalang palatandaan: nana, pamamaga at lagnat',
      'blisters_seek_care_1':
          'Larawan ng mga paltos at palaso patungo sa ospital',
    },
  );
}
