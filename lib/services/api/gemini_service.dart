import '../../data/health_context.dart' show healthContextPromptBlock;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_proxy_client.dart';
import '../../core/constants/analysis_lock.dart';
import '../../core/scope_check.dart';
import 'gemini_usage.dart';

/// The fixed, extensible wound/skin-issue taxonomy used across detection,
/// the result screen's category badge, and OTC-suggestion mapping. Add new
/// entries here (and to the OTC query mapping in
/// AssessmentResultScreen._otcQueryForClassification) to extend it.
class WoundCategories {
  WoundCategories._();

  static const String laceration = 'Laceration';
  static const String minorCut = 'Minor Cut';
  static const String scratch = 'Scratch';
  static const String abrasion = 'Abrasion';
  static const String punctureWound = 'Puncture Wound';
  static const String burn = 'Burn';
  static const String bruise = 'Bruise';
  static const String swelling = 'Swelling';
  static const String rash = 'Rash';
  static const String otherSkinIssue = 'Other Skin Issue';
  static const String unableToClassify = 'Unable to Classify';

  static const List<String> all = [
    laceration,
    minorCut,
    scratch,
    abrasion,
    punctureWound,
    burn,
    bruise,
    swelling,
    rash,
    otherSkinIssue,
    unableToClassify,
  ];
}

/// How confident the pre-check detection is that what it found is a real,
/// assessable wound/skin issue — the input to the "Free Pass Filter" gate
/// that decides whether it's safe to proceed to full analysis.
enum DetectionConfidence { high, medium, low }

/// Whether the detected mark looks like it could be something other than a
/// genuine skin injury — a pen/marker line, drawn mark, makeup, temporary
/// marking, drawing, shadow, clothing pattern, hair strand, or similar
/// artifact — rather than real skin trauma. (A screenshot, or a photo of a
/// screen, that shows a real wound or scar is NOT an artifact.)
enum ArtificialMarkLikelihood { no, unsure, yes }

/// The three-state outcome of the Free Pass Filter (see [WoundDetectionResult.freePassResult]).
enum FreePassResult {
  /// Sufficient evidence of a genuine wound/skin issue — safe to continue
  /// to classification and recommendations.
  pass,

  /// An obvious non-wound/invalid result (blurry, nothing detected, or a
  /// mark that looks artificial) — stop and ask for a retake/new image.
  fail,

  /// Can't confidently tell either way — don't force a category or
  /// guidance; ask for a clearer photo instead of guessing.
  uncertain,
}

/// Central "Free Pass Filter" threshold: the minimum detection confidence
/// required to proceed past pre-check into full wound analysis. Lower this
/// to `DetectionConfidence.low` to let more borderline images through, or
/// raise it to `DetectionConfidence.high` to be stricter.
const DetectionConfidence kFreePassMinConfidence = DetectionConfidence.medium;

class WoundDetectionResult {
  final bool isBlurry;
  final bool hasWound;
  final int woundCount;
  final List<String> woundDescriptions;
  final DetectionConfidence confidence;
  final ArtificialMarkLikelihood artificialMarkLikelihood;

  /// Other reasons the photo cannot be used: too dark (or washed out), the
  /// affected area cropped or too far away, no skin recognisable in it, or a
  /// fake picture (a drawing, illustration, cartoon, render or AI-made image
  /// that is not a real wound or scar). Screenshots and photos of a screen
  /// that show a real wound or scar are accepted.
  final bool isTooDark;
  final bool isCropped;
  final bool isUnrecognizable;
  final bool looksFake;

  /// The check itself could not be completed (no reply, an error, or a reply
  /// that could not be read). The photo is then NOT let through.
  final bool checkFailed;

  /// Normalized (0-1) bounding box per wound, in the same order as
  /// [woundDescriptions]. An entry is null if the model didn't return a
  /// usable box for that wound, so the UI can fall back to a generated
  /// position for just that one wound.
  final List<Rect?> woundBoxes;

  WoundDetectionResult({
    required this.isBlurry,
    required this.hasWound,
    required this.woundCount,
    required this.woundDescriptions,
    this.confidence = DetectionConfidence.medium,
    this.artificialMarkLikelihood = ArtificialMarkLikelihood.no,
    this.isTooDark = false,
    this.isCropped = false,
    this.isUnrecognizable = false,
    this.looksFake = false,
    this.checkFailed = false,
    this.woundBoxes = const [],
  });

  /// Blurry, too dark, cropped or unrecognisable: "the image is unclear".
  bool get isUnclear => isBlurry || isTooDark || isCropped || isUnrecognizable;

  /// The "Free Pass Filter": a three-state judgment on whether it's safe
  /// to proceed to wound classification and first-aid recommendations,
  /// rather than risking misleading guidance from an unclear photo, an
  /// artificial mark (pen line, drawing, makeup, etc.), or
  /// something that just isn't a wound at all.
  FreePassResult get freePassResult {
    if (checkFailed || isUnclear || looksFake) return FreePassResult.fail;
    if (!hasWound || woundCount == 0) return FreePassResult.fail;
    if (artificialMarkLikelihood == ArtificialMarkLikelihood.yes) {
      return FreePassResult.fail;
    }
    if (confidence.index > kFreePassMinConfidence.index ||
        artificialMarkLikelihood == ArtificialMarkLikelihood.unsure) {
      return FreePassResult.uncertain;
    }
    return FreePassResult.pass;
  }

  /// Convenience boolean for callers that only care about pass/no-pass.
  bool get passesFreePassFilter => freePassResult == FreePassResult.pass;
}

/// The English/Tagalog split of a chat reply formatted per the "EN:" /
/// "TL:" convention enforced by the chat model's system instruction.
class BilingualReply {
  final String english;
  final String? tagalog;

  /// Whether the chat model flagged this reply as a good moment to offer
  /// the "Find Nearby Healthcare" option (the user asked where to go, or
  /// the reply recommended seeking professional/emergency care).
  final bool suggestNearby;

  /// Whether the model judged this reply itself to indicate a severe /
  /// seek-care-ASAP situation. Driven by an explicit structured field the
  /// model sets, not by scanning the reply text for keywords client-side
  /// — the app renders this distinctly (bold, highlighted) when true.
  final bool isUrgent;

  /// Raw OTC product suggestions from the model's "OTC:" field, exactly as
  /// it wrote them — NOT yet checked against the denylist/allowlist. Every
  /// caller must run these through the OTC filter (otc_filter_service.dart)
  /// before showing them, per the OTC PRODUCT SUGGESTIONS system-prompt
  /// rule.
  final List<OtcSuggestion> otcSuggestions;

  const BilingualReply({
    required this.english,
    this.tagalog,
    this.suggestNearby = false,
    this.isUrgent = false,
    this.otcSuggestions = const [],
  });
}

