import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the "nearby healthcare" entry points (chat answer, Need More Help
/// when recovery is not progressing, and the Animal Scratch notice), English
/// + Tagalog. The recommendations are general advice — never a diagnosis —
/// and need review by a nursing/medical professional before release.
class NearbyStrings {
  final String findNearby;
  final String chatNearbyReply;
  final String worseningChatReply;
  final String animalTitle;
  final String animalBody;
  final String understood;

  const NearbyStrings({
    required this.findNearby,
    required this.chatNearbyReply,
    required this.worseningChatReply,
    required this.animalTitle,
    required this.animalBody,
    required this.understood,
  });

  static NearbyStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = NearbyStrings(
    findNearby: 'Find Nearby Healthcare',
    chatNearbyReply:
        'Here are healthcare options near you. Tap the button below to see '
        'hospitals, clinics, and other facilities you can call or visit.',
    worseningChatReply:
        'Since your recovery isn\'t progressing as expected, we recommend '
        'seeing a healthcare professional. Tap the button below to see '
        'nearby hospitals and clinics. You can still ask me anything here.',
    animalTitle: 'Seek medical consultation immediately',
    animalBody:
        'An animal scratch can carry a risk of rabies, tetanus, and '
        'infection, even when the wound looks small. Please seek medical '
        'consultation immediately.',
    understood: 'I understand',
  );

  static const tl = NearbyStrings(
    findNearby: 'Maghanap ng Malapit na Pasilidad',
    chatNearbyReply:
        'Narito ang mga pasilidad pangkalusugan na malapit sa iyo. I-tap ang '
        'button sa ibaba para makita ang mga ospital, klinika, at iba pang '
        'pasilidad na maaari mong tawagan o puntahan.',
    worseningChatReply:
        'Dahil hindi gumagaling ang iyong sugat ayon sa inaasahan, '
        'inirerekomenda naming magpatingin sa isang healthcare professional. '
        'I-tap ang button sa ibaba para makita ang malalapit na ospital at '
        'klinika. Maaari ka pa ring magtanong dito.',
    animalTitle: 'Magpakonsulta agad sa doktor',
    animalBody:
        'Ang kalmot ng hayop ay maaaring may panganib ng rabies, tetanus, at '
        'impeksyon, kahit maliit ang tingin sa sugat. Mangyaring magpakonsulta '
        'agad sa doktor.',
    understood: 'Naiintindihan ko',
  );
}
