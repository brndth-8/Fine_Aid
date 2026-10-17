import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../i18n/voice_strings.dart';

/// Playable audio row for a recorded follow-up question — play/pause,
/// a progress bar, and elapsed/duration time. Shared by every follow-up
/// Q&A surface that supports voice input (First Aid Kit, AI Camera).
class VoiceMessageBubble extends StatefulWidget {
  final String audioPath;
  final bool isUser;
  const VoiceMessageBubble({
    super.key,
    required this.audioPath,
    required this.isUser,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  // The clip that is playing now — starting another one stops it, so clips
  // never play over each other.
  static _VoiceMessageBubbleState? _active;

  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    // Ask for audio focus when playing, so other apps' audio makes way.
    _player
        .setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.gain).build(),
        )
        .catchError((Object e) {
          debugPrint('[VoiceMessageBubble] audio context not set: $e');
        });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      final other = _active;
      if (other != null && other != this && other.mounted) {
        try {
          await other._player.stop();
        } catch (_) {}
      }
      _active = this;
      await _play();
    }
  }

  /// Plays the clip; one retry after a failure, then a friendly message —
  /// the app keeps working either way.
  Future<void> _play() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _player.play(DeviceFileSource(widget.audioPath));
        return;
      } catch (e) {
        debugPrint('[VoiceMessageBubble] play failed (try $attempt): $e');
        try {
          await _player.stop();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(VoiceStrings.of(context).couldNotPlay)),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isUser
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    final total = _duration > Duration.zero ? _duration : _position;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / total.inMilliseconds;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            _state == PlayerState.playing
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
            color: color,
          ),
          onPressed: _toggle,
        ),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _format(_state == PlayerState.stopped ? _duration : _position),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
