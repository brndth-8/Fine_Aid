import 'dart:typed_data';

/// Saves a file to the device. The admin portal is a web app, so the real
/// implementation (admin_file_download_web.dart) is a browser download; this
/// stub only exists so the code still compiles on other platforms.
Future<void> downloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  throw UnsupportedError(
    'Downloads are only available in the web admin portal.',
  );
}
