import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Longest side, in pixels, a photo is shrunk to before it is sent to the
/// AI. Camera photos are several MB at full resolution, which made uploads
/// slow and prone to timing out.
const int kUploadMaxSide = 1280;

/// JPEG quality (0-100) for the compressed copy.
const int kUploadJpegQuality = 85;

/// Decodes [bytes], applies the camera's EXIF rotation (re-encoding drops
/// the EXIF tag, so without this a rotated photo would come out sideways),
/// shrinks it so its longest side is at most [maxSide] (never enlarging),
/// and re-encodes it as JPEG. Pure — no file access — so it is unit
/// testable. Returns null if [bytes] isn't a decodable image.
Uint8List? compressImageBytes(
  Uint8List bytes, {
  int maxSide = kUploadMaxSide,
  int quality = kUploadJpegQuality,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    var image = img.bakeOrientation(decoded);
    if (image.width > maxSide || image.height > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide)
          : img.copyResize(image, height: maxSide);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  } catch (_) {
    return null;
  }
}

/// Writes a compressed copy of the photo at [originalPath] next to it and
/// returns the copy's path. Runs the heavy decode/resize off the UI thread.
/// If anything goes wrong the original path is returned, so a scan is never
/// blocked by compression.
Future<String> compressImageFile(String originalPath) async {
  try {
    final bytes = await File(originalPath).readAsBytes();
    final compressed = await compute(_compressEntry, bytes);
    if (compressed == null) return originalPath;

    final out = File('${originalPath}_compressed.jpg');
    await out.writeAsBytes(compressed);
    return out.path;
  } catch (e) {
    debugPrint('compressImageFile failed, using the original: $e');
    return originalPath;
  }
}

Uint8List? _compressEntry(Uint8List bytes) => compressImageBytes(bytes);
