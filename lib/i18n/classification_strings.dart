/// Plain-language explanations of each wound / skin classification, so a user
/// can tell the types apart and tell a minor problem from a serious one (eg
/// how to know a cut is "deep"). English + Tagalog.
///
/// IMPORTANT: this is general first-aid guidance drafted from the app's own
/// existing first-aid content and standard first-aid teaching. It MUST be
/// reviewed by a nursing/medical professional before release.
library;

class ClassificationInfo {
  /// What this type of injury is.
  final String what;

  /// Signs that it is probably minor (empty = section hidden).
  final String minorSigns;

  /// Signs that it may be serious and needs a professional.
  final String seriousSigns;

  const ClassificationInfo({
    required this.what,
    this.minorSigns = '',
    this.seriousSigns = '',
  });
}

/// Headings and footer for the explanation sheet.
class ClassificationInfoLabels {
  final String whatIsIt;
  final String usuallyMinor;
  final String seeProfessional;
  final String disclaimer;
  final String tooltip;

  const ClassificationInfoLabels({
    required this.whatIsIt,
    required this.usuallyMinor,
    required this.seeProfessional,
    required this.disclaimer,
    required this.tooltip,
  });

  static const en = ClassificationInfoLabels(
    whatIsIt: 'What it is',
    usuallyMinor: 'Usually minor if',
    seeProfessional: 'See a healthcare professional if',
    disclaimer: 'General guidance only — not a diagnosis.',
    tooltip: 'What does this mean?',
  );

  static const tl = ClassificationInfoLabels(
    whatIsIt: 'Ano ito',
    usuallyMinor: 'Karaniwang maliit lang kung',
    seeProfessional: 'Magpatingin sa propesyonal sa kalusugan kung',
    disclaimer: 'Pangkalahatang gabay lamang ito — hindi isang diagnosis.',
    tooltip: 'Ano ang ibig sabihin nito?',
  );
}

const _laceration = (
  ClassificationInfo(
    what: 'A cut or tear in the skin, often with jagged or uneven edges.',
    minorSigns:
        'It is shallow, the edges lie close together, and bleeding stops '
        'within about 10 minutes of firm pressure.',
    seriousSigns:
        'You can see fat (yellow), muscle, or bone; the edges gape open; '
        'bleeding does not stop after 10 minutes of firm pressure; it was '
        'caused by a dirty or rusty object; or it is on the face, a hand, '
        'or over a joint.',
  ),
  ClassificationInfo(
    what:
        'Hiwa o punit sa balat na madalas ay may lamat-lamat o hindi pantay '
        'na gilid.',
    minorSigns:
        'Mababaw ito, magkadikit ang mga gilid, at humihinto ang pagdurugo '
        'sa loob ng mga 10 minuto ng madiing pagdiin.',
    seriousSigns:
        'Nakikita mo ang taba (dilaw), kalamnan, o buto; nakabuka ang mga '
        'gilid; hindi humihinto ang pagdurugo pagkatapos ng 10 minuto ng '
        'madiing pagdiin; sanhi ito ng marumi o kalawangin na bagay; o nasa '
        'mukha, kamay, o sa ibabaw ng kasukasuan.',
  ),
);

const _minorCut = (
  ClassificationInfo(
    what: 'A small, shallow cut in the skin.',
    minorSigns:
        'It is small and shallow, bleeds only a little, and stops quickly '
        'with gentle pressure.',
    seriousSigns:
        'Something is stuck in the wound; it is deep or gaping; bleeding '
        'does not stop after 10 minutes of firm pressure; or signs of '
        'infection appear (more redness, swelling, warmth, or pus).',
  ),
  ClassificationInfo(
    what: 'Maliit at mababaw na hiwa sa balat.',
    minorSigns:
        'Maliit at mababaw ito, kaunti lang ang dugo, at mabilis humihinto '
        'sa marahang pagdiin.',
    seriousSigns:
        'May nakabaon sa sugat; malalim o nakabuka ito; hindi humihinto ang '
        'pagdurugo pagkatapos ng 10 minuto ng madiing pagdiin; o may '
        'lumilitaw na palatandaan ng impeksyon (mas matinding pamumula, '
        'pamamaga, init, o nana).',
  ),
);

