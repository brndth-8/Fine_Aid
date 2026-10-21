import 'package:flutter/material.dart';

// A single app-wide navigator key, set on MaterialApp in main.dart. Lets
// code with no BuildContext of its own — notably NotificationService,
// responding to a tap that may arrive while no screen is currently
// visible — push a route directly.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// After a sign-out: drops EVERY screen from the navigation stack and starts
/// again from the app's root (AuthGate), which shows the login screen for a
/// signed-out user. Unlike popping back to "the first route", this also works
/// when the dashboard itself is the first route (eg right after onboarding),
/// where the old way left the user sitting on the dashboard in guest mode. Back
/// can't return to any signed-in screen.
void resetToLogin(NavigatorState navigator) {
  navigator.pushNamedAndRemoveUntil('/', (route) => false);
}
