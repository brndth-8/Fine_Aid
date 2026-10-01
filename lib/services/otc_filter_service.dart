import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api/gemini_service.dart' show OtcSuggestion, OtcSuggestionCategory;

class _AllowlistCategory {
  final List<String> keywords;
  final OtcSuggestionCategory type;
  const _AllowlistCategory({required this.keywords, required this.type});
}

/// Validates Gemini's raw OTC suggestions (see gemini_service.dart's
/// OTC PRODUCT SUGGESTIONS / OTC_OPTIONS system-prompt rules, shared by
/// the chat model and both wound-assessment models) before they ever
/// reach the UI. The prompt rules can slip — a model can still return
/// something off-scope — so every suggestion is re-checked here against a
/// denylist and an allowlist loaded from a config file that can be tuned
/// without touching Dart code (assets/config/otc_filter_config.json).
///
/// A suggestion survives only if it matches NO denylist term AND matches
/// at least one allowlist category's keywords. Anything that fails is
/// dropped silently (from the user's point of view) — the caller ends up
/// with a shorter, or empty, list; an empty list means the OTC block
/// doesn't render at all (see OtcSuggestionsBlock).
///
/// The allowlist category a suggestion matches also decides its
/// [OtcSuggestion.category] (product vs supply) in the returned list —
/// the AI is never trusted to self-report this, since the filter already
/// has to classify the suggestion anyway to vet it.
class OtcFilterService {
  OtcFilterService._();
  static final OtcFilterService instance = OtcFilterService._();

  static const String _configAssetPath = 'assets/config/otc_filter_config.json';

  List<String>? _denylistTerms;
  List<_AllowlistCategory>? _allowlistCategories;

  Future<void> _ensureLoaded() async {
    if (_denylistTerms != null && _allowlistCategories != null) return;
    try {
      final raw = await rootBundle.loadString(_configAssetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final denylist =
          (json['denylistTerms'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const <String>[];

      final categories =
          (json['allowlistCategories'] as List?)?.map((c) {
            final map = c as Map<String, dynamic>;
            final keywords = (map['keywords'] as List)
                .map((k) => k.toString().toLowerCase())
                .toList();
            final type = map['type']?.toString() == 'supply'
                ? OtcSuggestionCategory.supply
                : OtcSuggestionCategory.product;
            return _AllowlistCategory(keywords: keywords, type: type);
          }).toList() ??
          const <_AllowlistCategory>[];

      _denylistTerms = denylist;
      _allowlistCategories = categories;
    } catch (e) {
      debugPrint('OtcFilterService config load error: $e');
      // Fail closed — if the config can't be read, treat every suggestion
      // as unverifiable rather than risk showing something off-scope.
      _denylistTerms = const [];
      _allowlistCategories = const [];
    }
  }

  bool _matchesAny(String suggestionLower, List<String> terms) =>
      terms.any((term) => suggestionLower.contains(term));

  /// Filters [rawSuggestions] down to only the ones whose [OtcSuggestion.name]
  /// passes both checks — the name is what identifies the product/category,
  /// so that's what's matched against the denylist/allowlist rather than
  /// the age/allergy/how-to-use details. Never throws — a config load
  /// failure or an empty/malformed list just results in an empty (safe)
  /// output.
  Future<List<OtcSuggestion>> filter(List<OtcSuggestion> rawSuggestions) async {
    if (rawSuggestions.isEmpty) return const [];
    await _ensureLoaded();

    final denylist = _denylistTerms ?? const [];
    final allowlist = _allowlistCategories ?? const [];
    final kept = <OtcSuggestion>[];
    var filteredCount = 0;

    for (final suggestion in rawSuggestions) {
      final lower = suggestion.name.trim().toLowerCase();
      if (lower.isEmpty) continue;

      final denied = _matchesAny(lower, denylist);
      _AllowlistCategory? matchedCategory;
      if (!denied) {
        for (final c in allowlist) {
          if (_matchesAny(lower, c.keywords)) {
            matchedCategory = c;
            break;
          }
        }
      }

      if (matchedCategory != null) {
        kept.add(suggestion.copyWith(category: matchedCategory.type));
      } else {
        filteredCount++;
        // Log that something was removed, and why, without the wording
        // itself or any user context — just enough to improve the
        // denylist/allowlist over time.
        debugPrint(
          'OtcFilterService: removed 1 suggestion '
          '(${denied ? 'denylisted' : 'not in allowlist'})',
        );
      }
    }

    if (filteredCount > 0) {
      debugPrint(
        'OtcFilterService: $filteredCount of ${rawSuggestions.length} suggestion(s) removed',
      );
    }

    return kept;
  }
}
