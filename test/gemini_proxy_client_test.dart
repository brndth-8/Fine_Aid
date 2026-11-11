import 'dart:convert';
import 'dart:io';

import 'package:fine_aid/services/api/gemini_proxy_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Request? seen;
  final inner = MockClient.streaming((request, bodyStream) async {
    seen = request as http.Request;
    final text = jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'hello from the server'},
            ],
          },
        },
      ],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(text)),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  GeminiProxyClient client({String? token}) => GeminiProxyClient(
    inner: inner,
    endpoint: Uri.https('example.test', '/geminiProxy'),
    tokenProvider: () async => token,
  );

  setUp(() => seen = null);

  test(
    'the Gemini package talks to the proxy, with no key of its own',
    () async {
      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: geminiProxyApiKey,
        httpClient: client(token: 'abc'),
      );
      final reply = await model.generateContent([Content.text('hi')]);

      expect(reply.text, 'hello from the server');
      expect(seen!.url.host, 'example.test');
      expect(
        seen!.url.path,
        '/geminiProxy/v1beta/models/gemini-3.5-flash:generateContent',
      );
      expect(
        seen!.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-goog-api-key')),
      );
      expect(seen!.headers['authorization'], 'Bearer abc');
      expect(jsonDecode(seen!.body)['contents'], isNotEmpty);
    },
  );

  test('a guest sends no sign-in token', () async {
    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: geminiProxyApiKey,
      httpClient: client(),
    );
    await model.generateContent([Content.text('hi')]);
    expect(seen!.headers.containsKey('authorization'), isFalse);
  });

  test('a chat goes through the proxy too', () async {
    final model = GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: geminiProxyApiKey,
      httpClient: client(),
    );
    final reply = await model.startChat().sendMessage(Content.text('hi'));
    expect(reply.text, 'hello from the server');
    expect(seen!.url.path, endsWith(':generateContent'));
  });

  test('the app no longer holds a Gemini key', () {
    final service = File(
      'lib/services/api/gemini_service.dart',
    ).readAsStringSync();
    expect(service, isNot(contains('ApiKeys.gemini')));
    expect(service, isNot(contains('constants/api_keys.dart')));
    // and no key file at all any more (the SMS key moved to the server too)
    expect(File('lib/core/constants/api_keys.dart').existsSync(), isFalse);
  });
}
