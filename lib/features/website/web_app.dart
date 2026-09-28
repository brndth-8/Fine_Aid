import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_portal.dart' deferred as admin_portal;
import 'landing_page.dart';
import 'site_config.dart';

class FineAidWebsite extends StatelessWidget {
  const FineAidWebsite({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fine Aid — Your Smart First Aid Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: LandingColors.red800,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Build only the requested route; Flutter's default would also stack
      // every parent path segment underneath it.
      onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
      onGenerateRoute: _route,
    );
  }

  static Route<void> _route(RouteSettings settings) {
    final path = Uri.parse(settings.name ?? '/').path;
    final Widget page;
    if (path == '/' || path.isEmpty) {
      page = const LandingPage();
    } else if (SiteConfig.isAdminRoute(path)) {
      page = const _AdminLoader();
    } else {
      page = const NotFoundPage();
    }
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
    );
  }
}

/// Downloads the deferred admin bundle and initialises Firebase.
class _AdminLoader extends StatefulWidget {
  const _AdminLoader();

  @override
  State<_AdminLoader> createState() => _AdminLoaderState();
}

class _AdminLoaderState extends State<_AdminLoader> {
  late final Future<void> _ready = admin_portal.loadLibrary().then(
    (_) => admin_portal.initAdmin(),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to load. Please refresh.')),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return admin_portal.buildAdminPortal();
      },
    );
  }
}

/// Generic 404 — deliberately identical for any unknown path so that a
/// guessed admin URL looks no different from any other bad link.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Title(
      title: 'Page not found | Fine Aid',
      color: LandingColors.red800,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '404',
                  style: GoogleFonts.montserrat(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: LandingColors.red800,
                  ),
                ),
                Text(
                  'PAGE NOT FOUND',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: LandingColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "The page you're looking for doesn't exist or has been moved.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: LandingColors.body),
                ),
                const SizedBox(height: 28),
                RedButton(
                  label: 'Back to home',
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (_) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
