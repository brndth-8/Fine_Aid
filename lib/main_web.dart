import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'features/website/web_app.dart';

/// Web entry point: public landing page at `/`, admin module at the secret
/// path from config/web.json. Build with:
///   flutter build web -t lib/main_web.dart --dart-define-from-file=config/web.json
void main() {
  usePathUrlStrategy();
  runApp(const FineAidWebsite());
}
