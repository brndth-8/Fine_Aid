import 'dart:async';
import 'dart:io';

/// Shown in place of a raw exception, or in place of a message implying
/// something else went wrong, whenever a failure is actually about
/// connectivity rather than the AI/server itself.
const String noInternetMessage = 'No internet connection';

/// True when [error] looks like a network-connectivity failure (as opposed
/// to a real AI/server/logic failure) — used so the same friendly
/// [noInternetMessage] shows up everywhere a network call can fail,
/// instead of a raw exception or a message that implies something else
/// broke (eg, "couldn't get a clear answer").
bool isNetworkError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('timeoutexception') ||
      text.contains('connection timed out') ||
      text.contains('connection refused') ||
      text.contains('no address associated with hostname') ||
      text.contains('software caused connection abort');
}
