import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../i18n/app_language.dart';

/// What happened when a recording was started.
enum VoiceStartStatus {
  /// Recording and live transcription both started.
  ok,

  /// The clip is being recorded but live transcription could not start (so no
  /// words will come out of it).
  recordingOnly,

  /// Nothing could be started.
  failed,
}

class VoiceCaptureResult {
  final String? audioPath;
  final String transcript;

  /// The app is in Tagalog but this phone has no Tagalog speech voice, so the
  /// phone's default language was used.
  final bool localeFallback;

  /// The speech engine's last error (eg "error_no_match"), if any — for logs
  /// and friendly messages.
  final String? speechError;

  const VoiceCaptureResult({
    required this.audioPath,
    required this.transcript,
    this.localeFallback = false,
    this.speechError,
  });
}

/// Picks the speech locale for the app language from what the phone offers.
/// For Tagalog it looks for a Filipino/Tagalog locale ("fil_PH", "tl_PH");
/// when there isn't one it reports a fallback to the phone's default (id
/// null). English just uses the phone's default (id null) unless an exact
/// English locale is offered.
({String? id, bool usedFallback}) chooseSpeechLocale(
  Iterable<String> availableIds, {
  required bool tagalog,
}) {
  String norm(String s) => s.toLowerCase().replaceAll('-', '_');
  if (tagalog) {
    for (final id in availableIds) {
      final n = norm(id);
      if (n.startsWith('fil') || n.startsWith('tl')) {
        return (id: id, usedFallback: false);
      }
    }
    return (id: null, usedFallback: true);
  }
  for (final id in availableIds) {
    if (norm(id) == 'en_us') return (id: id, usedFallback: false);
  }
  return (id: null, usedFallback: false);
}

/// Captures a follow-up question spoken aloud: records the clip to a local
/// file (so it can be replayed as a chat bubble) while transcribing it at
/// the same time via the platform's speech recognizer.
///
/// Reliability notes (this used to fail intermittently):
/// - The speech engine is initialized once and awaited before anything is
///   started (and re-initialized after a fatal engine error).
/// - The recognizer must be really listening before the file recorder grabs
///   the microphone, so the recorder can't starve it.
/// - [stop] waits for the recognizer's final result, so the last words are
///   not lost.
/// - It follows the app language, with a fallback when the phone has no
///   Tagalog voice.
/// - A start that fails is retried once; errors are logged and reported,
///   never swallowed.
class VoiceInputService {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool>? _initFuture;
  bool _speechReady = false;

  String _liveTranscript = '';
  String? _recordingPath;
  String? _lastSpeechError;
  bool _localeFallback = false;
  bool _lastListenStarted = false;
  Completer<void>? _listening;
  Completer<void>? _finalResult;

  /// Initializes the speech engine once; concurrent callers share the same
  /// attempt. A failed attempt can be retried on the next call.
  Future<bool> _ensureSpeech() {
    if (_speechReady) return Future.value(true);
    return _initFuture ??= _speech
        .initialize(onError: _onSpeechError, onStatus: _onSpeechStatus)
        .then((ok) {
          _speechReady = ok;
          if (!ok) _initFuture = null;
          return ok;
        })
        .catchError((Object e) {
          debugPrint('[VoiceInput] speech initialize failed: $e');
          _initFuture = null;
          return false;
        });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _lastSpeechError = error.errorMsg;
    debugPrint(
      '[VoiceInput] speech error: ${error.errorMsg} '
      '(permanent: ${error.permanent})',
    );
    // A permanent error means the engine is no good any more: set it up
    // again the next time.
    if (error.permanent) {
      _speechReady = false;
      _initFuture = null;
    }
    _finish(_finalResult);
  }

  void _onSpeechStatus(String status) {
    debugPrint('[VoiceInput] speech status: $status');
    if (status == stt.SpeechToText.listeningStatus) _finish(_listening);
    // "done" comes after the final result (unlike "notListening", which can
    // fire earlier, even before the session has really started).
    if (status == stt.SpeechToText.doneStatus) _finish(_finalResult);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _liveTranscript = result.recognizedWords;
    if (result.finalResult) _finish(_finalResult);
  }

