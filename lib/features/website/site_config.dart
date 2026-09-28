/// Site-wide settings for the public website + admin module.
///
/// Nothing here hardcodes the production domain, so the build can be pointed
/// at any domain later (see docs/website_hosting.md).
class SiteConfig {
  SiteConfig._();

  /// Secret admin path segment (no slashes), injected at build time:
  ///   flutter build web -t lib/main_web.dart --dart-define-from-file=config/web.json
  /// Must match the rewrite in firebase.json. When empty, the admin route is
  /// disabled and every non-root path shows the 404 page.
  static const String adminPath = String.fromEnvironment('ADMIN_PATH');

  static bool isAdminRoute(String? routeName) {
    if (adminPath.isEmpty || routeName == null) return false;
    final path = Uri.parse(routeName).path.replaceAll(RegExp(r'/+$'), '');
    return path == '/$adminPath';
  }

  // Contact details shown in the footer.
  static const String address =
      'STI Altaraza Town Center, San Jose Del Monte, Bulacan';
  static const String phoneDisplay = '+63-905-817-1544';
  static final Uri phoneUri = Uri.parse('tel:+639058171544');
  static const String email = 'admin.fineaid@gmail.com';

  /// Opens the visitor's email app with the subject pre-filled.
  static final Uri emailUri = Uri.parse(
    'mailto:$email?subject=${Uri.encodeComponent('Fine Aid Inquiry')}',
  );
}
