import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Where the app's Gemini requests go. The key is kept on the server (the
/// `geminiProxy` Cloud Function), never in the app: this sends the same
/// request the Gemini package would have sent to Google, to that function
/// instead, with the signed-in person's sign-in token when there is one.
final Uri geminiProxyEndpoint = Uri.https(
  'us-central1-fine-aid-9e0a9.cloudfunctions.net',
  '/geminiProxy',
);

class GeminiProxyClient extends http.BaseClient {
  GeminiProxyClient({
    http.Client? inner,
    Uri? endpoint,
    Future<String?> Function()? tokenProvider,
  }) : _inner = inner ?? http.Client(),
       _endpoint = endpoint ?? geminiProxyEndpoint,
       _tokenProvider = tokenProvider ?? _signedInToken;

  final http.Client _inner;
  final Uri _endpoint;
  final Future<String?> Function() _tokenProvider;

  static Future<String?> _signedInToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[Gemini] no sign-in token: $e');
      return null;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final target = http.Request(
      request.method,
      _endpoint.replace(path: '${_endpoint.path}${request.url.path}'),
    )..bodyBytes = body;
    // The package adds its own key header; only the content type goes on.
    final contentType = request.headers['content-type'];
    if (contentType != null) target.headers['content-type'] = contentType;
    final token = await _tokenProvider();
    if (token != null) target.headers['authorization'] = 'Bearer $token';
    return _inner.send(target);
  }

  @override
  void close() => _inner.close();
}

/// One shared client for every Gemini model the app builds.
final GeminiProxyClient geminiProxyClient = GeminiProxyClient();

/// The Gemini package needs some key text; the real one is added by the
/// server, so this value is never used.
const String geminiProxyApiKey = 'via-proxy';
