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

  GenerativeModel _createVisionModel() {
    return GenerativeModel(
      model: 'gemini-3.5-flash',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 8192,
      ),
      systemInstruction: Content.system(
        'You are a medical first aid assistant for Fine Aid, a Filipino '
        'first aid app. '
        'Always include a medical disclaimer. Never diagnose — only provide '
        'first aid guidance. If the situation is severe, always recommend '
        'seeking professional medical help immediately. '
        'Format your response with these sections:\n'
        'Wound Assessment — what you observe\n'
        'First Aid Steps — numbered steps, each with English then '
        'Tagalog translation\n'
        'Warning Signs — when to seek emergency care\n'
        'Disclaimer — this is guidance only, not a diagnosis',
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
        'first aid app. '
        'Always include a medical disclaimer. Never diagnose — only provide '
        'first aid guidance. If severe, always recommend seeking professional '
        'medical help immediately. '
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
  }

  void resetChat() {
    _chatSession = null;
    _chatModel = null;
  }

  Future<String> sendChatMessage(String message) async {
    try {
      if (_chatModel == null || _chatSession == null) {
        _chatModel = _createChatModel();
        _chatSession = _chatModel!.startChat();
      }

      final response = await _chatSession!
          .sendMessage(Content.text(message))
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

  Future<String> analyzeWoundImage(String imagePath) async {
    try {
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
