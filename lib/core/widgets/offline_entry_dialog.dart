import 'package:flutter/material.dart';
import '../../i18n/screen_text_strings.dart';
import '../../services/connectivity_service.dart';

const Color _maroon = Color(0xFF780000);

/// What the person chose in the offline prompt.
enum OfflineChoice {
  /// Carry on into the app in Offline Mode.
  proceed,

  /// The connection came back (after "Try Again"): do what they tapped.
  online,
}

/// The landing page's gate: [onOnline] runs at once when there is internet.
/// Without internet nothing runs yet; the offline prompt (No Internet
/// Connection / Proceed to Offline Mode / Try Again) is shown first.
///  - Proceed to Offline Mode -> [onOffline] (the person enters Offline Mode);
///  - Try Again -> checks again; if the internet is back, [onOnline] runs;
///  - closing the prompt does nothing.
/// [isOnline] can be replaced (tests); a check that fails counts as online, so
/// a broken check can never lock someone out.
Future<void> enterOnlineOrOffline(
  BuildContext context, {
  required VoidCallback onOnline,
  required VoidCallback onOffline,
  Future<bool> Function()? isOnline,
}) async {
  final check = isOnline ?? () => ConnectivityService().isOnline;
  Future<bool> online() async {
    try {
      return await check();
    } catch (_) {
      return true;
    }
  }

  if (await online()) {
    onOnline();
    return;
  }
  if (!context.mounted) return;
  final choice = await showDialog<OfflineChoice>(
    context: context,
    builder: (_) => _OfflineEntryDialog(isOnline: online),
  );
  switch (choice) {
    case OfflineChoice.proceed:
      onOffline();
    case OfflineChoice.online:
      onOnline();
    case null:
      break;
  }
}

class _OfflineEntryDialog extends StatefulWidget {
  const _OfflineEntryDialog({required this.isOnline});

  final Future<bool> Function() isOnline;

  @override
  State<_OfflineEntryDialog> createState() => _OfflineEntryDialogState();
}

class _OfflineEntryDialogState extends State<_OfflineEntryDialog> {
  bool _checking = false;
  bool _stillOffline = false;

  Future<void> _tryAgain() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    final online = await widget.isOnline();
    if (!mounted) return;
    if (online) {
      Navigator.pop(context, OfflineChoice.online);
    } else {
      setState(() {
        _checking = false;
        _stillOffline = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ScreenText.of(context);
    // The landing page is light, so the prompt is too.
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE3E3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 46,
                color: _maroon,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.offlineTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF700509),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.offlineEntryBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
            if (_stillOffline) ...[
              const SizedBox(height: 8),
              Text(
                s.stillOffline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _maroon, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, OfflineChoice.proceed),
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: const StadiumBorder(),
              ),
              child: Text(
                s.proceedOffline,
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _checking ? null : _tryAgain,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(s.tryAgain, style: const TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _maroon, width: 1.5),
                minimumSize: const Size.fromHeight(44),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
