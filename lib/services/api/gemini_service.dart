import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/api_keys.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _chatModel;
  ChatSession? _chatSession;
  GenerativeModel? _groundingModel;

  GenerativeModel _createVisionModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 4096,
      ),
      systemInstruction: Content.system(
        'You are a medical first aid assistant for Fine Aid, a Filipino '
        'first aid app. '
        'Analyze wound and skin condition images and provide clear, '
        'accurate first aid guidance in both English and Filipino (Tagalog). '
        'Always include a medical disclaimer. Never diagnose — only provide '
        'first aid guidance. If the situation is severe, always recommend '
        'seeking professional medical help immediately. '
        'Format your response with these sections:\n'
        '**First Aid Steps** — numbered steps, each with English then '
        'Tagalog translation\n'
        '**Warning Signs** — when to seek emergency care\n'
        '**Disclaimer** — this is guidance only, not a diagnosis',
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
        'wound-care, skin condition, and OTC medicine reference books) '
        'followed by the actual USER QUESTION.\n\n'
        'STEP 1 — SCOPE CHECK (always do this first, before anything else):\n'
        'Decide whether the USER QUESTION is actually about a first aid '
        'concern — an injury, wound, burn, bite, bleeding, skin condition, '
        'symptom, medical emergency, or a question about an OTC medicine.\n'
        'IN-SCOPE examples: "I cut my finger", "is this rash dangerous", '
        '"can I take paracetamol for a headache", "my wound is swelling", '
        '"paano gamutin ang paso".\n'
        'OUT-OF-SCOPE examples: small talk or greetings with no health '
        'concern stated, requests unrelated to first aid ("help me with my '
        'homework", "write my essay", "what\'s the weather", "tell me a '
        'joke"), and statements that merely mention an unrelated object, '
        'food, or activity without describing any injury or symptom (eg, '
        '"I ate palabok", "I watched a movie"). Do NOT infer a health '
        'question from a message like that just because it could loosely '
        'relate to health (eg, food, tiredness, sitting) — if no injury, '
        'wound, symptom, or medical concern is actually stated or asked '
        'about, it is out of scope.\n'
        'If OUT-OF-SCOPE: reply with ONLY a short, friendly 1-2 sentence '
        'redirect stating you can only help with first aid, wound care, '
        'and related health questions, and invite them to describe an '
        'injury or symptom. Do NOT provide any advice, tips, facts, or '
        'suggestions about the off-topic subject or anything tangentially '
        'related to it (eg, no posture, diet, sleep, or productivity tips '
        'unless the user actually asked a first aid question). Stop there '
        '— do not continue to STEP 2.\n'
        'If IN-SCOPE: continue to STEP 2.\n\n'
        'STEP 2 — ANSWER FROM REFERENCE MATERIALS ONLY:\n'
        'Answer ONLY using the information in REFERENCE MATERIALS for that '
        'turn. Do not use outside/general medical knowledge. '
        'If REFERENCE MATERIALS says "(none found for this question)" or '
        'the reference excerpts provided do not actually contain the '
        'answer, say so clearly (eg, "I don\'t have that in my reference '
        'materials") and recommend the person consult a doctor, nurse, or '
        'pharmacist — do not guess or fill the gap from general knowledge. '
        'Reply in both English and Filipino (Tagalog) where practical. '
        'Always include a brief medical disclaimer. Never diagnose — only '
        'relay first aid guidance grounded in the reference materials. If '
        'the situation sounds severe, always recommend seeking professional '
        'medical help immediately regardless of what the reference '
        'materials say. '
        'IMPORTANT: Do not use any asterisks, bold markers, hashtags, or '
        'any markdown formatting in your response, and never mention the '
        'words "REFERENCE MATERIALS", "USER QUESTION", "STEP 1", or "STEP '
        '2" back to the user — just answer naturally as if you already '
        'knew this.',
      ),
    );
  }

  GenerativeModel _createGroundingModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 2048,
      ),
      systemInstruction: Content.system(
        'You are a medical first aid assistant for Fine Aid, a Filipino '
        'first aid app. '
        'You will receive a DRAFT wound/skin assessment written from a '
        'photo, plus REFERENCE MATERIALS drawn from trusted first aid and '
        'skin-condition handbooks. '
        'Rewrite the assessment using ONLY facts that are supported by the '
        'REFERENCE MATERIALS. If a part of the draft is not covered by the '
        'reference materials, say so plainly instead of guessing, and '
        'recommend seeking professional medical help for that part. '
        'Do not use outside knowledge beyond the REFERENCE MATERIALS and '
        'the visual description already in the draft (eg, "there is '
        'redness and swelling") — only the recommended care, causes, and '
        'guidance must come from the REFERENCE MATERIALS. '
        'Never diagnose — only provide first aid guidance, in both English '
        'and Filipino (Tagalog). '
        'IMPORTANT: Do not use any asterisks, bold markers, hashtags, or '
        'any markdown formatting in your response. Plain text only.\n'
        'Format your response with these exact section headers '
        '(write them exactly as shown, in ALL CAPS followed by colon):\n'
        'FIRST AID STEPS: numbered steps, each followed by the Tagalog '
        'translation on the next line\n'
        'WARNING SIGNS: list when to seek emergency care\n'
        'DISCLAIMER: One sentence only — state this is first aid guidance, not a medical diagnosis.',
      ),
    );
  }

  void reset() {
    _chatSession = null;
    _chatModel = null;
    _groundingModel = null;
  }

  void resetChat() {
    _chatSession = null;
    _chatModel = null;
  }

  Future<String> sendChatMessage(
    String message, {
    String? referenceContext,
  }) async {
    try {
      if (_chatModel == null || _chatSession == null) {
        _chatModel = _createChatModel();
        _chatSession = _chatModel!.startChat();
      }

      final promptText =
          referenceContext != null && referenceContext.trim().isNotEmpty
          ? 'REFERENCE MATERIALS:\n$referenceContext\n\nUSER QUESTION: $message'
          : 'REFERENCE MATERIALS:\n(none found for this question)\n\nUSER QUESTION: $message';

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
      return 'Something went wrong. Please try again.\nError: $e';
    }
  }

  Future<String> draftWoundAnalysis(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final model = _createVisionModel();

    final response = await model
        .generateContent([
          Content.multi([
            TextPart(
              'Please analyze this wound or skin condition and provide '
              'first aid guidance.',
            ),
            DataPart('image/jpeg', imageBytes),
          ]),
        ])
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () =>
              throw Exception('Analysis timed out. Please try again.'),
        );

    return response.text ??
        'Unable to analyze the image. Please ensure the wound is '
            'clearly visible and try again.';
  }

  Future<String> groundResultWithReferences(
    String draftResult,
    String referenceContext,
  ) async {
    _groundingModel ??= _createGroundingModel();

    final promptText =
        'REFERENCE MATERIALS:\n$referenceContext\n\n'
        'DRAFT ASSESSMENT:\n$draftResult';

    final response = await _groundingModel!
        .generateContent([Content.text(promptText)])
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Grounding request timed out. Please try again.'),
        );

    return response.text ?? draftResult;
  }

  Future<String> analyzeWoundImage(
    String imagePath, {
    Future<String?> Function(String query)? retrieveReferences,
  }) async {
    try {
      final draft = await draftWoundAnalysis(imagePath);

      if (retrieveReferences == null) return draft;

      String? referenceContext;
      try {
        referenceContext = await retrieveReferences(draft);
      } catch (e) {
        debugPrint('analyzeWoundImage retrieval error: $e');
      }

      if (referenceContext == null || referenceContext.trim().isEmpty) {
        return draft;
      }

      try {
        return await groundResultWithReferences(draft, referenceContext);
      } catch (e) {
        debugPrint('analyzeWoundImage grounding error: $e');
        return draft;
      }
    } catch (e) {
      debugPrint('Gemini analyzeWoundImage error: $e');
      if (e.toString().contains('SAFETY')) {
        return 'The image could not be processed due to content safety '
            'filters. Please ensure the image shows only the wound area.';
      }
      return 'Analysis failed. Please try again.\nError: $e';
    }
  }
}