/// Parses a chat response into its English/Tagalog parts, the nearby-
/// healthcare/urgency flags, and any raw OTC suggestions. Falls back to
/// showing the raw text as-is if the model didn't follow the "EN:" / "TL:"
/// / "NEARBY:" / "SEVERITY:" / "OTC:" format (eg, a short redirect
/// message).
BilingualReply parseBilingualReply(String raw) {
  final enMatch = RegExp(
    r'EN:\s*(.*?)(?=\n *TL:|$)',
    dotAll: true,
  ).firstMatch(raw);
  final tlMatch = RegExp(
    r'TL:\s*(.*?)(?=\n *NEARBY:|$)',
    dotAll: true,
  ).firstMatch(raw);
  final nearbyMatch = RegExp(
    r'NEARBY:\s*(yes|no)',
    caseSensitive: false,
  ).firstMatch(raw);
  final severityMatch = RegExp(
    r'SEVERITY:\s*(normal|urgent)',
    caseSensitive: false,
  ).firstMatch(raw);
  final otcMatch = RegExp(r'OTC:\s*(.*)').firstMatch(raw);

  final en = enMatch?.group(1)?.trim();
  final tl = tlMatch?.group(1)?.trim();
  final suggestNearby = nearbyMatch?.group(1)?.toLowerCase() == 'yes';
  final isUrgent = severityMatch?.group(1)?.toLowerCase() == 'urgent';
  final otcSuggestions = _parseRawOtcField(otcMatch?.group(1));

  if (en == null || en.isEmpty) {
    return BilingualReply(
      english: raw.trim(),
      suggestNearby: suggestNearby,
      isUrgent: isUrgent,
      otcSuggestions: otcSuggestions,
    );
  }
  return BilingualReply(
    english: en,
    tagalog: (tl != null && tl.isNotEmpty) ? tl : null,
    suggestNearby: suggestNearby,
    isUrgent: isUrgent,
    otcSuggestions: otcSuggestions,
  );
}

/// Whether an [OtcSuggestion] is a medicine/product (antiseptic, pain
/// reliever, etc) or a supply (dressing, gloves) — determined by
/// OtcFilterService from which allowlist category the suggestion matched,
/// not by the AI itself, so it's consistent regardless of model wording.
/// Defaults to [product] until a suggestion has actually been through the
/// filter.
enum OtcSuggestionCategory { product, supply }

/// One structured OTC suggestion, shared by every AI entry point (chat
/// follow-ups and the initial wound assessment) so they can never drift
/// apart in shape or wording. Deliberately limited to just these fields
/// per the OTC PRODUCT SUGGESTIONS format — no manufacturer/brand-company
/// field, ingredients list, price, or long description.
class OtcSuggestion {
  final String name; // generic name only
  final String ageLimit;
  final String allergyPrecaution;
  final String howToUse;
  final OtcSuggestionCategory category;

  const OtcSuggestion({
    required this.name,
    required this.ageLimit,
    required this.allergyPrecaution,
    required this.howToUse,
    this.category = OtcSuggestionCategory.product,
  });

  OtcSuggestion copyWith({OtcSuggestionCategory? category}) => OtcSuggestion(
    name: name,
    ageLimit: ageLimit,
    allergyPrecaution: allergyPrecaution,
    howToUse: howToUse,
    category: category ?? this.category,
  );
}

/// The substantive OTC-suggestion content rules — naming format, the
/// three allowed detail fields, scope/safety limits — shared verbatim by
/// the chat model AND both wound-assessment models below, so the format
/// and wording can never drift apart between AI entry points. Each model
/// wraps this with its own wire-format instructions (the chat's "OTC:"
/// line vs the assessment schemas' `otc_options` JSON array).
const String _otcContentRules =
    '- GENERIC NAMES ONLY: always use the generic name or active '
    'ingredient (e.g. \'Povidone-iodine\', \'Paracetamol\', '
    '\'Bacitracin ointment\'). NEVER write a brand name — not on its '
    'own and not in parentheses — and never name which company '
    'manufactures a product. A user can pick whichever brand of that '
    'generic product fits their budget. This applies to every '
    'suggestion — antiseptics, pain relievers, ointments, dressings, '
    'gloves, everything.\n'
    '- PER-SUGGESTION DETAILS: keep every suggestion concise. Give '
    'exactly three short details and nothing more — no ingredients '
    'list, price, manufacturer, or long description:\n'
    '  - Age limit: the minimum age it\'s safe for (e.g. "Adults and '
    'children 12 years and above"). If it\'s not safe for young '
    'children, say so plainly.\n'
    '  - Allergy precaution: the one key precaution — the main group '
    'who should avoid it or be careful, in one short phrase (e.g. '
    '"Do not use if allergic to iodine").\n'
    '  - How to use: begin with what it is for in a few words (e.g. '
    '"Antiseptic for minor cuts."), then how to apply or take it — '
    'the amount, how often, and the route (apply on skin, take by '
    'mouth, etc).\n'
    'For a supply (dressing, bandage, gloves) rather than a '
    'medicine, still give all three: age limit is usually "All '
    'ages" or "Adults and children", allergy precaution is "None '
    'known" unless something like latex applies, and how to use '
    'briefly says when/how to use it (e.g. "Wear before touching '
    'the wound to avoid contamination").\n'
    '- Where relevant, also suggest supplies in the same generic '
    'style — which type of dressing or bandage fits the wound (eg, '
    'sterile gauze pad, adhesive bandage, non-stick dressing) and '
    'whether gloves are needed before touching the wound (eg, '
    'disposable gloves).\n'
    '- Only suggest products/supplies for minor injuries. For '
    'severe, deep, infected-looking, or high-risk wounds, prioritize '
    'seeking medical care and never present these as a substitute.\n'
    '- Don\'t invent specific doses beyond what\'s on a typical '
    'package label. Fold a pregnancy/existing-medication caution '
    'into the allergy precaution detail when relevant, and suggest '
    'checking with a pharmacist or doctor if unsure.\n'
    '- Never recommend prescription drugs.\n'
    '- Keep it short: 1-3 suggestions, phrased as \'you may '
    'consider...\', not as a diagnosis or prescription.\n'
    '- Users are in the Philippines, so prefer products commonly '
    'available in local pharmacies, and give the Tagalog product/'
    'ingredient name if the user\'s language is Tagalog.\n'
    '- RELEVANCE: Only suggest products designed and labeled for '
    'treating wounds, skin injuries, or their symptoms (pain, '
    'swelling, itching, infection prevention). Never suggest products '
    'for unrelated body areas or purposes, even if the brand is '
    'similar to a wound-care product.\n'
    '- Explicitly exclude feminine washes and intimate hygiene '
    'products (including feminine washes of any brand), mouthwashes, '
    'throat gargles or sprays, shampoos, body or facial washes, '
    'cosmetics, deodorants, and unrelated supplements or vitamins.\n'
    '- If a generic ingredient comes in several forms, recommend only '
    'the wound-appropriate form (e.g. \'Povidone-iodine antiseptic '
    'solution\' for minor cuts, not a form meant for a different '
    'purpose).\n'
    '- If no relevant product or supply fits, suggest none.';

// Splits the model's "OTC: Name (Brand) :: Age :: Allergy :: HowTo || ..."
// (or "OTC: none") field into structured suggestions. Never throws on
// malformed input — a suggestion missing some fields just shows blank
// details rather than being dropped, and an entry with no name at all is
// skipped; worst case overall is an empty list, which just hides the block.
List<OtcSuggestion> _parseRawOtcField(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'none') {
    return const [];
  }
  return trimmed
      .split('||')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && item.toLowerCase() != 'none')
      .map(_parseOtcSuggestionItem)
      .whereType<OtcSuggestion>()
      .toList();
}

OtcSuggestion? _parseOtcSuggestionItem(String item) {
  final parts = item.split('::').map((p) => p.trim()).toList();
  final name = parts.isNotEmpty ? parts[0] : '';
  if (name.isEmpty) return null;
  return OtcSuggestion(
    name: name,
    ageLimit: parts.length > 1 ? parts[1] : '',
    allergyPrecaution: parts.length > 2 ? parts[2] : '',
    howToUse: parts.length > 3 ? parts[3] : '',
  );
}

