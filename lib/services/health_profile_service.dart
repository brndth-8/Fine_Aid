import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Caches the current user's onboarding Health Profile (diabetes,
/// hemophilia/blood disorders, severe allergies) in memory for the
/// session, so both AI Camera and First Aid Kit can surface
/// condition-relevant cautions without each doing its own Firestore read.
class HealthProfileService {
  static final HealthProfileService _instance =
      HealthProfileService._internal();
  factory HealthProfileService() => _instance;
  HealthProfileService._internal();

  Map<String, dynamic>? _cached;
  String? _cachedForUid;

  Future<Map<String, dynamic>?> getHealthProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (_cachedForUid == user.uid && _cached != null) return _cached;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      _cached = doc.data()?['healthProfile'] as Map<String, dynamic>?;
      _cachedForUid = user.uid;
      return _cached;
    } catch (_) {
      return null;
    }
  }
}
