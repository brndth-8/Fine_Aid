import 'dart:js_interop';
import 'dart:js_interop_unsafe';

const _key = 'fineAidAdminLastActivity';

/// Shares the time of the admin's last activity between tabs through
/// localStorage and its `storage` event (which only fires in the *other*
/// tabs). Activity in any tab therefore keeps every tab's idle timer alive,
/// so a tab the admin isn't looking at can't sign them out mid-work.
/// Signing out already applies to all tabs: Firebase Auth shares one session
/// across them and AdminGate reacts to it.
class AdminActivitySync {
  AdminActivitySync(this._onRemoteActivity) {
    _listener = ((JSObject event) {
      try {
        final key = event.getProperty<JSAny?>('key'.toJS).dartify();
        if (key != _key) return;
        final value = event.getProperty<JSAny?>('newValue'.toJS).dartify();
        final millis = value is String ? int.tryParse(value) : null;
        if (millis != null) _onRemoteActivity(millis);
      } catch (_) {
        // A malformed event is ignored; it must never break the timer.
      }
    }).toJS;
    try {
      globalContext.callMethod<JSAny?>(
        'addEventListener'.toJS,
        'storage'.toJS,
        _listener,
      );
    } catch (_) {
      // No window (or blocked): behaves like the per-window fallback.
    }
  }

  final void Function(int millis) _onRemoteActivity;
  late final JSFunction _listener;

  JSObject? get _storage {
    try {
      return globalContext.getProperty<JSObject?>('localStorage'.toJS);
    } catch (_) {
      return null; // Storage blocked (private mode, policy): skip syncing.
    }
  }

  void publish(int millis) {
    try {
      _storage?.callMethod<JSAny?>(
        'setItem'.toJS,
        _key.toJS,
        millis.toString().toJS,
      );
    } catch (_) {
      // Quota or blocked storage: this tab still times out on its own.
    }
  }

  void dispose() {
    try {
      globalContext.callMethod<JSAny?>(
        'removeEventListener'.toJS,
        'storage'.toJS,
        _listener,
      );
    } catch (_) {}
  }
}
