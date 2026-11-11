import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// The fixed text of the First Aid Assistance (chat) screen and of the
/// suggestions block under its answers, English + Filipino. The screen follows
/// the app language (Settings > Language); there is no separate toggle.
class ChatStrings {
  final String title;
  final String banner;
  final String greetingWithContext; // uses {context}
  final String greetingGeneral;
  final String inputHint;
  final String send;

  // The suggestions block.
  final String suggestedProducts;
  final String suggestedSupplies;
  final String seeDoctorNote;
  final String detailAge;
  final String detailAllergy;
  final String detailHowToUse;

  const ChatStrings({
    required this.title,
    required this.banner,
    required this.greetingWithContext,
    required this.greetingGeneral,
    required this.inputHint,
    required this.send,
    required this.suggestedProducts,
    required this.suggestedSupplies,
    required this.seeDoctorNote,
    required this.detailAge,
    required this.detailAllergy,
    required this.detailHowToUse,
  });

  static ChatStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String greetingFor(String context) =>
      greetingWithContext.replaceFirst('{context}', context);
  static const en = ChatStrings(
    title: 'First Aid Assistance',
    banner:
        'This assistant provides general first aid guidance only and is not '
        'a substitute for professional medical advice.',
    greetingWithContext:
        "Hi! I see you're asking about a {context} entry. How can I help. "
        'Are you noticing any new symptoms, or do you have a question about '
        'care steps?',
    greetingGeneral:
        "Hi! I'm the Fine Aid Assistant. I can help answer questions about "
        "first aid, wound care, and what to expect during healing. What's on "
        'your mind?',
    inputHint: 'Describe your concern',
    send: 'Send',
    suggestedProducts: 'Suggested OTC products',
    suggestedSupplies: 'Suggested supplies',
    seeDoctorNote:
        "If symptoms don't improve or get worse, consult a doctor or "
        'pharmacist.',
    detailAge: 'Age',
    detailAllergy: 'Allergy precaution',
    detailHowToUse: 'How to use',
  );

  static const tl = ChatStrings(
    title: 'Tulong sa Unang Lunas',
    banner:
        'Ang assistant na ito ay nagbibigay lamang ng pangkalahatang gabay '
        'sa unang lunas at hindi kapalit ng propesyonal na payong medikal.',
    greetingWithContext:
        'Kumusta! Nakikita kong nagtatanong ka tungkol sa isang entry na '
        '{context}. Paano kita matutulungan? May napapansin ka bang bagong '
        'sintomas, o may tanong ka ba tungkol sa mga hakbang ng pangangalaga?',
    greetingGeneral:
        'Kumusta! Ako ang Fine Aid Assistant. Matutulungan kitang sagutin '
        'ang mga tanong tungkol sa unang lunas, pangangalaga ng sugat, at '
        'kung ano ang aasahan habang naghihilom. Ano ang gusto mong itanong?',
    inputHint: 'Ilarawan ang iyong alalahanin',
    send: 'Ipadala',
    suggestedProducts: 'Mga iminumungkahing OTC na produkto',
    suggestedSupplies: 'Mga iminumungkahing gamit',
    seeDoctorNote:
        'Kung hindi bumuti o lumala ang mga sintomas, kumonsulta sa doktor '
        'o parmasyutiko.',
    detailAge: 'Edad',
    detailAllergy: 'Babala sa allergy',
    detailHowToUse: 'Paano gamitin',
  );
}
