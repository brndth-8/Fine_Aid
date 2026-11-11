import 'package:flutter/widgets.dart';
import 'app_language.dart';
import 'legal_content.dart';

/// One bullet of the camera permission text: a bold label and its sentence.
class PermissionPoint {
  final String label;
  final String text;

  const PermissionPoint(this.label, this.text);
}

/// A heading with a paragraph, bullets, or both.
class PermissionSection {
  final String heading;
  final String? paragraph;
  final List<PermissionPoint> points;

  const PermissionSection(
    this.heading, {
    this.paragraph,
    this.points = const [],
  });
}

/// Camera permission screen text. The body is "Camera Permission Access &
/// Privacy Terms" from "WITH TAGALOG TRANSLATION.pdf", word for word, each
/// English paragraph followed by its Filipino translation (legal_content.dart),
/// whatever the app language is. The buttons and messages follow the language.
class PermissionStrings {
  final String title;
  final List<PermissionSection> sections;
  final String allowCamera;
  final String continueButton;
  final String deniedMessage;
  final String openSettings;
  final String genericError;

  const PermissionStrings({
    required this.title,
    required this.sections,
    required this.allowCamera,
    required this.continueButton,
    required this.deniedMessage,
    required this.openSettings,
    required this.genericError,
  });

  static PermissionStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = PermissionStrings(
    title: 'CAMERA PERMISSION ACCESS & PRIVACY TERMS',
    sections: kPermissionSections,
    allowCamera:
        'I allow the app to access my camera for medical literacy and '
        'assessment purposes.',
    continueButton: 'Continue',
    deniedMessage:
        'Camera access is turned off, so AI scanning will not work. You can '
        'turn it on in the Settings of your phone. Tap Continue to move on '
        'without it and enable it later.',
    openSettings: 'Open Settings',
    genericError: 'Something went wrong. Please try again.',
  );

  static const tl = PermissionStrings(
    title: 'CAMERA PERMISSION ACCESS & PRIVACY TERMS',
    sections: kPermissionSections,
    allowCamera:
        'Pinapayagan ko ang app na gamitin ang aking camera para sa '
        'kaalamang medikal at layunin ng pagsusuri.',
    continueButton: 'Magpatuloy',
    deniedMessage:
        'Naka-off ang access sa camera kaya hindi gagana ang AI scanning. '
        'Maaari mo itong i-on sa Settings ng iyong telepono. I-tap ang '
        'Magpatuloy para magpatuloy nang wala nito at i-on ito mamaya.',
    openSettings: 'Buksan ang Settings',
    genericError: 'May nangyaring mali. Pakisubukang muli.',
  );
}
