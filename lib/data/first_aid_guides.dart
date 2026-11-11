/// First Aid Health Kit step-by-step guides, organised as Before (get ready),
/// During (the care itself) and After (monitoring and when to get help), each
/// step with a short "why". Keyed by the same `id` as each category in
/// first_aid_kit_screen.dart; the Tagalog version is in
/// lib/i18n/first_aid_guides_tl.dart (same steps, same order).
///
/// Every original step is kept; the Before/After steps, the "why" lines and
/// the materials / what-not-to-do notes are additions. All of this is
/// general first-aid guidance and needs review by a nursing or medical
/// professional before release.
library;

enum GuidePhase { before, during, after }

class GuideStep {
  final GuidePhase phase;
  final String text;
  final String why;

  const GuideStep(this.phase, this.text, this.why);
}

/// Plain-English phase names, used when a guide is saved to the journal.
const Map<GuidePhase, String> guidePhaseNamesEn = {
  GuidePhase.before: 'Before',
  GuidePhase.during: 'During',
  GuidePhase.after: 'After',
};

/// "Before: step — why" — the same single-string shape the AI camera
/// uses for its first-aid steps, so saved journal entries look alike.
String guideStepToJournalText(GuideStep step) =>
    '${guidePhaseNamesEn[step.phase]}: ${step.text} — ${step.why}';

const _handsGloves = GuideStep(
  GuidePhase.before,
  'Wash your hands with soap and water. Wear clean disposable gloves if '
      'you have them.',
  'Keeps germs from your hands out of the wound.',
);

const _checkInfection = GuideStep(
  GuidePhase.after,
  'Check the area each day for spreading redness, warmth, swelling, pus, '
      'or fever. See a healthcare professional if any appear.',
  'Treating an infection early stops it from getting worse.',
);

