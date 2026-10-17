// Admin portal settings that more than one screen reads. Change a value here
// and the behaviour and the Security page's status text both follow, so the
// two can't drift apart.

/// How long a signed-in admin can be idle (no click, tap, key press or
/// scroll) before they are signed out automatically.
const Duration kAdminIdleTimeout = Duration(minutes: 15);

/// How long before sign-out the "You will be signed out soon" warning shows.
const Duration kAdminIdleWarning = Duration(minutes: 1);
