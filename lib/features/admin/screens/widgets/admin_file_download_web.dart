import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Downloads [bytes] straight to the device as a file named [filename]: a
/// temporary link to the data is clicked, which makes the browser save it. It
/// is not the share sheet or any dialog the page builds.
Future<void> downloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blobType = globalContext.getProperty<JSFunction>('Blob'.toJS);
  final options = JSObject()..setProperty('type'.toJS, mimeType.toJS);
  final blob = blobType.callAsConstructor<JSObject>(
    <JSAny?>[bytes.toJS].toJS,
    options,
  );

  final urlApi = globalContext.getProperty<JSObject>('URL'.toJS);
  final objectUrl = urlApi
      .callMethod<JSString>('createObjectURL'.toJS, blob)
      .toDart;

  final document = globalContext.getProperty<JSObject>('document'.toJS);
  final link = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS)
    ..setProperty('href'.toJS, objectUrl.toJS)
    ..setProperty('download'.toJS, filename.toJS);
  final body = document.getProperty<JSObject>('body'.toJS);
  body.callMethod<JSAny?>('appendChild'.toJS, link);
  link.callMethod<JSAny?>('click'.toJS);
  body.callMethod<JSAny?>('removeChild'.toJS, link);
  // Give the browser a moment to start the download before releasing the data.
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, objectUrl.toJS),
  );
}
