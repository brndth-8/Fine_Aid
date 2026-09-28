import 'package:flutter/material.dart';

// A single app-wide navigator key, set on MaterialApp in main.dart. Lets
// code with no BuildContext of its own — notably NotificationService,
// responding to a tap that may arrive while no screen is currently
// visible — push a route directly.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
