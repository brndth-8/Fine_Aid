import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../admin_config.dart';
import 'admin_activity_sync_stub.dart'
    if (dart.library.js_interop) 'admin_activity_sync_web.dart';

/// Signs the admin out after [timeout] without real activity, with a warning
/// dialog [warning] before that. Wrap only the signed-in dashboard: the login
/// screen is outside it, so no timer runs there.
///
/// "Activity" is a pointer press or drag, a mouse-wheel/trackpad scroll or a
/// key press — all of which cover navigation too, since the sidebar is
/// clicked. Hover, polling and Firestore/stream updates deliberately do not
/// count. The timer compares wall-clock time, so a laptop that slept past the
/// limit signs out on wake-up. With the warning showing, only its "Stay
/// signed in" button counts, so stray movement can't hide it.
class AdminIdleGuard extends StatefulWidget {
  const AdminIdleGuard({
    super.key,
    required this.child,
    required this.onIdleTimeout,
    this.timeout = kAdminIdleTimeout,
    this.warning = kAdminIdleWarning,
    this.clock = DateTime.now,
  });

  final Widget child;
  final Future<void> Function() onIdleTimeout;
  final Duration timeout;
  final Duration warning;

  /// Current time; replaceable so tests can move time without waiting.
  final DateTime Function() clock;

  @override
  State<AdminIdleGuard> createState() => _AdminIdleGuardState();
}

class _AdminIdleGuardState extends State<AdminIdleGuard> {
  late DateTime _lastActivity = widget.clock();
  DateTime _lastPublished = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _ticker;
  late final AdminActivitySync _sync;
  final ValueNotifier<int> _secondsLeft = ValueNotifier(0);
  BuildContext? _dialogContext;
  bool _fired = false;

  bool get _warningOpen => _dialogContext != null;

  @override
  void initState() {
    super.initState();
    _sync = AdminActivitySync(_onRemoteActivity);
    HardwareKeyboard.instance.addHandler(_onKey);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _sync.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _touch();
    return false; // Observe only; never swallow the key.
  }

  void _touch() {
    if (_warningOpen || _fired) return;
    final now = widget.clock();
    _lastActivity = now;
    // Tell other tabs, at most once a second.
    if (now.difference(_lastPublished) >= const Duration(seconds: 1)) {
      _lastPublished = now;
      _sync.publish(now.millisecondsSinceEpoch);
    }
  }

  void _onRemoteActivity(int millis) {
    if (_fired) return;
    final remote = DateTime.fromMillisecondsSinceEpoch(millis);
    if (!remote.isAfter(_lastActivity)) return;
    _lastActivity = remote;
    _closeWarning(); // The admin is active in another tab.
  }

  void _tick() {
    if (!mounted || _fired) return;
    final idle = widget.clock().difference(_lastActivity);
    if (idle >= widget.timeout) {
      _fired = true;
      _closeWarning();
      widget.onIdleTimeout();
      return;
    }
    final untilLogout = widget.timeout - idle;
    if (untilLogout <= widget.warning) {
      _secondsLeft.value = untilLogout.inSeconds + 1;
      if (!_warningOpen) _showWarning();
    }
  }

  void _closeWarning() {
    final dialogContext = _dialogContext;
    _dialogContext = null;
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  void _stay() {
    _closeWarning();
    _touch();
  }

  void _showWarning() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Are you still there?'),
            content: ValueListenableBuilder<int>(
              valueListenable: _secondsLeft,
              builder: (context, seconds, _) => Text(
                'You will be signed out soon due to inactivity '
                '(in $seconds seconds).',
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: _stay,
                child: const Text('Stay signed in'),
              ),
            ],
          ),
        );
      },
    ).then((_) => _dialogContext = null);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerMove: (_) => _touch(),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _touch();
      },
      child: widget.child,
    );
  }
}
