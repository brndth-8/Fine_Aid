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
      'Get clean running water, clean gauze or cloth, and a sterile '
          'non-stick dressing ready.',
      'Having supplies ready lets you cover the wound quickly and keep it '
          'clean.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply gentle, firm pressure with clean gauze or cloth to control '
          'bleeding.',
      'Pressure helps the blood clot and slows the bleeding.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the wound with clean running water once bleeding slows.',
      'Washes out dirt and germs that can cause infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not put alcohol, hydrogen peroxide, or petroleum jelly directly '
          'on a fresh or bleeding wound.',
      'Alcohol and hydrogen peroxide can irritate and damage healing '
          'tissue, and petroleum jelly can trap moisture on a wet wound.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a sterile bandage or dressing.',
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
      'Get clean running water, a clean cloth, and a small adhesive '
          'bandage ready.',
      'Lets you clean and cover the cut right away.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the cut under clean running water.',
      'Washes away dirt and germs.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply gentle pressure with a clean cloth if it\'s bleeding.',
      'Pressure helps the bleeding stop.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply an antiseptic if available, as directed on the label. Do not '
          'pour alcohol or hydrogen peroxide on the cut.',
      'An antiseptic lowers the germs on the skin; alcohol and hydrogen '
          'peroxide can damage healing tissue.',
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
      'Wash your hands with soap and water. Have mild soap, clean water, '
          'and a clean bandage ready.',
      'Keeps germs from your hands out of the scratch.',
    ),
    GuideStep(
      GuidePhase.during,
      'Wash the scratch thoroughly with soap and clean water.',
      'Removes dirt and germs from the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply an antiseptic if available, as directed on the label. Do not '
          'pour alcohol or hydrogen peroxide on the scratch.',
      'An antiseptic lowers germs; alcohol and hydrogen peroxide can '
          'irritate the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a clean bandage if it\'s in an area prone to friction.',
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
      'Get clean running water and a sterile non-stick dressing ready.',
      'You will need them right after rinsing.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rinse the scrape gently under clean running water.',
      'Washes out dirt and germs.',
    ),
    GuideStep(
      GuidePhase.during,
      'Remove any loose, visible debris carefully.',
      'Dirt left in the wound raises the risk of infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not pour alcohol or hydrogen peroxide on the scrape, and do not '
          'apply petroleum jelly while it is still moist or weeping.',
      'They can irritate or damage healing tissue, and a greasy layer on '
          'a wet wound can trap moisture.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply antiseptic ointment if available, as directed on the label.',
      'Helps lower the germs on the scraped skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cover with a sterile, non-stick dressing.',
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
          'debris will not rinse out.',
      'Debris and infection need professional care.',
    ),
  ],
  'puncture_wound': [
    _handsGloves,
    GuideStep(
      GuidePhase.before,
      'Get soap, clean water, clean gauze, and a clean bandage ready.',
      'Lets you clean and cover the wound promptly.',
    ),
    GuideStep(
      GuidePhase.during,
      'Gently wash the area with soap and water.',
      'Removes dirt and germs from around the opening.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not push on the wound to make it bleed "to clean it out."',
      'Pressing can damage the tissue and does not clean the wound.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply gentle pressure with clean gauze if it\'s bleeding.',
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
      'Remove jewelry or tight items near the burned area, and get cool '
          'running water and a clean, non-stick dressing ready.',
      'The area may swell, which makes rings and tight items hard to '
          'remove later.',
    ),
    GuideStep(
      GuidePhase.during,
      'Cool the burn under cool (not ice-cold) running water for 10-20 '
          'minutes.',
      'Cooling stops the burn from going deeper and eases the pain.',
    ),
    GuideStep(
      GuidePhase.during,
      'Do not apply ice directly to the burn.',
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
      'Get a clean cloth or towel and a cold pack or ice ready.',
      'The cold must be wrapped, never placed straight on the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rest the bruised area and avoid further impact.',
      'Protects the area from more injury.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply a cold compress (wrapped, not directly on skin) for 15-20 '
          'minutes.',
      'Cold reduces swelling and pain, and direct ice can injure the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Elevate the area above heart level if possible.',
      'Helps fluid drain away from the area.',
    ),
    GuideStep(
      GuidePhase.after,
      'After 48 hours, a warm compress can help with healing.',
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
          'the area becomes numb or hard to move.',
      'These can be signs of a deeper injury.',
    ),
  ],
  'swelling': [
    GuideStep(
      GuidePhase.before,
      'Get a clean cloth or towel and a cold pack or ice ready.',
      'The cold must be wrapped, never placed straight on the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Rest the swollen area.',
      'Movement can increase swelling.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply a cold compress (wrapped, not directly on skin) for 15-20 '
          'minutes.',
      'Cold helps reduce swelling and pain, and direct ice can injure the '
          'skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Elevate the area above heart level if possible.',
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
      GuidePhase.during,
      'Avoid scratching the affected area.',
      'Scratching can break the skin and lead to infection.',
    ),
    GuideStep(
      GuidePhase.during,
      'Wash the area gently with mild soap and cool water.',
      'Removes irritants without drying out the skin.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply a fragrance-free moisturizer or soothing lotion if available.',
      'Soothes dry, itchy skin without adding more irritants.',
    ),
    GuideStep(
      GuidePhase.during,
      'Avoid known irritants or allergens if you can identify one.',
      'Further contact can make the rash worse.',
    ),
    GuideStep(
      GuidePhase.after,
      'Keep track of when the rash started and anything new you were '
          'exposed to.',
      'Helps you and a health professional find the cause.',
    ),
    GuideStep(
      GuidePhase.after,
      'Get medical help right away if the rash spreads quickly or comes '
          'with trouble breathing or facial swelling.',
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
      GuidePhase.during,
      'Keep the affected area clean.',
      'Clean skin is less likely to get infected.',
    ),
    GuideStep(
      GuidePhase.during,
      'Apply gentle first aid appropriate to what you\'re seeing '
          '(cleaning, cold compress wrapped in cloth, or rest as needed).',
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
      'If unsure what you\'re dealing with, treat cautiously and watch '
          'closely, and see a healthcare professional if it worsens.',
      'An unclear problem is safest checked by a professional.',
    ),
  ],
};
