import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/api_keys.dart';

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
/// marking, printed image, screenshot, shadow, clothing pattern, hair
/// strand, or similar artifact — rather than real skin trauma.
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
    this.woundBoxes = const [],
  });

  /// The "Free Pass Filter": a three-state judgment on whether it's safe
  /// to proceed to wound classification and first-aid recommendations,
  /// rather than risking misleading guidance from an unclear photo, an
  /// artificial mark (pen line, drawing, makeup, printed image, etc.), or
  /// something that just isn't a wound at all.
  FreePassResult get freePassResult {
    if (isBlurry || !hasWound || woundCount == 0) return FreePassResult.fail;
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

  const BilingualReply({
    required this.english,
    this.tagalog,
    this.suggestNearby = false,
    this.isUrgent = false,
  });
}

/// Parses a chat response into its English/Tagalog parts and the nearby-
/// healthcare/urgency flags. Falls back to showing the raw text as-is if
/// the model didn't follow the "EN:" / "TL:" / "NEARBY:" / "SEVERITY:"
/// format (eg, a short redirect message).
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

  final en = enMatch?.group(1)?.trim();
  final tl = tlMatch?.group(1)?.trim();
  final suggestNearby = nearbyMatch?.group(1)?.toLowerCase() == 'yes';
  final isUrgent = severityMatch?.group(1)?.toLowerCase() == 'urgent';

  if (en == null || en.isEmpty) {
    return BilingualReply(
      english: raw.trim(),
      suggestNearby: suggestNearby,
      isUrgent: isUrgent,
    );
  }
  return BilingualReply(
    english: en,
    tagalog: (tl != null && tl.isNotEmpty) ? tl : null,
    suggestNearby: suggestNearby,
    isUrgent: isUrgent,
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
  final List<String> otcOptions;
  final bool needsProfessionalEvaluation;
  final List<String> uncertainties;
  final String? error;

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
    this.error,
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

/// Parses the v2 assessment model's JSON response. Defensively strips
/// markdown code fences in case the model adds them despite instructions
/// not to, and falls back to an uncertain/error result rather than
/// crashing if the response isn't valid JSON — never silently invent a
/// wound assessment from unparseable output.
WoundAssessment parseWoundAssessment(String raw) {
  try {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }
    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    List<String> stringList(dynamic value) =>
        (value as List?)?.map((e) => e.toString()).toList() ?? const [];

    return WoundAssessment(
      isWound: map['is_wound'] == true,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      woundType: map['wound_type']?.toString() ?? 'none',
      visibleBleeding: map['visible_bleeding']?.toString() ?? 'none',
      apparentDepth: map['apparent_depth']?.toString() ?? 'unknown',
      foreignObjectVisible: map['foreign_object_visible'] == true,
      infectionSignsVisible: map['infection_signs_visible'] == true,
      triage: _parseTriage(map['triage']?.toString()),
      redFlags: stringList(map['red_flags']),
      firstAidSteps: stringList(map['first_aid_steps']),
      otcOptions: stringList(map['otc_options']),
      needsProfessionalEvaluation: map['needs_professional_evaluation'] == true,
      uncertainties: stringList(map['uncertainties']),
      error: map['error']?.toString(),
    );
  } catch (e) {
    debugPrint('parseWoundAssessment error: $e — raw: $raw');
    return WoundAssessment.errorFallback(e.toString());
  }
}

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _chatModel;
  ChatSession? _chatSession;

  GenerativeModel _createDetectionModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 512,
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
        'printed photo or a screenshot of an image (not a live view of '
        'skin), a shadow or lighting artifact, a fold or pattern in '
        'clothing, a strand of hair, a scar that has already fully '
        'healed, a tattoo, or dirt/stain. Genuine skin injuries usually '
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
        'Answer ONLY in this exact plain-text format, one field per line, '
        'no extra commentary, no markdown:\n'
        'BLURRY: yes or no — yes only if the photo is so out of focus or '
        'shaky that a wound could not be assessed from it\n'
        'WOUND_DETECTED: yes or no — yes only if you see genuine evidence '
        'of a real wound, injury, burn, bite, rash, or other actual skin '
        'condition (not just any mark on skin)\n'
        'ARTIFICIAL_MARK_LIKELY: yes, no, or unsure — yes if the mark '
        'looks like a pen/marker line, drawn mark, makeup, temporary '
        'marking, printed image, screenshot, shadow, clothing pattern, '
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
      apiKey: ApiKeys.gemini,
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
        'Decide whether the USER QUESTION is actually about a first aid '
        'concern — an injury, wound, burn, bite, bleeding, skin condition, '
        'symptom, medical emergency, or a question about an OTC medicine.\n'
        'IN-SCOPE examples: "I cut my finger", "is this rash dangerous", '
        '"can I take paracetamol for a headache", "my wound is swelling", '
        '"what if it doesn\'t heal in a week", "paano gamutin ang paso".\n'
        'OUT-OF-SCOPE examples: small talk or greetings with no health '
        'concern stated, requests unrelated to first aid ("help me with my '
        'homework", "write my essay", "what\'s the weather", "tell me a '
        'joke"), and statements that merely mention an unrelated object, '
        'food, or activity without describing any injury or symptom. '
        'If OUT-OF-SCOPE: reply with ONLY a short, friendly 1-2 sentence '
        'redirect and stop there.\n'
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
        'IMPORTANT: Do not use any asterisks, bold markers, hashtags, or '
        'any markdown formatting in your response, and never mention the '
        'words "REFERENCE MATERIALS", "USER QUESTION", "CURRENT WOUND '
        'ANALYSIS", or "STEP" back to the user — just answer naturally as '
        'if you already knew this.\n'
        'FORMAT: Always reply in exactly this format, one field per line, '
        'so the app can offer an English/Tagalog toggle, the nearby-'
        'healthcare option, and a bold visual warning when warranted — '
        'write the full response in English on a line starting with '
        '"EN:", then the full Tagalog translation of that same response '
        'on a line starting with "TL:", then a line "NEARBY: yes" or '
        '"NEARBY: no", then a line "SEVERITY: urgent" if this reply '
        'itself recommends seeking care urgently or immediately (an '
        'EMERGENCY or URGENT_CARE-level situation per the red-flag/'
        'emergency guidance above), or "SEVERITY: normal" otherwise. Do '
        'not add any other lines, headers, or commentary outside these '
        'four.',
      ),
    );
  }

  GenerativeModel _createV2AssessmentModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 2048,
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(
        'You are a wound-assessment vision model. Analyze the submitted '
        'image and respond with ONLY a single JSON object — no preamble, '
        'no explanation, no markdown code fences, no trailing text. The '
        'response must be valid, directly parseable JSON matching this '
        'schema exactly:\n\n'
        '{\n'
        '  "is_wound": boolean,\n'
        '  "confidence": number,        // 0.0-1.0\n'
        '  "wound_type": string,        // e.g. "laceration", "abrasion", "puncture", "burn", "none"\n'
        '  "visible_bleeding": string,  // "none" | "mild" | "moderate" | "severe"\n'
        '  "apparent_depth": string,    // "superficial" | "partial_thickness" | "deep" | "unknown"\n'
        '  "foreign_object_visible": boolean,\n'
        '  "infection_signs_visible": boolean,\n'
        '  "triage": string,            // "SELF_CARE" | "FIRST_AID" | "URGENT_CARE" | "EMERGENCY"\n'
        '  "red_flags": string[],       // e.g. "heavy bleeding", "exposed bone", "signs of infection"\n'
        '  "first_aid_steps": string[],\n'
        '  "otc_options": string[],\n'
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
        '- Do not guess the body part in first_aid_steps unless it is clearly and '
        'unambiguously visible — use neutral phrasing like "the affected area" '
        'otherwise.\n'
        '- Distinguish general hand-hygiene-before-touching-a-wound (a brief, '
        'secondary note at most) from care of the actual affected area shown in '
        'the photo (the main content of first_aid_steps) — never phrase hand '
        'hygiene as if it IS the affected-area care.',
      ),
    );
  }

  /// Runs the v2 structured wound assessment on [imagePath], optionally
  /// grounded with reference material (passed as additional context
  /// alongside the image, not as part of the fixed system instruction
  /// above). Returns a [WoundAssessment] parsed from the model's JSON
  /// response.
  Future<WoundAssessment> analyzeWoundV2(
    String imagePath, {
    String? referenceContext,
  }) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final model = _createV2AssessmentModel();

      final referenceBlock =
          referenceContext != null && referenceContext.trim().isNotEmpty
          ? 'Trusted reference material — use it to ground first_aid_steps '
                'and otc_options where relevant, and do not contradict it:\n'
                '$referenceContext\n\n'
          : '';

      final response = await model
          .generateContent([
            Content.multi([
              TextPart(
                '${referenceBlock}Analyze this wound or skin condition '
                'photo and respond per the schema.',
              ),
              DataPart('image/jpeg', imageBytes),
            ]),
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Analysis timed out. Please try again.'),
          );

      return parseWoundAssessment(response.text ?? '{}');
    } catch (e) {
      debugPrint('Gemini analyzeWoundV2 error: $e');
      return WoundAssessment.errorFallback(e.toString());
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
        apiKey: ApiKeys.gemini,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 2048,
        ),
        systemInstruction: Content.system(
          'Translate each numbered line of first aid instructions into '
          'natural, clear Filipino (Tagalog) suitable for a first aid '
          'app. Reply with ONLY the translated lines, one per line, in '
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

      final promptText =
          '$referenceBlock$woundBlock\n\nUSER QUESTION: $message';

      final response = await _chatSession!
          .sendMessage(Content.text(promptText))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

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
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final model = _createDetectionModel();

      final response = await model
          .generateContent([
            Content.multi([
              TextPart(
                'Check this photo for blur, count the distinct wounds or '
                'skin conditions visible, and give a bounding box for each '
                'one.',
              ),
              DataPart('image/jpeg', imageBytes),
            ]),
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Wound detection timed out.'),
          );

      return _parseDetectionResponse(response.text ?? '');
    } catch (e) {
      debugPrint('Gemini detectWounds error: $e');
      return WoundDetectionResult(
        isBlurry: false,
        hasWound: true,
        woundCount: 1,
        woundDescriptions: const [],
      );
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

  WoundDetectionResult _parseDetectionResponse(String text) {
    var isBlurry = false;
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
      if (key == 'WOUND_DETECTED') {
        hasWound = value.toLowerCase().startsWith('y');
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
      woundBoxes: boxes,
    );
  }
}
