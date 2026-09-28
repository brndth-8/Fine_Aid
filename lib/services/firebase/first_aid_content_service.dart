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
  final List<String> imageUrls;

  final int matchScore;

  FirstAidChunk({
    required this.id,
    required this.title,
    required this.content,
    required this.topic,
    required this.source,
    required this.keywords,
    this.page,
    this.imageUrls = const [],
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
      imageUrls:
          (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
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

  static const int _maxQueryKeywords = 10;

  static const Set<String> _stopWords = {
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'to',
    'of',
    'in',
    'on',
    'for',
    'and',
    'or',
    'but',
    'if',
    'so',
    'as',
    'at',
    'by',
    'with',
    'about',
    'against',
    'between',
    'into',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'from',
    'up',
    'down',
    'out',
    'off',
    'over',
    'under',
    'again',
    'further',
    'then',
    'once',
    'i',
    'me',
    'my',
    'you',
    'your',
    'it',
    'its',
    'this',
    'that',
    'these',
    'those',
    'do',
    'does',
    'did',
    'doing',
    'have',
    'has',
    'had',
    'having',
    'can',
    'could',
    'should',
    'would',
    'will',
    'shall',
    'may',
    'might',
    'what',
    'when',
    'where',
    'why',
    'how',
    'not',
    'no',
    'yes',
    'im',

    'help',
    'please',
    'hi',
    'hello',
    'thanks',
    'ok',
    'okay',
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

  List<FirstAidChunk>? _otcCache;
  DateTime? _otcCacheAt;

  Future<List<FirstAidChunk>> searchOtcMedications(
    String query, {
    int limit = 8,
    int minScore = 2,
  }) async {
    final tokens = tokenize(query).toSet();
    if (tokens.isEmpty) return [];

    try {
      var otcChunks = _otcCache;
      final cacheAge = _otcCacheAt == null
          ? null
          : DateTime.now().difference(_otcCacheAt!);
      if (otcChunks == null || cacheAge == null || cacheAge.inMinutes >= 10) {
        final snapshot = await _collection
            .where('topic', isEqualTo: 'otc_medication')
            .limit(600)
            .get()
            .timeout(const Duration(seconds: 15));
        otcChunks = snapshot.docs
            .map((doc) => FirstAidChunk.fromDoc(doc))
            .toList();
        _otcCache = otcChunks;
        _otcCacheAt = DateTime.now();
      }

      List<FirstAidChunk> scoreAndFilter(int threshold) {
        final scored = otcChunks!
            .map((c) {
              final score = c.keywords.toSet().intersection(tokens).length;
              return FirstAidChunk(
                id: c.id,
                title: c.title,
                content: c.content,
                topic: c.topic,
                source: c.source,
                page: c.page,
                keywords: c.keywords,
                imageUrls: c.imageUrls,
                matchScore: score,
              );
            })
            .where((c) => c.matchScore >= threshold)
            .toList();
        scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        return scored;
      }

      // Require at least [minScore] overlapping keywords by default — a
      // single shared generic word (eg, "relief", "pain") was previously
      // enough to surface completely unrelated products (an antacid or
      // cough lozenge showing up for a skin abrasion). Only fall back to a
      // looser single-keyword match if that stricter pass finds nothing,
      // so a category still gets *some* suggestions rather than none.
      final strict = scoreAndFilter(minScore);
      final results = strict.isNotEmpty ? strict : scoreAndFilter(1);
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('FirstAidContentService.searchOtcMedications error: $e');
      return [];
    }
  }
}
