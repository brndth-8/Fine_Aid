import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

/// Wraps the whole app so a slim "No internet connection" strip can appear
/// at the top of whatever screen is showing — like Messenger — and
/// disappear automatically the moment connectivity returns, without
/// blocking any interaction underneath it. Mounted once in MyApp's
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.grey.shade800,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
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
