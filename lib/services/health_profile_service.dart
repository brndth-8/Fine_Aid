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

  /// Forgets the cached profile, so the next read gets the saved one (call
  /// this after the profile was edited).
  void clear() {
    _cached = null;
    _cachedForUid = null;
  }

  /// The saved medications plus [taken], without repeating one (a name that
  /// differs only in capital letters counts as the same).
  static List<String> mergeMedications(List<String> saved, List<String> taken) {
    final merged = [...saved];
    final seen = {for (final m in saved) m.toLowerCase()};
    for (final raw in taken) {
      final m = raw.trim();
      if (m.isNotEmpty && seen.add(m.toLowerCase())) merged.add(m);
    }
    return merged;
  }

  /// Adds the medications named in an assessment to the Health Profile
  /// (`healthProfile.medications`), keeping the ones already there. Nothing
  /// is written for a guest, or when there is nothing new. Never throws.
  Future<void> addMedications(List<String> taken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || taken.isEmpty) return;
    try {
      final profile = await getHealthProfile();
      final saved = [
        for (final m in (profile?['medications'] as List?) ?? const [])
          if ('$m'.trim().isNotEmpty) '$m'.trim(),
      ];
      final merged = mergeMedications(saved, taken);
      if (merged.length == saved.length) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'healthProfile.medications': merged})
          .timeout(const Duration(seconds: 8));
      clear();
    } catch (_) {
      // The assessment carries on; the medications are still kept on the
      // journal entry.
    }
  }

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
