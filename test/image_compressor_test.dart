import 'dart:typed_data';
import 'package:fine_aid/services/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg(int w, int h, {int? exifOrientation}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 120, 100));
  if (exifOrientation != null) {
    image.exif.imageIfd.orientation = exifOrientation;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('a large landscape photo is shrunk to the max side, keeping aspect', () {
    final out = compressImageBytes(_jpeg(4000, 3000), maxSide: 1280)!;
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 1280);
    expect(decoded.height, 960);
  });

  test('a large portrait photo is shrunk by its height', () {
    final out = compressImageBytes(_jpeg(3000, 4000), maxSide: 1280)!;
    final decoded = img.decodeImage(out)!;
    expect(decoded.height, 1280);
    expect(decoded.width, 960);
  });

  test('a small photo is never enlarged', () {
    final out = compressImageBytes(_jpeg(600, 400), maxSide: 1280)!;
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 600);
    expect(decoded.height, 400);
  });

  test('the compressed copy is much smaller than a full-size photo', () {
    final original = _jpeg(4000, 3000);
    final out = compressImageBytes(original)!;
    expect(out.length, lessThan(original.length));
  });

  test('a rotated photo (EXIF orientation 6) comes out upright', () {
    // Stored 400x200 with a "rotate 90" tag: shown, it is 200 wide x 400 tall.
    final out = compressImageBytes(_jpeg(400, 200, exifOrientation: 6))!;
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 200);
    expect(decoded.height, 400);
  });

  test('bytes that are not an image return null instead of throwing', () {
    expect(compressImageBytes(Uint8List.fromList([1, 2, 3])), isNull);
    expect(compressImageBytes(Uint8List(0)), isNull);
  });

  test('a missing file falls back to the original path', () async {
    const missing = '/no/such/photo.jpg';
    expect(await compressImageFile(missing), missing);
  });
}
