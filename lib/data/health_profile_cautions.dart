// Turns the user's saved Health Profile into short, relevant cautions
// surfaced alongside first aid steps and OTC suggestions. This is a
// lightweight, additive nudge rather than a true medical-safety filter —
// the app has no per-product condition tagging to reliably hide specific
// OTC options, so instead it flags what's worth double-checking given the
// conditions the user reported.
//
// English by default; pass `tagalog: true` for the Filipino wording. The
// medical wording (both languages) should be reviewed by a professional.
List<String> healthProfileCautions(
  Map<String, dynamic>? healthProfile, {
  bool tagalog = false,
}) {
  if (healthProfile == null) return const [];
  String t(String en, String tl) => tagalog ? tl : en;
  final cautions = <String>[];

  if (healthProfile['diabetes'] == true) {
    cautions.add(
      t(
        "You've noted diabetes - wounds can heal more slowly and infection "
            'risk is higher, so watch this one closely and see a doctor sooner '
            'if healing seems slow or signs of infection appear.',
        'Nabanggit mong may diabetes ka - maaaring mas mabagal gumaling ang '
            'sugat at mas mataas ang panganib ng impeksyon, kaya bantayan ito '
            'nang mabuti at magpatingin agad sa doktor kung mabagal ang '
            'paggaling o may palatandaan ng impeksyon.',
      ),
    );
  }
  if (healthProfile['hemophiliaOrBloodDisorders'] == true) {
    cautions.add(
      t(
        "You've noted a bleeding or blood clotting condition — apply firm, "
            'sustained pressure to any bleeding, and seek medical care promptly '
            "if it doesn't stop quickly.",
        'Nabanggit mong may kondisyon ka sa pagdurugo o pamumuo ng dugo - '
            'diinan nang matagal at matatag ang anumang pagdurugo, at humingi '
            'agad ng tulong medikal kung hindi ito mabilis tumitigil.',
      ),
    );
  }
  if (healthProfile['severeAllergies'] == true) {
    cautions.add(
      t(
        "You've noted severe allergies — check ingredient labels before "
            'using any over-the-counter product, and ask a pharmacist first if '
            "you're unsure.",
        'Nabanggit mong may matinding allergy ka - basahin ang mga sangkap '
            'bago gumamit ng anumang over-the-counter na produkto, at '
            'magtanong muna sa parmasyutiko kung hindi sigurado.',
      ),
    );
  }

  final allergyTypes =
      (healthProfile['allergyTypes'] as List?)?.map((e) => '$e').toSet() ??
      const <String>{};
  if (allergyTypes.contains('latex')) {
    cautions.add(
      t(
        "You've noted a latex allergy - choose latex-free gloves and "
            'dressings.',
        'Nabanggit mong may allergy ka sa latex - pumili ng guwantes at '
            'takip ng sugat na walang latex.',
      ),
    );
  }
  if (allergyTypes.contains('drug')) {
    cautions.add(
      t(
        "You've noted a drug allergy - check the active ingredient of any "
            'medicine or ointment first, and ask a pharmacist if unsure.',
        'Nabanggit mong may allergy ka sa gamot - tingnan muna ang aktibong '
            'sangkap ng anumang gamot o ointment, at magtanong sa '
            'parmasyutiko kung hindi sigurado.',
      ),
    );
  }
  if (allergyTypes.contains('skin')) {
    cautions.add(
      t(
        "You've noted a skin allergy - skin that reacts easily can be "
            'irritated by creams and dressings, so use gentle products and '
            'stop any that make it worse.',
        'Nabanggit mong may allergy ka sa balat - madaling mairita ang '
            'balat sa mga cream at takip ng sugat, kaya gumamit ng '
            'banayad na produkto at itigil ang anumang nagpapalala nito.',
      ),
    );
  }
  if (allergyTypes.contains('insect')) {
    cautions.add(
      t(
        "You've noted an insect allergy - watch closely for swelling or "
            'trouble breathing after any bite or sting, and get medical help '
            'right away if they appear.',
        'Nabanggit mong may allergy ka sa insekto - bantayan nang mabuti '
            'ang pamamaga o hirap sa paghinga pagkatapos ng anumang kagat o '
            'tusok, at humingi agad ng tulong medikal kung lumitaw ang mga '
            'ito.',
      ),
    );
  }

  // The "other condition" the person typed (eg eczema).
  final other = (healthProfile['otherCondition'] as String?)?.trim();
  if (other != null && other.isNotEmpty) {
    final lower = other.toLowerCase();
    if (lower.contains('eczema') || lower.contains('atopic dermatitis')) {
      cautions.add(
        t(
          "You've noted eczema - eczema-prone skin is easily irritated and "
              'can look different from other skin issues, so keep to gentle '
              'care and see a doctor if the skin looks worse than your usual '
              'flare-ups.',
          'Nabanggit mong may eczema ka - madaling mairita ang balat na '
              'may eczema at maaaring iba ang itsura nito sa ibang problema '
              'sa balat, kaya manatili sa banayad na pangangalaga at '
              'magpatingin sa doktor kung mas malala ito kaysa sa karaniwan '
              'mong pagsumpong.',
        ),
      );
    } else {
      cautions.add(
        t(
          "You've noted $other - this may affect how you heal, so mention "
              'it to a doctor and see one sooner if healing is slow.',
          'Nabanggit mong may $other ka - maaari itong makaapekto sa '
              'paggaling mo, kaya sabihin ito sa doktor at magpatingin agad '
              'kung mabagal ang paggaling.',
        ),
      );
    }
  }

  return cautions;
}
