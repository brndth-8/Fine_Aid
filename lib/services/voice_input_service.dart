import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCaptureResult {
  final String? audioPath;
  final String transcript;
  const VoiceCaptureResult({required this.audioPath, required this.transcript});
}

/// Captures a follow-up question spoken aloud: records the clip to a local
/// file (so it can be replayed as a chat bubble) while transcribing it at
/// the same time via the platform's on-device speech recognizer. Both steps
/// run entirely on-device — no audio or text leaves the phone to produce
/// the transcript, so this keeps working with no internet connection.
class VoiceInputService {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  String _liveTranscript = '';
  String? _recordingPath;

  Future<bool> get isAvailable async {
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onError: (e) => debugPrint('[VoiceInput] speech error: $e'),
      );
    }
    return _speechInitialized && await _recorder.hasPermission();
  }

  /// Live mic level normalized to 0..1, used to drive the recording bar's
  /// pulse animation.
  Stream<double> amplitudeStream() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 150))
      .map((amp) => ((amp.current + 45) / 45).clamp(0.0, 1.0));

  bool _lastListenStarted = false;

  Future<void> start() async {
    _liveTranscript = '';
    _lastListenStarted = false;
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_followup_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Start the speech recognizer BEFORE the file recorder, not after.
    // Both want exclusive access to the mic (SpeechRecognizer typically
    // goes through a separate system recognition service/app, `record`
    // captures directly via AudioRecord in-process) — on some devices
    // requesting them in this order lets Android's audio policy hand the
    // recognizer priority instead of the raw recorder silently starving
    // it. This isn't a guaranteed fix (concurrent mic capture support
    // varies by OEM/Android version), but it's a safe, low-risk ordering
    // change over starting the plain recorder first.
    try {
      await _speech.listen(
        onResult: (result) => _liveTranscript = result.recognizedWords,
        // Not forcing onDevice: true here — on a lot of real devices
        // (anything without a downloaded offline speech model, which is
        // most phones without Google Play Services, eg Huawei/Honor) a
        // strictly on-device-only recognition session silently produces no
        // results at all, so voice input would just never work. Leaving
        // this unset lets the platform use its on-device recognizer when
        // one is available and fall back to network-assisted recognition
        // otherwise — the recording itself is still fully local either
        // way, and a plain network hiccup still just falls through to the
        // existing "couldn't catch that" message rather than crashing.
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 8),
        ),
      );
      _lastListenStarted = true;
    } catch (e) {
      // The audio clip can still be recorded and sent even if live
      // transcription never started — stop() reports which parts actually
      // worked instead of just going silent.
      debugPrint('[VoiceInput] listen() failed to start: $e');
    }

    try {
      await _recorder.start(const RecordConfig(), path: _recordingPath!);
    } catch (e) {
      debugPrint('[VoiceInput] recorder.start() failed: $e');
    }
  }

  Future<VoiceCaptureResult> stop() async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('[VoiceInput] recorder.stop() failed: $e');
    }
    if (_speech.isListening) await _speech.stop();

    String? finalPath;
    if (path != null && await File(path).exists()) {
      finalPath = path;
    }
    debugPrint(
      '[VoiceInput] stop(): listenStarted=$_lastListenStarted '
      'transcriptLength=${_liveTranscript.trim().length} '
      'audioSaved=${finalPath != null}',
    );
    return VoiceCaptureResult(
      audioPath: finalPath,
      transcript: _liveTranscript.trim(),
    );
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) await _recorder.cancel();
    if (_speech.isListening) await _speech.cancel();
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
    _recorder.dispose();
  }
}
