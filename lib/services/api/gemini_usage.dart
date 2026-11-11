import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';

/// Marker that starts the user's own words inside a chat message built by
/// GeminiService.sendChatMessage; everything before it is the per-turn
/// REFERENCE MATERIALS / CURRENT WOUND ANALYSIS context.
const String chatQuestionMarker = 'USER QUESTION: ';

/// How many past messages (a question and its reply count as two) the chat
/// keeps sending to Gemini: the last 3 exchanges.
const int maxChatHistoryMessages = 6;

/// The chat history to resend with the next message.
///
/// Gemini is stateless, so every turn resends the whole history. Two things
/// keep that from growing without bound: only the last [maxMessages] messages
/// are kept, and the bulky per-turn context (reference excerpts and wound
/// analysis) is cut from the older questions, leaving just what the user
/// asked. The new message is sent separately and still carries its full
/// context. The result always starts with a user message and never mutates
/// [history].
List<Content> trimChatHistory(
  Iterable<Content> history, {
  int maxMessages = maxChatHistoryMessages,
}) {
  var kept = history.toList();
  if (kept.length > maxMessages) kept = kept.sublist(kept.length - maxMessages);
  // A history has to open with the user's turn.
  while (kept.isNotEmpty && kept.first.role != 'user') {
    kept = kept.sublist(1);
  }
  return [
    for (final content in kept)
      content.role == 'user' ? _withoutContext(content) : content,
  ];
}

Content _withoutContext(Content content) {
  return Content(content.role, [
    for (final part in content.parts)
      if (part is TextPart) TextPart(_afterMarker(part.text)) else part,
  ]);
}

String _afterMarker(String text) {
  final at = text.indexOf(chatQuestionMarker);
  return at < 0 ? text : text.substring(at);
}

/// Token counts reported by Gemini for each call, printed in debug builds and
/// totalled for the running session (nothing is stored or sent anywhere).
class GeminiUsageLog {
  GeminiUsageLog._();
  static final GeminiUsageLog instance = GeminiUsageLog._();

  int _calls = 0;
  int _promptTokens = 0;
  int _outputTokens = 0;
  final Map<String, int> _callsByLabel = {};

  int get calls => _calls;
  int get promptTokens => _promptTokens;
  int get outputTokens => _outputTokens;
  int get totalTokens => _promptTokens + _outputTokens;
  Map<String, int> get callsByLabel => Map.unmodifiable(_callsByLabel);

  double get averagePromptTokens => _calls == 0 ? 0 : _promptTokens / _calls;
  double get averageOutputTokens => _calls == 0 ? 0 : _outputTokens / _calls;

  /// Records one response. [label] names the call ('chat', 'assessment', ...).
  /// A response without usage numbers is ignored.
  void record(String label, UsageMetadata? usage) {
    final prompt = usage?.promptTokenCount;
    final output = usage?.candidatesTokenCount;
    if (prompt == null && output == null) return;
    _calls++;
    _promptTokens += prompt ?? 0;
    _outputTokens += output ?? 0;
    _callsByLabel[label] = (_callsByLabel[label] ?? 0) + 1;
    debugPrint(
      '[Gemini tokens] $label: prompt=${prompt ?? '?'} '
      'output=${output ?? '?'} total=${usage?.totalTokenCount ?? '?'} '
      '(session avg: prompt ${averagePromptTokens.round()}, '
      'output ${averageOutputTokens.round()} over $_calls calls)',
    );
  }

  void reset() {
    _calls = 0;
    _promptTokens = 0;
    _outputTokens = 0;
    _callsByLabel.clear();
  }
}
