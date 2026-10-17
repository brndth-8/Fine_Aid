import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for attaching a photo in the "Need More Help" chat (eg to show a
/// healthcare professional how a wound is healing), English + Tagalog.
/// Review the Tagalog before release.
class ChatUploadStrings {
  final String addFile;
  final String takePhoto;
  final String chooseFromGallery;
  final String removePhoto;
  final String photoReady;
  final String uploading;
  final String savedMessage;
  final String uploadFailed;
  final String loginRequired;

  const ChatUploadStrings({
    required this.addFile,
    required this.takePhoto,
    required this.chooseFromGallery,
    required this.removePhoto,
    required this.photoReady,
    required this.uploading,
    required this.savedMessage,
    required this.uploadFailed,
    required this.loginRequired,
  });

  static ChatUploadStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = ChatUploadStrings(
    addFile: 'Add photo',
    takePhoto: 'Take a photo',
    chooseFromGallery: 'Choose from gallery',
    removePhoto: 'Remove photo',
    photoReady: 'Photo ready to send',
    uploading: 'Uploading photo...',
    savedMessage:
        'Your photo was saved. You can show it to a healthcare professional '
        'so they can see how your wound is healing.',
    uploadFailed:
        'Could not upload the photo. Please check your connection and try '
        'again.',
    loginRequired: 'Please log in to upload a photo.',
  );

  static const tl = ChatUploadStrings(
    addFile: 'Magdagdag ng larawan',
    takePhoto: 'Kumuha ng larawan',
    chooseFromGallery: 'Pumili mula sa gallery',
    removePhoto: 'Alisin ang larawan',
    photoReady: 'Handa nang ipadala ang larawan',
    uploading: 'Ina-upload ang larawan...',
    savedMessage:
        'Na-save ang iyong larawan. Maaari mo itong ipakita sa propesyonal '
        'sa kalusugan para makita nila kung paano gumagaling ang iyong sugat.',
    uploadFailed:
        'Hindi na-upload ang larawan. Pakisuri ang iyong koneksyon at '
        'subukang muli.',
    loginRequired: 'Mag-log in para makapag-upload ng larawan.',
  );
}