/// Triage urgency from the v2 wound-assessment schema.
enum TriageLevel { selfCare, firstAid, urgentCare, emergency, unknown }

TriageLevel _parseTriage(String? raw) {
  switch ((raw ?? '').toUpperCase().trim()) {
    case 'SELF_CARE':
      return TriageLevel.selfCare;
    case 'FIRST_AID':
      return TriageLevel.firstAid;
    case 'URGENT_CARE':
      return TriageLevel.urgentCare;
    case 'EMERGENCY':
      return TriageLevel.emergency;
    default:
      return TriageLevel.unknown;
  }
}

/// Maps the v2 schema's free-form `wound_type` string onto the app's fixed
/// [WoundCategories] taxonomy, so category display, OTC mapping, and the
/// Health Journal's healing-timeframe lookup all stay consistent.
String mapWoundTypeToCategory(String woundType) {
  switch (woundType.toLowerCase().trim()) {
    case 'laceration':
      return WoundCategories.laceration;
    case 'cut':
    case 'minor_cut':
    case 'incision':
      return WoundCategories.minorCut;
    case 'scratch':
      return WoundCategories.scratch;
    case 'abrasion':
    case 'scrape':
      return WoundCategories.abrasion;
    case 'puncture':
      return WoundCategories.punctureWound;
    case 'burn':
      return WoundCategories.burn;
    case 'bruise':
    case 'contusion':
      return WoundCategories.bruise;
    case 'swelling':
    case 'edema':
      return WoundCategories.swelling;
    case 'rash':
      return WoundCategories.rash;
    case 'none':
      return WoundCategories.unableToClassify;
    default:
      return WoundCategories.otherSkinIssue;
  }
}

/// Structured result of the v2 JSON wound-assessment schema.
class WoundAssessment {
  final bool isWound;
  final double confidence;
  final String woundType;
  final String visibleBleeding;
  final String apparentDepth;
  final bool foreignObjectVisible;
  final bool infectionSignsVisible;
  final TriageLevel triage;
  final List<String> redFlags;
  final List<String> firstAidSteps;
  final List<OtcSuggestion> otcOptions;
  final bool needsProfessionalEvaluation;
  final List<String> uncertainties;

  /// Tagalog versions of [firstAidSteps] and [uncertainties] (same order and
  /// count), only when the request asked for Tagalog; empty otherwise.
  final List<String> firstAidStepsTl;
  final List<String> uncertaintiesTl;
  final String? error;
  // Only ever set for an injury that came from the multi-injury schema
  // (eg "left knee", "right forearm") — null for the single-wound path,
  // where there's nothing to disambiguate.
  final String? location;

  const WoundAssessment({
    required this.isWound,
    required this.confidence,
    required this.woundType,
    required this.visibleBleeding,
    required this.apparentDepth,
    required this.foreignObjectVisible,
    required this.infectionSignsVisible,
    required this.triage,
    required this.redFlags,
    required this.firstAidSteps,
    required this.otcOptions,
    required this.needsProfessionalEvaluation,
    required this.uncertainties,
    this.firstAidStepsTl = const [],
    this.uncertaintiesTl = const [],
    this.error,
    this.location,
  });

  factory WoundAssessment.errorFallback(String message) => WoundAssessment(
    isWound: false,
    confidence: 0.0,
    woundType: 'none',
    visibleBleeding: 'none',
    apparentDepth: 'unknown',
    foreignObjectVisible: false,
    infectionSignsVisible: false,
    triage: TriageLevel.unknown,
    redFlags: const [],
    firstAidSteps: const [],
    otcOptions: const [],
    needsProfessionalEvaluation: true,
    uncertainties: const ['The assessment could not be completed.'],
    error: message,
  );

  String get category => mapWoundTypeToCategory(woundType);
}

List<String> _stringList(dynamic value) =>
    (value as List?)?.map((e) => e.toString()).toList() ?? const [];

/// Parses the wound-assessment schema's `otc_options` array (objects with
/// name/age_limit/allergy_precaution/how_to_use) into [OtcSuggestion]s —
/// the same shared model the chat's OTC field parses into, so both places
/// render through the same widget. Defensive against drift and against
/// old cached/malformed data: a plain string entry (the pre-this-change
/// shape) is kept as a name-only suggestion rather than dropped or
/// crashing, a non-string/non-map entry is skipped, and a map missing
/// some fields just leaves those fields blank (the UI hides a blank
/// detail row rather than showing "null").
List<OtcSuggestion> _parseOtcOptionsFromJson(dynamic value) {
  if (value is! List) return const [];
  final result = <OtcSuggestion>[];
  for (final entry in value) {
    if (entry is Map) {
      final name = entry['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      result.add(
        OtcSuggestion(
          name: name,
          ageLimit: entry['age_limit']?.toString().trim() ?? '',
          allergyPrecaution:
              entry['allergy_precaution']?.toString().trim() ?? '',
          howToUse: entry['how_to_use']?.toString().trim() ?? '',
        ),
      );
    } else if (entry is String) {
      final name = entry.trim();
      if (name.isEmpty || name.toLowerCase() == 'none') continue;
      result.add(
        OtcSuggestion(
          name: name,
          ageLimit: '',
          allergyPrecaution: '',
          howToUse: '',
        ),
      );
    }
  }
  return result;
}

/// Shared by both the single-wound and multi-injury schemas — every field
/// below is identical between "one JSON object" and "one entry in the
/// injuries array", so both parsers build a [WoundAssessment] the same way.
WoundAssessment _woundAssessmentFromMap(Map<String, dynamic> map) {
  return WoundAssessment(
    isWound: map['is_wound'] == true,
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    woundType: map['wound_type']?.toString() ?? 'none',
    visibleBleeding: map['visible_bleeding']?.toString() ?? 'none',
    apparentDepth: map['apparent_depth']?.toString() ?? 'unknown',
    foreignObjectVisible: map['foreign_object_visible'] == true,
    infectionSignsVisible: map['infection_signs_visible'] == true,
    triage: _parseTriage(map['triage']?.toString()),
    redFlags: _stringList(map['red_flags']),
    firstAidSteps: _stringList(map['first_aid_steps']),
    otcOptions: _parseOtcOptionsFromJson(map['otc_options']),
    needsProfessionalEvaluation: map['needs_professional_evaluation'] == true,
    uncertainties: _stringList(map['uncertainties']),
    firstAidStepsTl: _stringList(map['first_aid_steps_tl']),
    uncertaintiesTl: _stringList(map['uncertainties_tl']),
    error: map['error']?.toString(),
    location: map['location']?.toString(),
  );
}

/// Strips markdown code fences in case the model adds them despite
/// instructions not to — shared by both the single and multi-injury
/// response parsers.
String _stripCodeFences(String raw) {
  var cleaned = raw.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').trim();
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }
  }
  return cleaned;
}

/// The part of the assessment request that passes the app's language on: for
/// Tagalog, a request for the Tagalog steps and unclear details next to the
/// English ones; nothing for English.
String assessmentLanguageBlock({required bool tagalog}) => tagalog
    ? 'LANGUAGE: the person reads Tagalog. Keep every field of the '
          'schema exactly as specified, in English. In addition, add '
          'these two keys: "first_aid_steps_tl": the same '
          'first_aid_steps in plain, simple Tagalog, with the same '
          'number of items in the same order, each written "Before: '
          '<hakbang> — <dahilan>", "During: <hakbang> — <dahilan>" or '
          '"After: <hakbang> — <dahilan>" (keep the English words '
          'Before, During and After as the label, and the spaced em '
          'dash); and "uncertainties_tl": the same uncertainties in '
          'Tagalog. Do not change the meaning or add medical facts.\n\n'
    : '';

