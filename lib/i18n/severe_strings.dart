import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for a severe result (an emergency, so no first aid steps are shown),
/// English + Tagalog. General safety advice, not a diagnosis; review the
/// wording with a nursing/medical professional and the Tagalog with a native
/// speaker before release.
class SevereStrings {
  final String title;
  final String body;
  final String nearbyHospitals;
  final String close;
  final String noStepsTitle;
  final String noStepsBody;
  // The emergency pop-up for a severe scan result.
  final String emergencyTitle;
  final String callEmergency;
  final String medicalNeeded;
  final String nearbyHospitalsButton;
  final String closeTooltip;

  const SevereStrings({
    required this.title,
    required this.body,
    required this.nearbyHospitals,
    required this.close,
    required this.noStepsTitle,
    required this.noStepsBody,
    required this.emergencyTitle,
    required this.callEmergency,
    required this.medicalNeeded,
    required this.nearbyHospitalsButton,
    required this.closeTooltip,
  });

  static SevereStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = SevereStrings(
    title: 'Seek medical consultation immediately',
    body:
        'This injury looks serious. Please get medical help right away: '
        'go to the nearest hospital or call emergency services. First aid '
        'steps are not shown because this needs a medical professional.',
    nearbyHospitals: 'Nearby hospitals',
    close: 'Close',
    noStepsTitle: 'Medical help is needed',
    noStepsBody:
        'First aid steps are not shown for this injury. Please seek medical '
        'consultation immediately.',
    emergencyTitle: 'Seek Emergency Care Immediately',
    callEmergency: 'Call Emergency Services (911)',
    medicalNeeded: 'Medical Health is needed',
    nearbyHospitalsButton: 'Nearby Hospitals',
    closeTooltip: 'Close',
  );

  static const tl = SevereStrings(
    title: 'Magpakonsulta agad sa doktor',
    body:
        'Mukhang malubha ang pinsalang ito. Humingi agad ng tulong medikal: '
        'pumunta sa pinakamalapit na ospital o tumawag sa emergency '
        'services. Hindi ipinapakita ang mga hakbang sa first aid dahil '
        'kailangan nito ng medical professional.',
    nearbyHospitals: 'Malalapit na ospital',
    close: 'Isara',
    noStepsTitle: 'Kailangan ng tulong medikal',
    noStepsBody:
        'Hindi ipinapakita ang mga hakbang sa first aid para sa pinsalang '
        'ito. Magpakonsulta agad sa doktor.',
    emergencyTitle: 'Humingi Agad ng Emergency na Tulong',
    callEmergency: 'Tumawag sa Emergency Services (911)',
    medicalNeeded: 'Kailangan ang tulong medikal',
    nearbyHospitalsButton: 'Malalapit na Ospital',
    closeTooltip: 'Isara',
  );
}
