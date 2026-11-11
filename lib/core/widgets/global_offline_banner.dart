import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Wraps the whole app so a slim "No internet connection" strip can appear
/// at the top of whatever screen is showing — like Messenger — and
/// disappear automatically the moment connectivity returns. The screen is
/// moved down under the strip, so nothing on it is covered. Mounted once in MyApp's
/// builder, so it's visible from the very first frame (even on the splash/
/// login/OTP screens), not just once the user reaches the dashboard.
class GlobalOfflineBanner extends StatefulWidget {
  final Widget child;

  const GlobalOfflineBanner({super.key, required this.child});

  @override
  State<GlobalOfflineBanner> createState() => _GlobalOfflineBannerState();
}

class _GlobalOfflineBannerState extends State<GlobalOfflineBanner> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    ConnectivityService().isOnline.then((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    ConnectivityService().onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  /// The height of the strip itself (below the status bar).
  static const double _stripHeight = 28;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final statusBar = media.padding.top;
    // While offline the strip takes the top of the screen (status bar
    // included) and the screens sit under it, so their top bars (back button,
    // search...) are never covered by it.
    final offline = !_isOnline;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              top: offline ? statusBar + _stripHeight : 0,
            ),
            child: MediaQuery(
              data: offline
                  ? media.copyWith(
                      padding: media.padding.copyWith(top: 0),
                      viewPadding: media.viewPadding.copyWith(top: 0),
                    )
                  : media,
              child: widget.child,
            ),
          ),
        ),
        if (offline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.grey.shade800,
              child: Padding(
                padding: EdgeInsets.only(top: statusBar),
                child: const SizedBox(
                  height: _stripHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'No internet connection',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
