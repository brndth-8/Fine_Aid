import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for adding a photo to a Health Journal entry — the Take photo /
/// Upload image chooser, the permission explanations, the denied message and
/// the photo preview — English + Tagalog. Review the Tagalog before release.
class PhotoStrings {
  final String addImage;
  final String chooseTitle;
  final String takePhoto;
  final String uploadImage;
  final String cameraAccessTitle;
  final String cameraAccessBody;
  final String galleryAccessTitle;
  final String galleryAccessBody;
  final String continueLabel;
  final String notNow;
  final String cameraDeniedTitle;
  final String cameraDeniedBody;
  final String openSettings;
  final String cancel;
  final String previewTitle;
  final String retake;
  final String chooseAnother;
  final String remove;
  final String usePhoto;
  final String couldNotAddPhoto;

  const PhotoStrings({
    required this.addImage,
    required this.chooseTitle,
    required this.takePhoto,
    required this.uploadImage,
    required this.cameraAccessTitle,
    required this.cameraAccessBody,
    required this.galleryAccessTitle,
    required this.galleryAccessBody,
    required this.continueLabel,
    required this.notNow,
    required this.cameraDeniedTitle,
    required this.cameraDeniedBody,
    required this.openSettings,
    required this.cancel,
    required this.previewTitle,
    required this.retake,
    required this.chooseAnother,
    required this.remove,
    required this.usePhoto,
    required this.couldNotAddPhoto,
  });

  static PhotoStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = PhotoStrings(
    addImage: 'Add Image',
    chooseTitle: 'Add a photo',
    takePhoto: 'Take photo',
    uploadImage: 'Upload image',
    cameraAccessTitle: 'Allow camera access?',
    cameraAccessBody:
        'Fine Aid needs your camera to take a photo of your wound or skin '
        'issue for this journal entry. The photo is saved only to your '
        'account.',
    galleryAccessTitle: 'Allow photo access?',
    galleryAccessBody:
        'Fine Aid needs to open your photos so you can choose an image of '
        'your wound or skin issue for this journal entry. Only the photo you '
        'pick is used.',
    continueLabel: 'Continue',
    notNow: 'Not now',
    cameraDeniedTitle: 'Camera access is off',
    cameraDeniedBody:
        'Without camera access, Fine Aid can\'t take a photo. You can turn '
        'it on in your phone\'s app settings, or use Upload image instead.',
    openSettings: 'Open Settings',
    cancel: 'Cancel',
    previewTitle: 'Photo preview',
    retake: 'Retake',
    chooseAnother: 'Choose another',
    remove: 'Remove',
    usePhoto: 'Use photo',
    couldNotAddPhoto: 'Could not add the photo. Please try again.',
  );

  static const tl = PhotoStrings(
    addImage: 'Magdagdag ng Larawan',
    chooseTitle: 'Magdagdag ng larawan',
    takePhoto: 'Kumuha ng larawan',
    uploadImage: 'Mag-upload ng larawan',
    cameraAccessTitle: 'Payagan ang access sa camera?',
    cameraAccessBody:
        'Kailangan ng Fine Aid ang iyong camera para makakuha ng larawan ng '
        'iyong sugat o problema sa balat para sa journal entry na ito. Ang '
        'larawan ay sine-save lamang sa iyong account.',
    galleryAccessTitle: 'Payagan ang access sa mga larawan?',
    galleryAccessBody:
        'Kailangan ng Fine Aid na buksan ang iyong mga larawan para makapili '
        'ka ng larawan ng iyong sugat o problema sa balat para sa journal '
        'entry na ito. Ang larawang pipiliin mo lamang ang gagamitin.',
    continueLabel: 'Magpatuloy',
    notNow: 'Hindi muna',
    cameraDeniedTitle: 'Naka-off ang access sa camera',
    cameraDeniedBody:
        'Kung walang access sa camera, hindi makakakuha ng larawan ang Fine '
        'Aid. Maaari mo itong i-on sa app settings ng iyong telepono, o '
        'gamitin ang Mag-upload ng larawan.',
    openSettings: 'Buksan ang Settings',
    cancel: 'Kanselahin',
    previewTitle: 'Preview ng larawan',
    retake: 'Kumuha ulit',
    chooseAnother: 'Pumili ng iba',
    remove: 'Alisin',
    usePhoto: 'Gamitin ang larawan',
    couldNotAddPhoto: 'Hindi naidagdag ang larawan. Pakisubukan muli.',
  );
}
