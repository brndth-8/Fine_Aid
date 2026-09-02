import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class FirstAidChunk {
  final String id;
  final String title;
  final String content;
  final String topic;
  final String source;
  final int? page;
  final List<String> keywords;

  final int matchScore;

  FirstAidChunk({
    required this.id,
    required this.title,
    required this.content,
    required this.topic,
    required this.source,
    required this.keywords,
    this.page,
    this.matchScore = 0,
  });

  factory FirstAidChunk.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    int matchScore = 0,
  }) {
    final data = doc.data();
    return FirstAidChunk(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      topic: (data['topic'] as String?) ?? '',
      source: (data['source'] as String?) ?? '',
      page: data['page'] is int ? data['page'] as int : null,
      keywords:
          (data['keywords'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      matchScore: matchScore,
    );
  }

  String toContextEntry() {
    final pageInfo = page != null ? ', p.$page' : '';
    return '### $title\nSource: $source$pageInfo\n$content';
  }
}

class FirstAidContentService {
  static final FirstAidContentService _instance =
      FirstAidContentService._internal();
  factory FirstAidContentService() => _instance;
  FirstAidContentService._internal();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('firstAidContent');

  // Firestore allows at most 10 values in an `array-contains-any` clause.
  static const int _maxQueryKeywords = 10;

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'to', 'of', 'in', 'on', 'for', 'and', 'or', 'but', 'if', 'so', 'as',
    'at', 'by', 'with', 'about', 'against', 'between', 'into', 'through',
    'during', 'before', 'after', 'above', 'below', 'from', 'up', 'down',
    'out', 'off', 'over', 'under', 'again', 'further', 'then', 'once',
    'i', 'me', 'my', 'you', 'your', 'it', 'its', 'this', 'that', 'these',
    'those', 'do', 'does', 'did', 'doing', 'have', 'has', 'had', 'having',
    'can', 'could', 'should', 'would', 'will', 'shall', 'may', 'might',
    'what', 'when', 'where', 'why', 'how', 'not', 'no', 'yes', 'im',
    // Common conversational filler in a first-aid chatbot context
    'help', 'please', 'hi', 'hello', 'thanks', 'ok', 'okay',
  };

  List<String> tokenize(String text) {
    final tokens = RegExp(
      r"[a-zA-Z][a-zA-Z0-9\-]*",
    ).allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();

    final seen = <String>{};
    final result = <String>[];
    for (final t in tokens) {
      if (t.length < 3) continue;
      if (_stopWords.contains(t)) continue;
      if (seen.add(t)) result.add(t);
    }
    return result;
  }

  Future<List<FirstAidChunk>> search(String query, {int limit = 4}) async {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return [];

    final queryTokens = List<String>.from(tokens)
      ..sort((a, b) => b.length.compareTo(a.length));
    final searchTokens = queryTokens.take(_maxQueryKeywords).toList();

    try {
      final snapshot = await _collection
          .where('keywords', arrayContainsAny: searchTokens)
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) return [];

      final tokenSet = tokens.toSet();
      final scored = snapshot.docs.map((doc) {
        final data = doc.data();
        final docKeywords =
            (data['keywords'] as List?)?.map((e) => e.toString()).toSet() ??
            <String>{};
        final score = docKeywords.intersection(tokenSet).length;
        return FirstAidChunk.fromDoc(doc, matchScore: score);
      }).toList();

      scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      return scored.take(limit).toList();
    } catch (e) {
      debugPrint('FirstAidContentService.search error: $e');
      return [];
    }
  }

  Future<String?> buildReferenceContext(String query, {int limit = 4}) async {
    final chunks = await search(query, limit: limit);
    if (chunks.isEmpty) return null;
    return chunks.map((c) => c.toContextEntry()).join('\n\n---\n\n');
  }
}
