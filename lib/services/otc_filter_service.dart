import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Validates Gemini's raw "OTC:" suggestions (see gemini_service.dart's
/// OTC PRODUCT SUGGESTIONS system-prompt rule) before they ever reach the
/// UI. The prompt rules can slip — a model can still return something
/// off-scope — so every suggestion is re-checked here against a denylist
/// and an allowlist loaded from a config file that can be tuned without
/// touching Dart code (assets/config/otc_filter_config.json).
///
/// A suggestion survives only if it matches NO denylist term AND matches
/// at least one allowlist category's keywords. Anything that fails is
/// dropped silently (from the user's point of view) — the caller ends up
/// with a shorter, or empty, list; an empty list means the OTC block
/// doesn't render at all (see OtcSuggestionsBlock).
class OtcFilterService {
  OtcFilterService._();
  static final OtcFilterService instance = OtcFilterService._();

  static const String _configAssetPath =
      'assets/config/otc_filter_config.json';

  List<String>? _denylistTerms;
  List<List<String>>? _allowlistCategoryKeywords;

  Future<void> _ensureLoaded() async {
    if (_denylistTerms != null && _allowlistCategoryKeywords != null) return;
    try {
      final raw = await rootBundle.loadString(_configAssetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final denylist = (json['denylistTerms'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const <String>[];

      final categories = (json['allowlistCategories'] as List?)
              ?.map(
                (c) => ((c as Map<String, dynamic>)['keywords'] as List)
                    .map((k) => k.toString().toLowerCase())
                    .toList(),
              )
              .toList() ??
          const <List<String>>[];

      _denylistTerms = denylist;
      _allowlistCategoryKeywords = categories;
    } catch (e) {
      debugPrint('OtcFilterService config load error: $e');
      // Fail closed — if the config can't be read, treat every suggestion
      // as unverifiable rather than risk showing something off-scope.
      _denylistTerms = const [];
      _allowlistCategoryKeywords = const [];
    }
  }

  bool _matchesAny(String suggestionLower, List<String> terms) =>
      terms.any((term) => suggestionLower.contains(term));

  /// Filters [rawSuggestions] down to only the ones that pass both checks.
  /// Never throws — a config load failure or an empty/malformed list just
  /// results in an empty (safe) output.
  Future<List<String>> filter(List<String> rawSuggestions) async {
    if (rawSuggestions.isEmpty) return const [];
    await _ensureLoaded();

    final denylist = _denylistTerms ?? const [];
    final allowlist = _allowlistCategoryKeywords ?? const [];
    final kept = <String>[];
    var filteredCount = 0;

    for (final suggestion in rawSuggestions) {
      final trimmed = suggestion.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      final denied = _matchesAny(lower, denylist);
      final allowed = allowlist.any(
        (keywords) => _matchesAny(lower, keywords),
      );

      if (!denied && allowed) {
        kept.add(trimmed);
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
      debugPrint('OtcFilterService: $filteredCount of ${rawSuggestions.length} suggestion(s) removed');
    }

    return kept;
  }
}