/// Parses the v2 assessment model's JSON response. Falls back to an
/// uncertain/error result rather than crashing if the response isn't valid
/// JSON — never silently invent a wound assessment from unparseable output.
WoundAssessment parseWoundAssessment(String raw) {
  try {
    final map = jsonDecode(_stripCodeFences(raw)) as Map<String, dynamic>;
    return _woundAssessmentFromMap(map);
  } catch (e) {
    debugPrint('parseWoundAssessment error: $e — raw: $raw');
    return WoundAssessment.errorFallback(e.toString());
  }
}

/// Structured result of the multi-injury JSON schema: every injury the
/// model found in the photo, each parsed the same way as the single-wound
/// schema, plus a combined treat-first-to-last ordering.
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _chatModel;
  ChatSession? _chatSession;

  GenerativeModel _createDetectionModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: geminiProxyApiKey,
      httpClient: geminiProxyClient,
      // 512 can cut the reply off once several wounds (each with a
      // description and a box line) are listed — the same failure that cut
      // off the assessment reply — so later wounds would silently vanish.
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 2048,
      ),
      systemInstruction: Content.system(
        'You are the image validation and pre-check step for Fine Aid, a '
        'first aid app. Your job is NOT to just spot something that looks '
        'wound-shaped — it is to judge whether there is genuine evidence '
        'of a real skin injury or skin condition, so the app can decide '
        'whether it is safe to proceed to give first aid advice.\n\n'
        'BE CONSERVATIVE. Before anything else, actively consider whether '
        'the mark you are looking at could be something OTHER than a real '
        'skin injury, such as: a pen or marker line drawn on skin, a '
        'drawn-on scratch, makeup or a temporary/decorative marking, a '
        'drawing, illustration, cartoon or computer-rendered picture, a '
        'shadow or lighting artifact, a fold or pattern in clothing, a '
        'strand of hair, a tattoo, or dirt/stain. Genuine skin injuries usually '
        'show irregular (not perfectly straight or geometric) edges, '
        'color variation consistent with a real tissue response (eg, '
        'redness, bruising tones, scabbing), some texture disruption of '
        'the skin surface, and often visible surrounding skin reaction '
        '(redness, swelling). A uniform-width, perfectly straight or '
        'suspiciously clean line with no surrounding skin reaction is a '
        'strong signal of an artificial mark, not a real wound — do not '
        'call that a scratch or any other wound type just because it is '
        'a mark on skin. If you are not genuinely convinced this is real '
        'skin trauma or a real skin condition, say so honestly rather '
        'than guessing — it is much better to ask the user for a clearer '
        'photo than to confidently mislabel a pen mark as an injury.\n\n'
        'ACCEPTED IMAGES: a live camera photo, a screenshot of an image, or '
        'a photo taken of another screen (phone, monitor, TV) is VALID as '
        'long as it shows a real wound or scar on real skin. Never reject an '
        'image only because it is a screenshot or a photo of a screen — judge '
        'only whether it depicts a real wound or scar on real skin. Scars '
        '(superficial wounds, healed or old scars) are valid subjects.\n\n'
        'Answer ONLY in this exact plain-text format, one field per line, '
        'no extra commentary, no markdown:\n'
        'BLURRY: yes or no — yes only if the photo is so out of focus or '
        'shaky that a wound could not be assessed from it\n'
        'TOO_DARK: yes or no — yes only if the photo is so dark (or so '
        'over-exposed) that the skin cannot be made out\n'
        'CROPPED: yes or no — yes if the affected area is cut off by the '
        'edge of the photo, or is so small or far away that it cannot be '
        'assessed\n'
        'UNRECOGNIZABLE: yes or no — yes if the photo does not clearly show '
        'human skin or a body part (an object, a wall, a room, a pet, '
        'anything that is not a person\'s skin)\n'
        'FAKE_IMAGE: yes or no — yes only if the picture is a drawing, '
        'illustration, cartoon, 3D or computer render, or an AI-generated '
        'or fabricated image, rather than a depiction of a real wound or '
        'scar on real skin. A screenshot or a photo of a screen that shows '
        'a real wound or scar is NOT fake: answer no\n'
        'WOUND_DETECTED: yes or no — yes only if you see genuine evidence '
        'of a real wound, injury, burn, bite, rash, scar, or other actual '
        'skin condition (not just any mark on skin)\n'
        'ARTIFICIAL_MARK_LIKELY: yes, no, or unsure — yes if the mark '
        'looks like a pen/marker line, drawn mark, makeup, temporary '
        'marking, drawing, shadow, clothing pattern, '
        'hair strand, or other non-injury artifact rather than genuine '
        'skin trauma; unsure if you cannot tell either way; no only if '
        'you see clear evidence this is genuine skin trauma or a real '
        'skin condition (irregular edges, real tissue color/texture, '
        'surrounding skin reaction)\n'
        'CONFIDENCE: high, medium, or low — how confident you are that '
        'this image shows a real, clearly assessable wound or skin issue '
        '(not just BLURRY — also low if the image is ambiguous, the area '
        'is too small/far away, lighting is very poor, or it\'s genuinely '
        'unclear whether this is a wound at all)\n'
        'WOUND_COUNT: a single integer — how many separate, distinct '
        'wounds or skin-condition areas are visible (0 if none, 1 if just '
        'one; 0 if WOUND_DETECTED is no)\n'
        'WOUND_1: a short 5-10 word description of the first wound '
        '(omit this line entirely if WOUND_COUNT is 0)\n'
        'WOUND_1_BOX: the bounding box tightly around the first wound, as '
        'four integers ymin,xmin,ymax,xmax on a 0-1000 scale where '
        '(0,0) is the top-left corner of the image and (1000,1000) is '
        'the bottom-right corner\n'
        'WOUND_2: same as WOUND_1 for the second wound if there is one, '
        'and so on (WOUND_3, WOUND_4, ...) for each additional wound\n'
        'WOUND_2_BOX: same as WOUND_1_BOX for the second wound, and so on '
        '(WOUND_3_BOX, WOUND_4_BOX, ...) for each additional wound — every '
        'WOUND_n line must have a matching WOUND_n_BOX line\n'
        'Do not diagnose or give care advice here — this step only judges '
        'whether there is real evidence of a wound and, if so, roughly '
        'where each one is, so the app can route to the right screen and '
        'let the user tap the correct wound on the photo.',
      ),
    );
  }

  GenerativeModel _createChatModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: geminiProxyApiKey,
      httpClient: geminiProxyClient,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 2048,
      ),
      systemInstruction: Content.system(
        'You are a medical first aid assistant for Fine Aid, a Filipino '
        'first aid app. Every user message begins with a REFERENCE '
        'MATERIALS block (excerpts retrieved from trusted first aid, '
        'wound-care, skin condition, and OTC medicine reference books), '
        'optionally followed by a CURRENT WOUND ANALYSIS block (the '
        'app\'s own AI-generated assessment of the specific wound the '
        'user is currently asking about, including the detected category '
        'and first aid steps already given), followed by the actual USER '
        'QUESTION. The chat history itself already contains the prior '
        'turns of this conversation — treat later questions as continuing '
        'the same conversation about the same wound unless the user '
        'clearly changes topic.\n\n'
        'A message may also contain a USER HEALTH PROFILE block: facts the '
        'user already saved in the app (health conditions, allergies, '
        'medicines, and their latest journal entries). Rules for it: use '
        'ONLY what is written there, never invent or assume anything '
        'about the user; use it to tailor an in-scope wound, injury or '
        'skin answer (eg slower healing, infection risk, a medicine that '
        'conflicts); it does NOT widen the SCOPE CHECK below. When the '
        'question could be connected to something in that block (eg a '
        'deficiency, condition or allergy), politely ask ONE short '
        'clarifying question in your answer, such as: "I noticed an iron '
        'deficiency in your health profile. Is your question related to '
        'that?" - and still answer what you safely can. Ask it once in a '
        'conversation, not on every message. If there is no such block, '
        'behave as normal. The medical disclaimer and professional-'
        'consultation advice stay exactly as described below.\n\n'
        'Follow this response priority order for every message:\n'
        '1. SCOPE CHECK — is this actually about a first aid/health '
        'concern (see below)?\n'
        '2. Read the CURRENT WOUND ANALYSIS (if present) and prior chat '
        'turns as your primary context for what the user means.\n'
        '3. SAFETY / RED-FLAG CHECK — does the question describe or ask '
        'about something concerning (see red-flag list below)?\n'
        '4. Give a direct answer to what was actually asked.\n'
        '5. Add a professional-consultation recommendation if warranted.\n'
        '6. Only if the user is asking where to go, or you just '
        'recommended care and it fits naturally, offer to help find '
        'nearby healthcare.\n\n'
        'STEP 1 — SCOPE CHECK:\n'
        'Fine Aid only answers questions about: wounds (cuts, scrapes, '
        'punctures, burns, bites, etc.), minor injuries (sprains, '
        'bruises, minor swelling, etc.), and skin conditions (rashes, '
        'itching, acne, fungal infections, etc.) — including a question '
        'about an OTC medicine for one of these. Everything else is out '
        'of scope, EVEN IF it sounds like a general medical question — '
        'eg dry or wet cough, colds/flu, fever with no wound or skin '
        'cause, chronic illnesses (diabetes, hypertension, asthma, etc.), '
        'stomach or digestive problems, headaches, mental health, or any '
        'other general medical concern.\n'
        'BORDERLINE CASES ARE IN SCOPE: a symptom linked to a wound or '
        'skin problem is in scope even if the symptom alone wouldn\'t be '
        '— eg fever WITH an infected wound, swelling around a bite. If '
        'it\'s genuinely unclear whether something is wound/skin-related, '
        'you may ask ONE short clarifying question about the wound or '
        'skin issue instead of refusing outright.\n'
        'IN-SCOPE examples: "I cut my finger", "is this rash dangerous", '
        '"my wound is swelling", "what if it doesn\'t heal in a week", '
        '"my cut is red and I have a fever", "paano gamutin ang paso".\n'
        'OUT-OF-SCOPE examples: "I have a cough", "I have diabetes, what '
        'should I eat?", small talk or greetings with no health concern '
        'stated, requests unrelated to first aid ("help me with my '
        'homework", "write my essay", "what\'s the weather", "tell me a '
        'joke"), and any general medical question with no stated '
        'connection to a wound, injury, or skin condition.\n'
        'If OUT-OF-SCOPE: reply with ONLY this exact message, translated '
        'to Tagalog for the TL: field, and nothing else — no partial '
        'answer, no OTC suggestion, no follow-up question about the '
        'out-of-scope topic: "$outOfScopeRefusalMessage"\n'
        'This applies per-message: if THIS message is entirely about '
        'something out of scope (eg a follow-up like "also, I have a '
        'cough" after an earlier in-scope wound question), refuse just '
        'this message the same way — the conversation continues '
        'normally on the next in-scope message about the wound. A '
        'refusal is still a normal reply, not an error — still follow '
        'the FORMAT below (EN:/TL:/NEARBY:/SEVERITY:/OTC:), just with '
        '"NEARBY: no", "SEVERITY: normal", "OTC: none", and the refusal '
        'text (and its Tagalog translation) as the EN:/TL: content.\n'
        'If IN-SCOPE: continue.\n\n'
        'STEP 2 — ANSWER DIRECTLY, USING WOUND CONTEXT:\n'
        'Ground your answer in REFERENCE MATERIALS and, when present, the '
        'CURRENT WOUND ANALYSIS and prior conversation — treat the wound '
        'analysis as reliable context about this user\'s specific case '
        '(it was already grounded in trusted reference material). '
        'BE DIRECT AND CONCISE. Answer the actual question first, in 1-3 '
        'short sentences. Do NOT open with disclaimers about what you do '
        'or don\'t have information on ("I do not have specific '
        'information...", "my reference materials do not contain...", "I '
        'cannot determine...") — only say you lack the information if '
        'NEITHER the reference materials NOR the wound analysis NOR '
        'ordinary first aid judgment can answer safely, and even then, '
        'lead with what you CAN say (eg, a professional-consultation '
        'recommendation) rather than the limitation itself. '
        'For a question like "what if it doesn\'t heal in a week" or '
        '"it keeps coming back" or "it\'s getting worse", answer plainly: '
        'recommend seeing a doctor, nurse, or other qualified healthcare '
        'professional for an evaluation if it isn\'t improving as '
        'expected, and mention 1-3 relevant warning signs to seek care '
        'sooner for (eg, worsening pain, spreading redness, swelling, '
        'discharge, fever) — do not pad this with unnecessary hedging.\n\n'
        'RED FLAGS — respond to these with clear, direct safety guidance, '
        'not a mild "you may want to consult someone": heavy or spurting '
        'bleeding that won\'t stop, a deep or gaping wound, rapidly '
        'spreading swelling, signs of a severe allergic reaction '
        '(difficulty breathing, facial/throat swelling), worsening or '
        'severe pain, high fever, or a wound that keeps reopening, '
        'spreading, or shows signs of infection. For anything sounding '
        'like an emergency (severe bleeding that won\'t stop, difficulty '
        'breathing, signs of a severe allergic reaction, a possible '
        'serious injury), tell the user plainly to seek emergency medical '
        'services or go to an emergency department right away — do not '
        'just suggest an ordinary clinic visit for these. For non-'
        'emergency but concerning cases (not healing, recurring, mildly '
        'worsening), recommend consulting a doctor, nurse, or other '
        'qualified healthcare professional for an evaluation.\n\n'
        'OTC PRODUCT SUGGESTIONS: When the user asks a follow-up question '
        'about a wound or injury (including one they photographed), answer '
        'the question first. Then, where relevant, suggest OTC options '
        'that fit their situation, such as antiseptic wash or solution '
        'for minor cuts, antibiotic ointment for minor scrapes, non-stick '
        'sterile dressings or adhesive bandages, burn gel or hydrogel '
        'dressings for minor burns, oral pain relievers for pain, '
        'hydrocortisone cream or antihistamines for itching or minor '
        'allergic reactions, and cold packs for swelling.\n'
        'Rules:\n'
        '$_otcContentRules\n\n'
        'NEARBY HEALTHCARE: if the user asks where to go, how to find a '
        'hospital/clinic/doctor, or similar, OR if you just recommended '
        'seeking professional/emergency care, you may offer to help find '
        'nearby healthcare (the app will show a "Find Nearby Healthcare" '
        'option) — set the NEARBY field below to yes in that case. '
        'Never invent specific hospital/clinic names, addresses, phone '
        'numbers, or hours yourself — that lookup is handled separately '
        'by the app using real location data.\n\n'
        'Keep the medical disclaimer brief and only when it adds value — '
        'you do not need to repeat that you are not a doctor in every '
        'single reply; a short mention is enough the first time or when '
        'directly relevant. Never present guidance as a definitive '
        'diagnosis. '
        'Use simple words a child could understand. Avoid medical or '
        'technical terms. Say "slightly warm water", never "tepid water". '
        'IMPORTANT: Do not use any asterisks, bold markers, hashtags, or '
        'any markdown formatting in your response, and never mention the '
        'words "REFERENCE MATERIALS", "USER QUESTION", "CURRENT WOUND '
        'ANALYSIS", or "STEP" back to the user — just answer naturally as '
        'if you already knew this.\n'
        'FORMAT: Always reply in exactly this format, one field per line, '
        'so the app can offer an English/Tagalog toggle, the nearby-'
        'healthcare option, a bold visual warning when warranted, and a '
        'separate "Suggested OTC options" block — write the full response '
        'in English on a line starting with "EN:", then the full Tagalog '
        'translation of that same response on a line starting with "TL:", '
        'then a line "NEARBY: yes" or "NEARBY: no", then a line '
        '"SEVERITY: urgent" if this reply itself recommends seeking care '
        'urgently or immediately (an EMERGENCY or URGENT_CARE-level '
        'situation per the red-flag/emergency guidance above), or '
        '"SEVERITY: normal" otherwise, then a line "OTC: " followed by '
        'your OTC suggestions (per the OTC PRODUCT SUGGESTIONS rules '
        'above), or "OTC: none" if none apply. Format the OTC line '
        'exactly like this, all on one line, no line breaks within it: '
        'each suggestion as "Generic name :: Age limit :: '
        'Allergy precaution :: How to use", and separate multiple '
        'suggestions with " || ". Example: "OTC: Povidone-iodine :: '
        'Adults and children 2 years and above :: Do not use if allergic '
        'to iodine :: Antiseptic for minor cuts. Apply a small amount on '
        'the wound 1-2 times daily '
        '|| Paracetamol :: Adults and children 6 years and '
        'above :: Avoid if allergic to paracetamol or have liver disease '
        ':: Pain reliever. Take by mouth every 4-6 hours as needed, '
        'follow the package label for the exact dose". Do NOT repeat the OTC suggestions '
        'inside EN: or TL: — they belong only in the OTC: field, since '
        'the app renders them in their own labeled block with its own '
        'reminder to consult a doctor or pharmacist. Do not add any '
        'other lines, headers, or commentary outside these five.',
      ),
    );
  }

  GenerativeModel _createV2AssessmentModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: geminiProxyApiKey,
      httpClient: geminiProxyClient,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        // 2048 cut the JSON off mid-reply for serious wounds (long steps,
        // red flags and several OTC entries), which failed to parse and
        // showed as "Unable to Classify".
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(
        'You are a wound-assessment vision model. Analyze the submitted '
        'image and respond with ONLY a single JSON object — no preamble, '
        'no explanation, no markdown code fences, no trailing text. The '
        'response must be valid, directly parseable JSON matching this '
        'schema exactly:\n\n'
        '{\n'
        '  "is_wound": boolean,         // true for a real wound, injury, burn, bite, rash, skin condition or SCAR (also when the image is a screenshot or a photo of a screen showing one)\n'
        '  "confidence": number,        // 0.0-1.0\n'
        '  "wound_type": string,        // e.g. "laceration", "abrasion", "puncture", "burn", "scar", "none"\n'
        '  "visible_bleeding": string,  // "none" | "mild" | "moderate" | "severe"\n'
        '  "apparent_depth": string,    // "superficial" | "partial_thickness" | "deep" | "unknown"\n'
        '  "foreign_object_visible": boolean,\n'
        '  "infection_signs_visible": boolean,\n'
        '  "triage": string,            // "SELF_CARE" | "FIRST_AID" | "URGENT_CARE" | "EMERGENCY"\n'
        '  "red_flags": string[],       // e.g. "heavy bleeding", "exposed bone", "signs of infection"\n'
        '  "first_aid_steps": string[], // each item "Before|During|After: step — why"\n'
        '  "otc_options": [{"name": string, "age_limit": string, "allergy_precaution": string, "how_to_use": string}],\n'
        '  "needs_professional_evaluation": boolean,\n'
        '  "uncertainties": string[]    // anything the model is unsure about from the image\n'
        '}\n\n'
        'Rules:\n'
        '- Output the JSON object and nothing else. If you cannot produce valid JSON, '
        'still return the schema with an added "error" field rather than free text.\n'
        '- If image quality, angle, or lighting limits assessment, reflect that in '
        '"confidence" and "uncertainties" rather than guessing.\n'
        '- Any sign of heavy/uncontrolled bleeding, exposed bone/tendon, suspected '
        'fracture, deep puncture, large burns, or infection signs should default '
        '"triage" to "URGENT_CARE" or "EMERGENCY" and "needs_professional_evaluation" '
        'to true — bias toward caution when uncertain.\n'
        '- Do not conclude "needs_professional_evaluation": false unless confidence '
        'is high and no red flags are present.\n'
        '- FIRST_AID_STEPS FORMAT: write 6-10 short items in this order: 1-2 '
        '"Before:" items (preparation — washing hands with soap and water, '
        'clean disposable gloves, and the materials needed such as clean '
        'running water, clean gauze, and a clean non-stick dressing), '
        '3-5 "During:" items (the actual care), then 2-3 "After:" items '
        '(monitoring, when to change the dressing, signs of infection to '
        'watch for, and when to seek help). Write every item exactly as '
        '"Before: <step> — <why>", "During: <step> — <why>" or "After: '
        '<step> — <why>", where <why> is one short plain-language reason '
        '(under 15 words) and the separator is a spaced em dash (" — "). '
        'Use only standard, widely accepted first-aid reasons; never '
        'invent medical facts.\n'
        '- Contraindications to respect in first_aid_steps where they '
        'apply: never put ice directly on skin (wrap it in cloth); do not '
        'pour alcohol on a wound; do not '
        'put petroleum jelly on a wound that is still moist, weeping or '
        'bleeding; for burns, do not use butter, oil or toothpaste and do '
        'not pop blisters. Say so in a "During:" item when relevant.\n'
        '- HYDROGEN PEROXIDE: for a laceration, cut, scratch, scrape, '
        'puncture or other open wound (never a burn), include ONE '
        '"During:" item that offers household hydrogen peroxide for the '
        'first cleaning of the wound only, followed by a rinse with clean '
        'running water. Never suggest using it again or repeatedly on the '
        'same wound.\n'
        '- SUPPLY ALTERNATIVES: whenever a "Before:" item names a supply, '
        'also give a common substitute, for example "clean gauze, or a '
        'clean cloth if you do not have gauze. For a small injury, an '
        'adhesive bandage is fine."\n'
        '- AIR-DRYING: for a rash or another skin condition that is not an '
        'open wound, include a "During:" item to let the skin air-dry after '
        'washing: do not rub it with a towel, and keep the area uncovered.\n'
        '- PLAIN WORDS: Use simple words a child could understand. Avoid '
        'medical or technical terms. Write short sentences. Say "slightly '
        'warm water", never "tepid water"; "dirt", never "debris"; "put '
        'on", never "apply"; "rinse", never "irrigate"; and "clean", not '
        '"sterile", wherever that is safe to say.\n'
        '- SEVERE CASES: if "triage" is "EMERGENCY", or "visible_bleeding" '
        'is "severe", or "apparent_depth" is "deep" (for example exposed '
        'flesh, heavy bleeding or a deep wound), this is an emergency and '
        'not first aid: return "first_aid_steps": [] and "otc_options": [], '
        'set "needs_professional_evaluation" to true, and give the reasons '
        'in "red_flags".\n'
        '- Do not guess the body part in first_aid_steps unless it is clearly and '
        'unambiguously visible — use neutral phrasing like "the affected area" '
        'otherwise.\n'
        '- Hand hygiene belongs only in the "Before:" items; the "During:" '
        'items are the care of the actual affected area shown in the photo '
        '— never phrase hand hygiene as if it IS the affected-area care.\n'
        '- Do not include applying petroleum jelly (or a similar occlusive '
        'ointment) as a routine first_aid_steps item unless it is genuinely '
        'indicated for this specific wound_type — it is not common first aid '
        'practice for most minor wounds (e.g. do not suggest it for an '
        'abrasion/scrape). Prefer standard care instead (cleaning, antiseptic, '
        'a clean non-stick dressing).\n'
        '- OTC_OPTIONS: populate "otc_options" per these rules (same rules '
        'used for follow-up chat suggestions, so both places match):\n'
        '$_otcContentRules',
      ),
    );
  }

  /// Runs the v2 structured wound assessment on [imagePath], optionally
  /// grounded with reference material (passed as additional context
  /// alongside the image, not as part of the fixed system instruction
  /// above). Returns a [WoundAssessment] parsed from the model's JSON
  /// response.
  ///
  /// [tagalog] passes the app's language to the request: the model then also
  /// returns the steps and the unclear details in Tagalog
  /// (`first_aid_steps_tl`, `uncertainties_tl`) next to the English ones the
  /// app reads its Before / During / After labels and pictures from.
  ///
  /// [healthContext] (see data/health_context.dart) tells the model the
  /// person's reported conditions, allergies and medicines, so the steps and
  /// OTC suggestions can differ for someone with a health condition.
  Future<WoundAssessment> analyzeWoundV2(
    String imagePath, {
    String? referenceContext,
    bool tagalog = false,
    String? healthContext,
  }) async {
    // One analysis at a time (a double-tap must not send a second request).
    if (!AnalysisLock.tryAcquire()) {
      debugPrint('Gemini analyzeWoundV2: an analysis is already running');
      return WoundAssessment.errorFallback(
        'An analysis is already running. Please wait.',
      );
    }
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final model = _createV2AssessmentModel();

      final referenceBlock =
          referenceContext != null && referenceContext.trim().isNotEmpty
          ? 'Trusted reference material — use it to ground first_aid_steps '
                'and otc_options where relevant, and do not contradict it:\n'
                '$referenceContext\n\n'
          : '';

      final languageBlock = assessmentLanguageBlock(tagalog: tagalog);
      final healthBlock = healthContext != null && healthContext.isNotEmpty
          ? healthContextPromptBlock(healthContext)
          : '';

      final response = await model
          .generateContent([
            Content.multi([
              TextPart(
                '$referenceBlock$healthBlock${languageBlock}Analyze this wound or skin '
                'condition photo and respond per the schema.',
              ),
              DataPart('image/jpeg', imageBytes),
            ]),
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Analysis timed out. Please try again.'),
          );

      GeminiUsageLog.instance.record('assessment', response.usageMetadata);
      return parseWoundAssessment(response.text ?? '{}');
    } catch (e) {
      debugPrint('Gemini analyzeWoundV2 error: $e');
      return WoundAssessment.errorFallback(e.toString());
    } finally {
      AnalysisLock.release();
    }
  }

  /// Translates first-aid step strings into Tagalog for the result
  /// screen's translate toggle. Kept as a small, separate call so the v2
  /// assessment call above can stay strictly compliant with its exact
  /// JSON schema (which has no language field). Returns an empty list on
  /// failure — callers should keep showing the English text in that case.
  // Deliberately NOT using JSON mode here (unlike the other calls in this
  // file) — a strict `jsonDecode` throws on the smallest deviation (a
  // stray leading sentence, an unescaped quote inside a translated line,
  // a wrapper object instead of a bare array), and translation prose is
  // exactly the kind of output that's more prone to those deviations than
  // the rigid structured-assessment JSON elsewhere. A numbered-line format
  // parsed with simple, forgiving string splitting tolerates minor
  // formatting drift instead of failing outright on it.
  Future<List<String>> translateToTagalog(List<String> englishLines) async {
    if (englishLines.isEmpty) return [];
    try {
      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: geminiProxyApiKey,
        httpClient: geminiProxyClient,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 2048,
        ),
        systemInstruction: Content.system(
          'Translate each numbered line of first aid instructions into '
          'natural, clear Filipino (Tagalog) suitable for a first aid '
          'app. Use simple words a child could understand and avoid '
          'medical or technical terms. Reply with ONLY the translated lines, one per line, in '
          'the same order, each starting with the same number and a '
          'period (eg "1. ..."). Do not add any other text, headers, '
          'blank lines, or commentary.',
        ),
      );
      final numbered = [
        for (var i = 0; i < englishLines.length; i++)
          '${i + 1}. ${englishLines[i]}',
      ].join('\n');
      final response = await model
          .generateContent([Content.text(numbered)])
          .timeout(const Duration(seconds: 20));
      GeminiUsageLog.instance.record('translation', response.usageMetadata);

      // Match each line by its OWN number rather than by position/count —
      // a strict "same number of lines in, same number out" check turned
      // out to be its own source of silent failures: any stray blank line,
      // reordering, or a step the model wrapped across two lines was
      // enough to throw the whole translation away. Reading the number
      // off each line and looking up exactly what's needed tolerates all
      // of that; only a genuinely missing translation for a given step
      // now counts as a real failure.
      final byNumber = <int, String>{};
      for (final rawLine in (response.text ?? '').split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final match = RegExp(r'^(\d+)[.)]\s*(.+)$').firstMatch(line);
        if (match == null) continue;
        final number = int.tryParse(match.group(1)!);
        final text = match.group(2)!.trim();
        if (number != null && text.isNotEmpty) byNumber[number] = text;
      }

      final translated = <String>[];
      for (var i = 1; i <= englishLines.length; i++) {
        final line = byNumber[i];
        if (line == null) {
          debugPrint(
            'Gemini translateToTagalog: missing line $i of '
            '${englishLines.length}. Raw: ${response.text}',
          );
          return [];
        }
        translated.add(line);
      }
      return translated;
    } catch (e) {
      debugPrint('Gemini translateToTagalog error: $e');
      return [];
    }
  }

  /// True for a past user message that still holds the per-turn context
  /// blocks that [trimChatHistory] cuts.
  static bool _carriesContext(Content content) =>
      content.role == 'user' &&
      content.parts.any(
        (p) => p is TextPart && !p.text.startsWith(chatQuestionMarker),
      );

  void reset() {
    _chatSession = null;
    _chatModel = null;
  }

  void resetChat() {
    _chatSession = null;
    _chatModel = null;
  }

  Future<String> sendChatMessage(
    String message, {
    String? referenceContext,
    String? woundContext,
    String? healthContext,
  }) async {
    try {
      if (_chatModel == null || _chatSession == null) {
        _chatModel = _createChatModel();
        _chatSession = _chatModel!.startChat();
      }

      final referenceBlock =
          referenceContext != null && referenceContext.trim().isNotEmpty
          ? 'REFERENCE MATERIALS:\n$referenceContext'
          : 'REFERENCE MATERIALS:\n(none found for this question)';
      final woundBlock = woundContext != null && woundContext.trim().isNotEmpty
          ? '\n\nCURRENT WOUND ANALYSIS:\n$woundContext'
          : '';

      // What the person already saved in the app (see chatHealthContext).
      final healthBlock =
          healthContext != null && healthContext.trim().isNotEmpty
          ? '\n\nUSER HEALTH PROFILE:\n$healthContext'
          : '';

      final promptText =
          '$referenceBlock$woundBlock$healthBlock\n\n$chatQuestionMarker$message';

      // Gemini resends the whole history every turn, so keep only the last
      // few exchanges and drop the old turns' reference excerpts.
      final history = _chatSession!.history.toList();
      if (history.length > maxChatHistoryMessages ||
          history.any(_carriesContext)) {
        _chatSession = _chatModel!.startChat(history: trimChatHistory(history));
      }

      final response = await _chatSession!
          .sendMessage(Content.text(promptText))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      GeminiUsageLog.instance.record('chat', response.usageMetadata);
      return response.text ??
          'I could not generate a response. Please try rephrasing.';
    } catch (e) {
      debugPrint('Gemini sendChatMessage error: $e');
      _chatSession = null;
      _chatModel = null;

      if (e.toString().contains('SAFETY')) {
        return 'I\'m unable to respond to that. Please ask questions '
            'related to first aid and wound care only.';
      }
      // Every other failure (network error, timeout, malformed API
      // response) is a real error, not a message to show as if it came
      // from the assistant — let it propagate so the caller's own
      // friendly-fallback handling deals with it instead of this method
      // formatting the raw exception into what looks like a chat reply.
      rethrow;
    }
  }

  Future<WoundDetectionResult> detectWounds(String imagePath) async {
    // One analysis at a time (a double-tap must not send a second request).
    if (!AnalysisLock.tryAcquire()) {
      debugPrint('Gemini detectWounds: an analysis is already running');
      return WoundDetectionResult(
        isBlurry: false,
        hasWound: false,
        woundCount: 0,
        woundDescriptions: const [],
        checkFailed: true,
      );
    }
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final model = _createDetectionModel();

      final response = await model
          .generateContent([
            Content.multi([
              TextPart(
                'Check this photo for blur, darkness, cropping, whether it is '
                'a genuine direct photo of skin, count the distinct wounds '
                'or skin conditions visible, and give a bounding box for '
                'each one.',
              ),
              DataPart('image/jpeg', imageBytes),
            ]),
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Wound detection timed out.'),
          );

      GeminiUsageLog.instance.record('detection', response.usageMetadata);
      return parseDetectionResponse(response.text ?? '');
    } catch (e) {
      debugPrint('Gemini detectWounds error: $e');
      // The photo could not be checked: do not let it through unchecked.
      return WoundDetectionResult(
        isBlurry: false,
        hasWound: false,
        woundCount: 0,
        woundDescriptions: const [],
        checkFailed: true,
      );
    } finally {
      AnalysisLock.release();
    }
  }

  Rect? _parseBox(String value) {
    final numbers = RegExp(r'-?\d+(\.\d+)?')
        .allMatches(value)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    if (numbers.length < 4) return null;

    final ymin = (numbers[0] / 1000).clamp(0.0, 1.0);
    final xmin = (numbers[1] / 1000).clamp(0.0, 1.0);
    final ymax = (numbers[2] / 1000).clamp(0.0, 1.0);
    final xmax = (numbers[3] / 1000).clamp(0.0, 1.0);
    if (xmax <= xmin || ymax <= ymin) return null;

    return Rect.fromLTRB(xmin, ymin, xmax, ymax);
  }

  @visibleForTesting
  WoundDetectionResult parseDetectionResponse(String text) {
    var isBlurry = false;
    var isTooDark = false;
    var isCropped = false;
    var isUnrecognizable = false;
    var looksFake = false;
    // A reply without the wound verdict cannot be trusted either way.
    var sawVerdict = false;
    var hasWound = true;
    var woundCount = 1;
    var confidence = DetectionConfidence.medium;
    var artificialMark = ArtificialMarkLikelihood.no;
    final descriptionsByIndex = <int, String>{};
    final boxesByIndex = <int, Rect>{};

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = RegExp(r'^([A-Z_0-9]+):\s*(.*)$').firstMatch(line);
      if (match == null) continue;
      final key = match.group(1)!.toUpperCase();
      final value = match.group(2)!.trim();

      if (key == 'BLURRY') {
        isBlurry = value.toLowerCase().startsWith('y');
        continue;
      }
      bool yes() => value.toLowerCase().startsWith('y');
      if (key == 'TOO_DARK') {
        isTooDark = yes();
        continue;
      }
      if (key == 'CROPPED') {
        isCropped = yes();
        continue;
      }
      if (key == 'UNRECOGNIZABLE') {
        isUnrecognizable = yes();
        continue;
      }
      if (key == 'FAKE_IMAGE') {
        looksFake = yes();
        continue;
      }
      if (key == 'WOUND_DETECTED') {
        hasWound = yes();
        sawVerdict = true;
        continue;
      }
      if (key == 'CONFIDENCE') {
        final lower = value.toLowerCase();
        if (lower.startsWith('high')) {
          confidence = DetectionConfidence.high;
        } else if (lower.startsWith('low')) {
          confidence = DetectionConfidence.low;
        } else {
          confidence = DetectionConfidence.medium;
        }
        continue;
      }
      if (key == 'ARTIFICIAL_MARK_LIKELY') {
        final lower = value.toLowerCase();
        if (lower.startsWith('yes')) {
          artificialMark = ArtificialMarkLikelihood.yes;
        } else if (lower.startsWith('unsure')) {
          artificialMark = ArtificialMarkLikelihood.unsure;
        } else {
          artificialMark = ArtificialMarkLikelihood.no;
        }
        continue;
      }
      if (key == 'WOUND_COUNT') {
        final digits = RegExp(r'\d+').firstMatch(value)?.group(0);
        woundCount = digits != null ? int.parse(digits) : woundCount;
        continue;
      }

      final boxMatch = RegExp(r'^WOUND_(\d+)_BOX$').firstMatch(key);
      if (boxMatch != null) {
        final rect = _parseBox(value);
        if (rect != null) boxesByIndex[int.parse(boxMatch.group(1)!)] = rect;
        continue;
      }

      final descMatch = RegExp(r'^WOUND_(\d+)$').firstMatch(key);
      if (descMatch != null && value.isNotEmpty) {
        descriptionsByIndex[int.parse(descMatch.group(1)!)] = value;
      }
    }

    if (!hasWound) {
      woundCount = 0;
    } else if (woundCount < 1) {
      woundCount = descriptionsByIndex.isNotEmpty
          ? descriptionsByIndex.length
          : 1;
    }

    // Build description/box lists indexed 1..woundCount so the UI always
    // gets exactly `woundCount` entries to render as tappable regions,
    // even if the model omitted a line for one of them.
    final descriptions = <String>[];
    final boxes = <Rect?>[];
    for (var i = 1; i <= woundCount; i++) {
      descriptions.add(descriptionsByIndex[i] ?? 'Wound $i');
      boxes.add(boxesByIndex[i]);
    }

    return WoundDetectionResult(
      isBlurry: isBlurry,
      hasWound: hasWound,
      woundCount: woundCount,
      woundDescriptions: descriptions,
      confidence: confidence,
      artificialMarkLikelihood: artificialMark,
      isTooDark: isTooDark,
      isCropped: isCropped,
      isUnrecognizable: isUnrecognizable,
      looksFake: looksFake,
      checkFailed: !sawVerdict,
      woundBoxes: boxes,
    );
  }
}
