/// Shares "the admin just did something" between browser tabs. Only the web
/// build can do that (see admin_activity_sync_web.dart); everywhere else this
/// is a no-op, so the idle timer simply works per window.
class AdminActivitySync {
  AdminActivitySync(void Function(int millis) onRemoteActivity);

  void publish(int millis) {}

  void dispose() {}
}