const _scratch = (
  ClassificationInfo(
    what:
        'A light mark on the skin surface, such as from fingernails or a '
        'thorn, where the skin is only slightly broken.',
    minorSigns:
        'Only the top layer of skin is affected and there is little or no '
        'bleeding.',
    seriousSigns:
        'It came from an animal (there may be a risk of infection or '
        'rabies), it is swelling, or it shows signs of infection.',
  ),
  ClassificationInfo(
    what:
        'Magaan na gasgas sa ibabaw ng balat, tulad ng mula sa kuko o tinik, '
        'kung saan bahagya lang ang punit ng balat.',
    minorSigns:
        'Ang pinakaibabaw na patong lang ng balat ang apektado at kaunti o '
        'walang dugo.',
    seriousSigns:
        'Galing ito sa hayop (maaaring may panganib ng impeksyon o rabies), '
        'namamaga ito, o may palatandaan ng impeksyon.',
  ),
);

const _abrasion = (
  ClassificationInfo(
    what:
        'A scrape where the top layer of skin has been rubbed off, such as '
        'after a fall. It can look raw and ooze a little.',
    minorSigns:
        'It is smaller than your palm, oozes only lightly, and dirt rinses '
        'out with clean water.',
    seriousSigns:
        'It is larger than your palm, it is deep, dirt or debris will not '
        'rinse out, or signs of infection appear.',
  ),
  ClassificationInfo(
    what:
        'Galos kung saan nakuskos ang pinakaibabaw na patong ng balat, tulad '
        'ng pagkatapos ng pagkahulog. Maaari itong magmukhang hilaw at '
        'bahagyang magtubig.',
    minorSigns:
        'Mas maliit ito kaysa sa iyong palad, bahagya lang ang pagtutubig, '
        'at natatanggal ang dumi sa pagbanlaw ng malinis na tubig.',
    seriousSigns:
        'Mas malaki ito kaysa sa iyong palad, malalim ito, hindi natatanggal '
        'ang dumi o mga labi sa pagbanlaw, o may lumilitaw na palatandaan ng '
        'impeksyon.',
  ),
);

const _puncture = (
  ClassificationInfo(
    what:
        'A small, deep hole made by a pointed object such as a nail or '
        'needle. It may look minor on the surface but can go deep.',
    minorSigns:
        'A very shallow prick from a clean object with little bleeding is '
        'the least concerning.',
    seriousSigns:
        'The object was dirty or rusty, the puncture is deep, something is '
        'left inside, or you are not sure about your tetanus vaccination.',
  ),
  ClassificationInfo(
    what:
        'Maliit at malalim na butas na gawa ng matulis na bagay tulad ng '
        'pako o karayom. Maaaring mukhang maliit sa ibabaw ngunit maaaring '
        'malalim.',
    minorSigns:
        'Ang napakababaw na tusok mula sa malinis na bagay na kaunti lang '
        'ang dugo ang pinakamaliit na dahilan ng pag-aalala.',
    seriousSigns:
        'Marumi o kalawangin ang bagay, malalim ang butas, may naiwan sa '
        'loob, o hindi ka sigurado sa iyong bakuna laban sa tetano.',
  ),
);

const _burn = (
  ClassificationInfo(
    what:
        'Damage to the skin from heat, hot liquids, fire, chemicals, or '
        'electricity.',
    minorSigns:
        'The skin is red and painful, like a mild sunburn, smaller than your '
        'palm, with no blisters or only a few small ones.',
    seriousSigns:
        'It is larger than your palm; on the face, hands, feet, or a joint; '
        'has large or broken blisters; or the skin looks white, charred, or '
        'leathery.',
  ),
  ClassificationInfo(
    what:
        'Pinsala sa balat mula sa init, mainit na likido, apoy, kemikal, o '
        'kuryente.',
    minorSigns:
        'Namumula at masakit ang balat, parang bahagyang sunburn, mas maliit '
        'kaysa sa iyong palad, at walang paltos o iilang maliit lang.',
    seriousSigns:
        'Mas malaki ito kaysa sa iyong palad; nasa mukha, kamay, paa, o '
        'kasukasuan; may malaki o pumutok na paltos; o puti, nasunog, o '
        'parang balat na makapal ang itsura ng balat.',
  ),
);

