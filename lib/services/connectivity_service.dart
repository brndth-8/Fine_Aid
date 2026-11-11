import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// The last answer seen from [isOnline] or [onlineStream] (the app's offline
  /// strip keeps both running), or null before any. Lets a screen know at
  /// once, without waiting on a platform call, whether it opened offline.
  bool? lastKnownOnline;

  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        lastKnownOnline = online;
        return online;
      });

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    lastKnownOnline = online;
    return online;
  }
}