const Map<String, List<GuideStep>> firstAidGuides = {
  'laceration': [
    _handsGloves,
    GuideStep(
      GuidePhase.before,
      'Get clean running water, clean gauze (or a clean cloth if '
          'you do not have gauze), and a clean non-stick dressing '
          'ready. For a small cut, a small adhesive bandage is fine.',
      'Having supplies ready lets you cover the wound quickly and '
          'keep it clean.',
    ),
    GuideStep(
      GuidePhase.during,
      'Press firmly but gently with clean gauze or cloth to control '
          'bleeding.',
      'Pressure helps the bleeding slow down and stop.',
    ),
    GuideStep(
      GuidePhase.during,
      'If you have it, you may pour a little hydrogen peroxide on '
          'the wound for the first cleaning only, then rinse it off '
          'with clean water. Do not use it again on the same wound.',
      'It helps clean a fresh wound once. Using it again can '
          'irritate the skin and slow healing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the wound well with clean running water once bleeding '
          'slows. Rinse off any hydrogen peroxide too.',
      'Washes out dirt and germs that can cause infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not put alcohol or petroleum jelly directly on a fresh or'
          ' bleeding wound.',
      'Alcohol can irritate and damage healing skin, and petroleum '
          'jelly can trap moisture on a wet wound.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a clean bandage or dressing.',
      'Protects the wound from dirt and germs.',
    ),
    GuideStep(
      GuidePhase.after,
      'Change the dressing daily, or sooner if it gets wet or dirty, and '
          'keep the area clean and dry.',
      'A wet or dirty dressing lets germs grow.',
    ),
    _checkInfection,
  ],
  'minor_cut': [
    _handsGloves,
    GuideStep(
      GuidePhase.before,
      'Get clean running water, a clean cloth or gauze, and a small'
          ' adhesive bandage ready.',
      'Lets you clean and cover the cut right away.',
    ),
    GuideStep(
      GuidePhase.during,
      'If you have it, you may pour a little hydrogen peroxide on '
          'the cut for the first cleaning only, then rinse it off with '
          'clean water. Do not use it again on the same cut.',
      'It helps clean a fresh wound once. Using it again can '
          'irritate the skin and slow healing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the cut under clean running water.',
      'Washes away dirt and germs.',
    ),
    GuideStep(
      GuidePhase.during,
      'Press gently with a clean cloth if it\'s bleeding.',
      'Pressure helps the bleeding stop.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put on an antiseptic if you have one, as directed on the label. '
          'Do not pour alcohol on the cut.',
      'An antiseptic lowers the germs on the skin; alcohol can '
          'damage healing skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a small adhesive bandage.',
      'Keeps dirt out while the cut heals.',
    ),
    GuideStep(
      GuidePhase.after,
      'Keep the area clean and change the bandage daily, or sooner if it '
          'gets wet or dirty.',
      'A clean, dry covering helps the cut heal.',
    ),
    _checkInfection,
  ],
  'scratch': [
    GuideStep(
      GuidePhase.before,
      'Wash your hands with soap and water. Have mild soap, clean '
          'water, and a clean bandage (or a small adhesive bandage) ready.',
      'Keeps germs from your hands out of the scratch.',
    ),
    GuideStep(
      GuidePhase.during,
      'If you have it, you may pour a little hydrogen peroxide on '
          'the scratch for the first cleaning only, then rinse it off '
          'with clean water. Do not use it again on the same scratch.',
      'It helps clean a fresh wound once. Using it again can '
          'irritate the skin and slow healing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Wash the scratch thoroughly with soap and clean water.',
      'Removes dirt and germs from the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put on an antiseptic if you have one, as directed on the label. '
          'Do not pour alcohol on the scratch.',
      'An antiseptic lowers germs; alcohol can irritate the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a clean bandage if the spot gets rubbed a lot.',
      'Stops clothing or movement from rubbing the scratch.',
    ),
    GuideStep(
      GuidePhase.after,
      'Monitor the area daily for the next few days.',
      'Lets you spot problems early.',
    ),
    GuideStep(
      GuidePhase.after,
      'Keep the area clean and avoid scratching it further.',
      'Scratching can break the skin again and let germs in.',
    ),
    _checkInfection,
  ],
  'abrasion': [
    _handsGloves,
    GuideStep(
      GuidePhase.before,
      'Get clean running water and a clean non-stick dressing '
          'ready. If you do not have one, use clean gauze or a clean '
          'cloth with tape.',
      'You will need them right after rinsing.',
    ),
    GuideStep(
      GuidePhase.during,
      'If you have it, you may pour a little hydrogen peroxide on '
          'the scrape for the first cleaning only, then rinse it off '
          'with clean water. Do not use it again on the same scrape.',
      'It helps clean a fresh wound once. Using it again can '
          'irritate the skin and slow healing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the scrape gently under clean running water.',
      'Washes out dirt and germs.',
    ),
    GuideStep(
      GuidePhase.during,
      'Carefully take out any loose dirt you can see.',
      'Dirt left in the wound raises the risk of infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not pour alcohol on the scrape, and do not put '
          'petroleum jelly on it while it is still wet or oozing.',
      'Alcohol can irritate or damage healing skin, and a greasy '
          'layer on a wet wound can trap moisture.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put on antiseptic ointment if you have it, as directed on the label.',
      'Helps lower the germs on the scraped skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a clean, non-stick dressing.',
      'Protects the wound and does not tear it open when removed.',
    ),
    GuideStep(
      GuidePhase.after,
      'Change the dressing daily until healed, or sooner if it gets wet or '
          'dirty.',
      'A wet or dirty dressing lets germs grow.',
    ),
    GuideStep(
      GuidePhase.after,
      'Check the area each day for spreading redness, warmth, swelling, '
          'pus, or fever. See a healthcare professional if any appear, or if '
          'dirt will not rinse out.',
      'Dirt left in the wound and infection need care from a professional.',
    ),
  ],
  'puncture_wound': [
    _handsGloves,
    GuideStep(
      GuidePhase.before,
      'Get soap, clean water, clean gauze (or a clean cloth), and a'
          ' clean bandage ready.',
      'Lets you clean and cover the wound promptly.',
    ),
    GuideStep(
      GuidePhase.during,
      'If you have it, you may pour a little hydrogen peroxide on '
          'the wound for the first cleaning only, then rinse it off '
          'with clean water. Do not use it again on the same wound.',
      'It helps clean a fresh wound once. Using it again can '
          'irritate the skin and slow healing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Gently wash the area with soap and water.',
      'Removes dirt and germs from around the opening.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not push on the wound to make it bleed "to clean it out."',
      'Pressing can hurt the skin and does not clean the wound.',
    ),
    GuideStep(
      GuidePhase.during,
      'Press gently with clean gauze if it\'s bleeding.',
      'Pressure helps the bleeding stop.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a clean bandage.',
      'Keeps dirt out of the wound.',
    ),
    GuideStep(
      GuidePhase.after,
      'Watch closely for signs of infection over the next few days.',
      'Puncture wounds are hard to clean deep inside, so infection can '
          'develop later.',
    ),
    GuideStep(
      GuidePhase.after,
      'See a healthcare professional if the object was dirty or rusty, the '
          'puncture is deep, or you are unsure about your tetanus vaccination.',
      'These wounds can need a tetanus shot or professional cleaning.',
    ),
  ],
  'burn': [
    GuideStep(
      GuidePhase.before,
      'Wash your hands with soap and water.',
      'Keeps germs from your hands away from the burned skin.',
    ),
    GuideStep(
      GuidePhase.before,
      'Remove jewelry or tight items near the burned area, and get '
          'cool running water and a clean, non-stick dressing ready (or'
          ' a clean, lint-free cloth if you do not have one).',
      'The area may swell, which makes rings and tight items hard '
          'to remove later.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cool the burn under cool (not ice-cold) running water for 10-20 '
          'minutes.',
      'Cooling stops the burn from going deeper and eases the pain.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not put ice directly on the burn.',
      'Ice can damage the skin even more.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not put butter, oil, toothpaste, or petroleum jelly on a fresh '
          'burn.',
      'They can trap heat and raise the risk of infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover loosely with a clean, non-stick dressing.',
      'Protects the burn and does not stick to the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not pop any blisters that form.',
      'The blister\'s skin protects against infection.',
    ),
    GuideStep(
      GuidePhase.after,
      'Change the dressing when it gets wet or dirty, and keep the area '
          'clean.',
      'A wet or dirty dressing lets germs grow.',
    ),
    _checkInfection,
  ],
  'bruise': [
    GuideStep(
      GuidePhase.before,
      'Get a clean cloth or towel and a cold pack or ice ready. If '
          'you have no cold pack, use a bag of ice or frozen vegetables'
          ' wrapped in the cloth.',
      'The cold must be wrapped, never placed straight on the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rest the bruised area and avoid further impact.',
      'Protects the area from more injury.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put a cold pack on the area (wrapped in cloth, not directly on skin) for 15-20 '
          'minutes.',
      'Cold reduces swelling and pain, and direct ice can injure the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Raise the area above your heart if you can.',
      'Helps fluid drain away from the area.',
    ),
    GuideStep(
      GuidePhase.after,
      'After 48 hours, a warm, damp cloth can help with healing.',
      'Warmth increases blood flow, which helps clear the bruise.',
    ),
    GuideStep(
      GuidePhase.after,
      'Take note of the bruise\'s size and color over the next few days.',
      'Lets you notice if it is getting worse instead of better.',
    ),
    GuideStep(
      GuidePhase.after,
      'See a healthcare professional if swelling or pain increases, or if '
          'the area loses feeling or is hard to move.',
      'These can be signs of a deeper injury.',
    ),
  ],
  'swelling': [
    GuideStep(
      GuidePhase.before,
      'Get a clean cloth or towel and a cold pack or ice ready. If '
          'you have no cold pack, use a bag of ice or frozen vegetables'
          ' wrapped in the cloth.',
      'The cold must be wrapped, never placed straight on the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rest the swollen area.',
      'Movement can increase swelling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put a cold pack on the area (wrapped in cloth, not directly on skin) for 15-20 '
          'minutes.',
      'Cold helps reduce swelling and pain, and direct ice can injure the '
          'skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Raise the area above your heart if you can.',
      'Helps fluid drain away from the area.',
    ),
    GuideStep(
      GuidePhase.during,
      'Avoid heat or vigorous activity on the area for the first day.',
      'Heat and activity can increase swelling.',
    ),
    GuideStep(
      GuidePhase.after,
      'Monitor how the swelling changes over the next 24-48 hours.',
      'Swelling that keeps growing needs a professional\'s check.',
    ),
    GuideStep(
      GuidePhase.after,
      'Get medical help right away if swelling spreads to the face, lips, '
          'or throat, or you have trouble breathing or swallowing.',
      'This can be a serious allergic reaction.',
    ),
  ],
  'rash': [
    GuideStep(
      GuidePhase.before,
      'Wash your hands with soap and water.',
      'Keeps germs from your hands away from irritated skin.',
    ),
    GuideStep(
      GuidePhase.before,
      'Prepare clean, lukewarm water and a soft, clean towel (or a '
          'clean soft cloth).',
      'Gentle water and a soft towel are kinder to irritated skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Avoid scratching the affected area.',
      'Scratching can break the skin and lead to infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Wash the affected area gently with mild soap and lukewarm '
          'water. Remove any surface dirt.',
      'Removes irritants and dirt without drying out the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'After washing, let the skin air-dry. Do not rub it with a '
          'towel, and keep the area uncovered.',
      'Rubbing can make the rash worse, and an uncovered area can '
          'dry on its own.',
    ),
    GuideStep(
      GuidePhase.during,
      'Put on a mild, fragrance-free moisturizer or soothing lotion '
          'if available.',
      'Soothes dry, itchy skin without adding more irritants.',
    ),
    GuideStep(
      GuidePhase.during,
      'Protect the face from direct sunlight, and cover other '
          'affected skin with loose clothing.',
      'Sun can irritate skin that is already sensitive.',
    ),
    GuideStep(
      GuidePhase.during,
      'Avoid known irritants or allergens if you can identify one.',
      'Further contact can make the rash worse.',
    ),
    GuideStep(
      GuidePhase.after,
      'Keep track of when the rash started and anything new you '
          'were exposed to.',
      'Helps you and a health professional find the cause.',
    ),
    GuideStep(
      GuidePhase.after,
      'Consult a doctor for formal evaluation if the rash does not '
          'get better in a few days or keeps coming back.',
      'A doctor can find the cause and give the right treatment.',
    ),
    GuideStep(
      GuidePhase.after,
      'Get medical help right away if the rash spreads quickly or '
          'comes with trouble breathing or facial swelling.',
      'These can be signs of a severe allergic reaction.',
    ),
  ],
  'other_skin_issue': [
    GuideStep(
      GuidePhase.before,
      'Wash your hands with soap and water. Wear clean disposable gloves '
          'if the skin is broken or bleeding.',
      'Keeps germs from your hands away from the affected skin.',
    ),
    GuideStep(
      GuidePhase.before,
      'Prepare clean, lukewarm water and a soft, clean towel (or a '
          'clean soft cloth).',
      'Gentle water and a soft towel are kinder to irritated skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Keep the affected area clean.',
      'Clean skin is less likely to get infected.',
    ),
    GuideStep(
      GuidePhase.during,
      'Give gentle first aid that fits what you see '
          '(cleaning, a cold pack wrapped in cloth, or rest as needed).',
      'Gentle care avoids making an unknown problem worse.',
    ),
    GuideStep(
      GuidePhase.during,
      'Avoid putting strain on the injured area.',
      'Strain can make pain and damage worse.',
    ),
    GuideStep(
      GuidePhase.after,
      'Monitor the area for changes over the next day.',
      'Changes can show whether it is improving or getting worse.',
    ),
    GuideStep(
      GuidePhase.after,
      'If you are unsure what you are dealing with, treat it gently'
          ' and watch closely. Consult a doctor for formal evaluation '
          'if it gets worse or does not improve.',
      'An unclear problem is safest checked by a professional.',
    ),
  ],
};