const _bruise = (
  ClassificationInfo(
    what:
        'A red, blue, or purple mark under unbroken skin, caused by bleeding '
        'under the skin after a knock or fall.',
    minorSigns:
        'It is tender with mild swelling, and you can still move the area '
        'normally.',
    seriousSigns:
        'It came from a hard impact (a fall, vehicle accident, or heavy '
        'object); the area is very swollen, misshapen, or hard to move (it '
        'could be a fracture); or it keeps getting larger.',
  ),
  ClassificationInfo(
    what:
        'Pula, asul, o lilang marka sa ilalim ng hindi nasirang balat, '
        'sanhi ng pagdurugo sa ilalim ng balat pagkatapos ng pagkabundol o '
        'pagkahulog.',
    minorSigns:
        'Masakit kapag hinawakan at bahagyang namamaga, at nagagalaw mo pa '
        'nang normal ang bahaging iyon.',
    seriousSigns:
        'Galing ito sa malakas na pagkabundol (pagkahulog, aksidente sa '
        'sasakyan, o mabigat na bagay); sobrang namamaga, hindi pantay ang '
        'hugis, o mahirap igalaw ang bahagi (maaaring bali); o patuloy na '
        'lumalaki.',
  ),
);

const _swelling = (
  ClassificationInfo(
    what:
        'An area of the body that looks puffed up because of fluid or '
        'inflammation.',
    minorSigns:
        'It is mild, appeared after a knock or sprain, and slowly improves '
        'with rest and raising the area.',
    seriousSigns:
        'It started suddenly without an injury, keeps increasing, spreads to '
        'the face, lips, or throat, or comes with trouble breathing or '
        'swallowing.',
  ),
  ClassificationInfo(
    what: 'Bahagi ng katawan na mukhang namumutok dahil sa likido o pamamaga.',
    minorSigns:
        'Bahagya lang ito, lumitaw pagkatapos ng pagkabundol o pagkapilay, '
        'at unti-unting gumagaling sa pahinga at pag-angat ng bahagi.',
    seriousSigns:
        'Biglaan itong nagsimula nang walang pinsala, patuloy na lumalaki, '
        'kumakalat sa mukha, labi, o lalamunan, o may kasamang hirap sa '
        'paghinga o paglunok.',
  ),
);

const _rash = (
  ClassificationInfo(
    what:
        'A change in the color or texture of the skin, often red, itchy, or '
        'bumpy.',
    minorSigns:
        'It is mild redness or itch that stays in one area and does not '
        'spread quickly.',
    seriousSigns:
        'It appeared suddenly after a new food, medicine, or insect bite; '
        'spreads quickly; or comes with trouble breathing or swelling of '
        'the face.',
  ),
  ClassificationInfo(
    what:
        'Pagbabago sa kulay o tekstura ng balat, madalas ay pula, makati, o '
        'bukol-bukol.',
    minorSigns:
        'Bahagyang pamumula o pangangati na nasa isang lugar lang at hindi '
        'mabilis kumakalat.',
    seriousSigns:
        'Biglaan itong lumitaw pagkatapos ng bagong pagkain, gamot, o kagat '
        'ng insekto; mabilis kumakalat; o may kasamang hirap sa paghinga o '
        'pamamaga ng mukha.',
  ),
);

const _otherSkin = (
  ClassificationInfo(
    what: 'A skin problem that does not fit the other groups.',
    minorSigns: 'It is small, painless, and not getting worse.',
    seriousSigns:
        'You are unsure what it is, or it is painful, bleeding, or changing '
        'quickly. When in doubt, have it checked.',
  ),
  ClassificationInfo(
    what: 'Problema sa balat na hindi kasama sa iba pang grupo.',
    minorSigns: 'Maliit ito, walang sakit, at hindi lumalala.',
    seriousSigns:
        'Hindi ka sigurado kung ano ito, o masakit ito, dumudugo, o mabilis '
        'na nagbabago. Kapag nagdududa, ipasuri ito.',
  ),
);

