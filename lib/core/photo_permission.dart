import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/photo_strings.dart';

enum PhotoSource { camera, gallery }

const String _galleryExplainedPrefsKey = 'photo_gallery_access_explained';

/// The platform calls behind [ensurePhotoPermission], swappable in tests.
class PhotoPermissionGateway {
  Future<PermissionStatus> cameraStatus() => Permission.camera.status;
  Future<PermissionStatus> requestCamera() => Permission.camera.request();
  Future<bool> openSettings() => openAppSettings();
}

PhotoPermissionGateway photoPermissionGateway = PhotoPermissionGateway();

/// Makes sure the app may use [source] before it is opened. Returns true
/// when the camera / gallery can be opened now.
///
/// - Camera: explains why first, then asks for the camera permission. If it
///   is refused (or blocked), says so and offers "Open Settings".
/// - Gallery: the system photo picker needs no permission on Android, so
///   this only explains (once) why the app opens the photos.
Future<bool> ensurePhotoPermission(BuildContext context, PhotoSource source) =>
    source == PhotoSource.camera
    ? _ensureCamera(context)
    : _ensureGallery(context);

Future<bool> _ensureCamera(BuildContext context) async {
  final status = await photoPermissionGateway.cameraStatus();
  if (status.isGranted) return true;
  if (!context.mounted) return false;
  final s = PhotoStrings.of(context);

  // Already blocked: the system dialog won't show again, so go straight to
  // the "turn it on in Settings" message.
  if (!status.isPermanentlyDenied) {
    final proceed = await _explain(
      context,
      title: s.cameraAccessTitle,
      body: s.cameraAccessBody,
    );
    if (proceed != true) return false;
    final result = await photoPermissionGateway.requestCamera();
    if (result.isGranted) return true;
    if (!context.mounted) return false;
  }

  await _showDenied(context);
  return false;
}

Future<bool> _ensureGallery(BuildContext context) async {
  final s = PhotoStrings.of(context);
  bool alreadyExplained = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    alreadyExplained = prefs.getBool(_galleryExplainedPrefsKey) ?? false;
  } catch (_) {}
  if (alreadyExplained) return true;
  if (!context.mounted) return false;

  final proceed = await _explain(
    context,
    title: s.galleryAccessTitle,
    body: s.galleryAccessBody,
  );
  if (proceed != true) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_galleryExplainedPrefsKey, true);
  } catch (_) {}
  return true;
}

Future<bool?> _explain(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final s = PhotoStrings.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(body),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(s.notNow),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(s.continueLabel),
        ),
      ],
    ),
  );
}

Future<void> _showDenied(BuildContext context) {
  final s = PhotoStrings.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(s.cameraDeniedTitle),
      content: Text(s.cameraDeniedBody),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            photoPermissionGateway.openSettings();
          },
          child: Text(s.openSettings),
        ),
      ],
    ),
  );
}