  void _finish(Completer<void>? c) {
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<bool> get isAvailable async {
    final speech = await _ensureSpeech();
    return speech && await _recorder.hasPermission();
  }

  /// Live mic level normalized to 0..1, used to drive the recording bar's
  /// pulse animation.
  Stream<double> amplitudeStream() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 150))
      .map((amp) => ((amp.current + 45) / 45).clamp(0.0, 1.0));

  /// The speech locale for the current app language (see [chooseSpeechLocale]).
  Future<String?> _pickLocale() async {
    final tagalog = AppLanguageController.instance.language == AppLanguage.tl;
    try {
      final locales = await _speech.locales();
      final choice = chooseSpeechLocale(
        locales.map((l) => l.localeId),
        tagalog: tagalog,
      );
      _localeFallback = choice.usedFallback;
      return choice.id;
    } catch (e) {
      debugPrint('[VoiceInput] could not list speech locales: $e');
      _localeFallback = tagalog;
      return null;
    }
  }

  /// Starts the recognizer and waits until it really is listening.
  Future<bool> _beginListening(String? localeId) async {
    _listening = Completer<void>();
    _finalResult = Completer<void>();
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        // Not forcing onDevice: true — on many phones without a downloaded
        // offline speech model a strictly on-device session silently
        // produces nothing. Leaving it unset lets the platform use its
        // on-device recognizer when there is one and fall back otherwise.
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('[VoiceInput] listen() failed to start: $e');
      return false;
    }
    // listen() returns before the microphone is actually open; the recorder
    // must not start until the recognizer has it.
    await _listening!.future.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () {},
    );
    return _speech.isListening;
  }

  Future<bool> _beginRecording() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _recorder.start(const RecordConfig(), path: _recordingPath!);
        return true;
      } catch (e) {
        debugPrint('[VoiceInput] recorder.start() failed (try $attempt): $e');
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }

  Future<VoiceStartStatus> start() async {
    _liveTranscript = '';
    _lastSpeechError = null;
    _localeFallback = false;
    _lastListenStarted = false;
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_followup_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Speech first (waited until it is really listening), then the recorder.
    var listening = false;
    if (await _ensureSpeech()) {
      final localeId = await _pickLocale();
      listening = await _beginListening(localeId);
      if (!listening) {
        // One retry with a freshly set-up engine.
        debugPrint('[VoiceInput] retrying speech start once');
        try {
          await _speech.cancel();
        } catch (_) {}
        _speechReady = false;
        _initFuture = null;
        if (await _ensureSpeech()) listening = await _beginListening(localeId);
      }
    }
    _lastListenStarted = listening;

    final recording = await _beginRecording();

    if (listening) return VoiceStartStatus.ok;
    return recording ? VoiceStartStatus.recordingOnly : VoiceStartStatus.failed;
  }

  Future<VoiceCaptureResult> stop() async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('[VoiceInput] recorder.stop() failed: $e');
    }
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('[VoiceInput] speech.stop() failed: $e');
      }
    }
    // Wait for the recognizer's final result — it arrives just after stop()
    // returns, and without it the last words (or all of them) are lost.
    await _finalResult?.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );

    String? finalPath;
    if (path != null && await File(path).exists()) {
      finalPath = path;
    }
    debugPrint(
      '[VoiceInput] stop(): listenStarted=$_lastListenStarted '
      'transcriptLength=${_liveTranscript.trim().length} '
      'audioSaved=${finalPath != null} error=$_lastSpeechError '
      'localeFallback=$_localeFallback',
    );
    return VoiceCaptureResult(
      audioPath: finalPath,
      transcript: _liveTranscript.trim(),
      localeFallback: _localeFallback,
      speechError: _lastSpeechError,
    );
  }

  Future<void> cancel() async {
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } catch (e) {
      debugPrint('[VoiceInput] recorder.cancel() failed: $e');
    }
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (e) {
      debugPrint('[VoiceInput] speech.cancel() failed: $e');
    }
    final path = _recordingPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    _liveTranscript = '';
  }

  void dispose() {
    // Release the speech session too, not just the recorder.
    try {
      unawaited(_speech.cancel());
    } catch (_) {}
    _recorder.dispose();
  }
}