const _unable = (
  ClassificationInfo(
    what: 'The AI could not tell what type of injury this is from the photo.',
    seriousSigns:
        'You are worried, or the area is getting worse. Try again with a '
        'clearer, well-lit photo, or see a healthcare professional.',
  ),
  ClassificationInfo(
    what: 'Hindi matukoy ng AI kung anong uri ng pinsala ito mula sa larawan.',
    seriousSigns:
        'Nag-aalala ka, o lumalala ang bahagi. Subukang muli gamit ang '
        'mas malinaw at maliwanag na larawan, o magpatingin sa propesyonal '
        'sa kalusugan.',
  ),
);

const _injuryGroup = (
  ClassificationInfo(
    what: 'A general group for wounds such as cuts, lacerations, and scrapes.',
    // Minor / Deep descriptions — also shown as the Deep / Minor options when
    // adding a Health Journal entry. Draft: needs medical review.
    minorSigns:
        'A shallow wound: only the top layer of skin is affected, there is '
        'little bleeding that stops with gentle pressure, and the edges lie '
        'close together.',
    seriousSigns:
        'The wound goes beyond the skin and may show fat, muscle, or bone; '
        'the edges gape open; bleeding does not stop after 10 minutes of '
        'pressure; or it was caused by a dirty or puncturing object.',
  ),
  ClassificationInfo(
    what:
        'Pangkalahatang grupo para sa mga sugat tulad ng hiwa, punit, at '
        'galos.',
    minorSigns:
        'Mababaw na sugat: ang pinakaibabaw na patong lang ng balat ang '
        'apektado, kaunti ang dugo at humihinto sa marahang pagdiin, at '
        'magkadikit ang mga gilid.',
    seriousSigns:
        'Lampas sa balat ang sugat at maaaring makita ang taba, kalamnan, o '
        'buto; nakabuka ang mga gilid; hindi humihinto ang pagdurugo '
        'pagkatapos ng 10 minuto ng pagdiin; o sanhi ito ng marumi o '
        'tumusok na bagay.',
  ),
);

const _animal = (
  ClassificationInfo(
    what: 'A bite or scratch from an animal.',
    seriousSigns:
        'Any animal bite or scratch: clean it with soap and water and see a '
        'healthcare professional soon, because of the risk of infection and '
        'rabies.',
  ),
  ClassificationInfo(
    what: 'Kagat o kalmot mula sa hayop.',
    seriousSigns:
        'Anumang kagat o kalmot ng hayop: hugasan ito ng sabon at tubig at '
        'magpatingin agad sa propesyonal sa kalusugan, dahil sa panganib ng '
        'impeksyon at rabies.',
  ),
);

/// Lower-cased classification name -> (English, Tagalog). Covers the AI
/// categories, the First Aid Assistant categories, and the Health Journal's
/// manual-entry classifications.
final Map<String, (ClassificationInfo, ClassificationInfo)> _byName = {
  'laceration': _laceration,
  'minor cut': _minorCut,
  'scratch': _scratch,
  'abrasion': _abrasion,
  'puncture wound': _puncture,
  'burn': _burn,
  'burns': _burn,
  'bruise': _bruise,
  'swelling': _swelling,
  'rash': _rash,
  'other skin issue': _otherSkin,
  'skin issues': _otherSkin,
  'unable to classify': _unable,
  'injury (wounds/laceration/abrasion)': _injuryGroup,
  'animal bite/scratch': _animal,
  'animal scratch': _animal,
};

/// The explanation for [classification] in the requested language, or null
/// if there isn't one (the info button is then simply not shown).
ClassificationInfo? classificationInfoFor(
  String? classification, {
  required bool tagalog,
}) {
  final key = classification?.trim().toLowerCase();
  if (key == null || key.isEmpty) return null;
  final pair = _byName[key];
  if (pair == null) return null;
  return tagalog ? pair.$2 : pair.$1;
}

/// Every classification name that has an explanation (used by tests to make
/// sure none is missing).
Iterable<String> get classificationNamesWithInfo => _byName.keys;
