import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Camera permission screen text (English + Tagalog). English is the
/// original wording, unchanged. Review the Tagalog before release.
class PermissionStrings {
  final String title;
  final String intro;
  final String whyTitle;
  final String why;
  final String privacyTitle;
  final String privacy;
  final String allowCamera;
  final String skipForNow;
  final String continueButton;
  final String notGranted;
  final String genericError;

  const PermissionStrings({
    required this.title,
    required this.intro,
    required this.whyTitle,
    required this.why,
    required this.privacyTitle,
    required this.privacy,
    required this.allowCamera,
    required this.skipForNow,
    required this.continueButton,
    required this.notGranted,
    required this.genericError,
  });

  static PermissionStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = PermissionStrings(
    title: 'Camera Access Required',
    intro:
        'To provide accurate first aid guidance, this application needs to '
        'use your camera for AI-powered scanning. Your camera will only be '
        'active when you are using the scanning feature.',
    whyTitle: 'Why is this needed?',
    why:
        'The camera allows the AI to analyze visible injuries and skin '
        'condition to provide real-time, data-driven insights to assist in '
        'your decision-making.',
    privacyTitle: 'Privacy & Safety',
    privacy:
        'In accordance with the Data Privacy Act and responsible AI '
        'frameworks, images are used only for assessment and are not shared '
        'without your explicit consent.',
    allowCamera:
        'I allow the app to access my camera for medical literacy and '
        'assessment purposes.',
    skipForNow: 'Skip for now',
    continueButton: 'Continue',
    notGranted:
        'Camera permission was not granted. You can enable it later in '
        'Settings.',
    genericError: 'Something went wrong. Please try again.',
  );

  static const tl = PermissionStrings(
    title: 'Kailangan ang Access sa Camera',
    intro:
        'Para makapagbigay ng tumpak na gabay sa first aid, kailangan ng '
        'application na ito na gamitin ang iyong camera para sa AI-powered '
        'na pag-scan. Gagana lamang ang iyong camera kapag ginagamit mo ang '
        'tampok na pag-scan.',
    whyTitle: 'Bakit ito kailangan?',
    why:
        'Dahil sa camera, nasusuri ng AI ang mga nakikitang sugat at ang '
        'kondisyon ng balat para makapagbigay ng real-time at '
        'batay-sa-datos na impormasyon na makatutulong sa iyong '
        'pagdedesisyon.',
    privacyTitle: 'Privacy at Kaligtasan',
    privacy:
        'Alinsunod sa Data Privacy Act at sa mga responsableng balangkas ng '
        'AI, ginagamit lamang ang mga larawan para sa pagsusuri at hindi '
        'ibinabahagi nang walang malinaw mong pahintulot.',
    allowCamera:
        'Pinapayagan ko ang app na gamitin ang aking camera para sa '
        'kaalamang medikal at layunin ng pagsusuri.',
    skipForNow: 'Laktawan muna',
    continueButton: 'Magpatuloy',
    notGranted:
        'Hindi ibinigay ang pahintulot sa camera. Maaari mo itong i-on '
        'mamaya sa Settings.',
    genericError: 'May nangyaring mali. Pakisubukang muli.',
  );
}
