import 'package:flutter_test/flutter_test.dart';
import 'package:fine_aid/services/api/gemini_usage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

Content user(String text) => Content('user', [TextPart(text)]);
Content model(String text) => Content('model', [TextPart(text)]);

String textOf(Content c) => (c.parts.single as TextPart).text;

void main() {
  group('trimChatHistory', () {
    test('keeps only the last messages and still opens with a user turn', () {
      final history = [
        for (var i = 1; i <= 5; i++) ...[
          user('${chatQuestionMarker}q$i'),
          model('a$i'),
        ],
      ];
      final trimmed = trimChatHistory(history, maxMessages: 4);
      expect(trimmed.map(textOf), [
        '${chatQuestionMarker}q4',
        'a4',
        '${chatQuestionMarker}q5',
        'a5',
      ]);
      expect(trimmed.first.role, 'user');
    });

    test('an odd cut never starts on a model reply', () {
      final history = [
        user('${chatQuestionMarker}q1'),
        model('a1'),
        user('${chatQuestionMarker}q2'),
        model('a2'),
      ];
      final trimmed = trimChatHistory(history, maxMessages: 3);
      expect(trimmed.first.role, 'user');
      expect(trimmed.map(textOf), ['${chatQuestionMarker}q2', 'a2']);
    });

    test('old reference excerpts and wound analysis are cut', () {
      final trimmed = trimChatHistory([
        user(
          'REFERENCE MATERIALS:\n### Cuts\nlong excerpt\n\n'
          'CURRENT WOUND ANALYSIS:\nsteps\n\n'
          '${chatQuestionMarker}how do I clean it?',
        ),
        model('EN: rinse it'),
      ]);
      expect(textOf(trimmed.first), '${chatQuestionMarker}how do I clean it?');
      expect(textOf(trimmed.last), 'EN: rinse it');
    });

    test('does not change the history it was given', () {
      final history = [
        user('REFERENCE MATERIALS:\nx\n\n${chatQuestionMarker}q'),
        model('a'),
      ];
      trimChatHistory(history);
      expect(textOf(history.first), startsWith('REFERENCE MATERIALS'));
    });

    test('an empty history stays empty', () {
      expect(trimChatHistory(const []), isEmpty);
    });
  });

  group('GeminiUsageLog', () {
    setUp(GeminiUsageLog.instance.reset);

    test('totals and averages the reported tokens', () {
      final log = GeminiUsageLog.instance;
      log.record(
        'chat',
        UsageMetadata(
          promptTokenCount: 1000,
          candidatesTokenCount: 200,
          totalTokenCount: 1200,
        ),
      );
      log.record(
        'chat',
        UsageMetadata(
          promptTokenCount: 2000,
          candidatesTokenCount: 400,
          totalTokenCount: 2400,
        ),
      );
      expect(log.calls, 2);
      expect(log.promptTokens, 3000);
      expect(log.outputTokens, 600);
      expect(log.totalTokens, 3600);
      expect(log.averagePromptTokens, 1500);
      expect(log.averageOutputTokens, 300);
      expect(log.callsByLabel, {'chat': 2});
    });

    test('a response with no usage numbers is ignored', () {
      final log = GeminiUsageLog.instance;
      log.record('chat', null);
      log.record('chat', UsageMetadata());
      expect(log.calls, 0);
      expect(log.averagePromptTokens, 0);
    });
  });
}
