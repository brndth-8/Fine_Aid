import '../../data/healthcare_facilities.dart';

/// Looks up healthcare facilities from the static, locally bundled
/// directory (see `lib/data/healthcare_facilities.dart`) — no maps, no
/// location permission, no network call. Works fully offline.
class NearbyHealthcareService {
  static final NearbyHealthcareService _instance =
      NearbyHealthcareService._internal();
  factory NearbyHealthcareService() => _instance;
  NearbyHealthcareService._internal();

  List<HealthcareFacility> all() => kHealthcareFacilities;

  List<String> categories() =>
      kHealthcareFacilities.map((f) => f.category).toSet().toList();

  /// Case-insensitive search over name, category, and address.
  List<HealthcareFacility> search(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return kHealthcareFacilities.where((f) {
      final matchesCategory = category == null || f.category == category;
      if (!matchesCategory) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          f.address.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q);
    }).toList();
  }
}
