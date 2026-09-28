import 'dart:math';
import 'package:flutter/foundation.dart';

// A few caring, varied ways to say "that didn't work" without ever
// surfacing a raw exception, error code, or technical detail to the user.
// Shared by every follow-up Q&A surface (First Aid Kit, AI Camera, the
// standalone chatbot) so they all fail the same friendly way.
const List<String> followUpFallbackMessages = [
  "Hmm, I'm having a little trouble answering that right now. Mind trying "
      'again in a moment?',
  "Sorry about that - I couldn't get a clear answer through. Could you "
      'ask again?',
  "I wasn't able to work that one out just now. Let's try again whenever "
      "you're ready.",
  "Something got in the way there. I'm still here - feel free to ask "
      'again.',
  "That didn't quite come through on my end. Try again when you can, I'm "
      'listening.',
];

final Random _followUpFallbackRandom = Random();

String randomFollowUpFallbackMessage() =>
    followUpFallbackMessages[_followUpFallbackRandom.nextInt(
      followUpFallbackMessages.length,
    )];

// Every follow-up-question failure — network error, timeout, an empty or
// malformed model reply — should funnel through here. The real cause is
// logged for developers/debugging only and never reaches the UI.
void logFollowUpError(String screen, Object error, StackTrace stackTrace) {
  debugPrint('[$screen] follow-up question failed: $error');
  debugPrintStack(stackTrace: stackTrace, label: '[$screen]');
}
