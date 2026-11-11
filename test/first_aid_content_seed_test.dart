import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// seed_firestore/firstAidContent.json is what the seed script writes to the
/// `firstAidContent` collection. The OTC part now comes from "OTC products.pdf".
void main() {
  final chunks =
      (jsonDecode(File('seed_firestore/firstAidContent.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final otc = chunks.where((c) => c['topic'] == 'otc_medication').toList();

  test('every chunk has what the app and the seed script need', () {
    final ids = <String>{};
    for (final c in chunks) {
      expect(ids.add(c['id'] as String), isTrue, reason: 'duplicate ${c['id']}');
      expect(c['id'], matches(RegExp(r'^chunk_\d{4}$')));
      for (final f in ['title', 'content', 'topic', 'source']) {
        expect((c[f] as String).trim(), isNotEmpty, reason: '${c['id']} $f');
      }
      expect(c['keywords'], isA<List>());
      expect((c['keywords'] as List), isNotEmpty, reason: c['id'] as String);
    }
  });

  test('the older 531-product directory is gone; the PDF items replace it', () {
    expect(chunks.length, 157);
    expect(otc.length, 21);
    expect(
      chunks.where((c) => c['source'] == 'Non-Rx OTC Medicines Directory'),
      isEmpty,
    );
    final titles = otc.map((c) => c['title'] as String).join('|');
    for (final name in ['BIOGESIC', 'ADVIL', 'BETADINE WOUND SOLUTION',
        'Roller bandage', 'Triangular bandage or cravat']) {
      expect(titles, contains(name));
    }
    // the first-aid manual and WHO chunks are untouched
    expect(chunks.where((c) => c['topic'] != 'otc_medication').length, 136);
  });

  test('repeated PDF entries are stored once and prices are left out', () {
    final titles = otc.map((c) => c['title'] as String).toList();
    expect(titles.toSet().length, titles.length);
    expect(titles.where((t) => t.startsWith('HANSOL')).length, 1);
    expect(titles.where((t) => t.startsWith('SANISCRUB')).length, 1);
    for (final c in otc) {
      expect(c['content'], isNot(matches(RegExp(r'\(P[0-9]'))), reason: c['id'] as String);
    }
  });

  test('the Rx / Non-Rx note travels with each medicine', () {
    final meds = otc.where((c) => (c['source'] as String).startsWith('MIMS'));
    expect(meds.length, 11);
    for (final c in meds) {
      expect(c['content'], contains('Non-Rx'), reason: c['id'] as String);
      expect(c['content'], contains('Composition:'), reason: c['id'] as String);
    }
    final allermed = otc.firstWhere((c) => (c['title'] as String).startsWith('ALLERMED'));
    expect(allermed['content'], contains('Oral soln: Rx'));
  });

  test('the file is compact (was about 1 MB with the old directory)', () {
    expect(File('seed_firestore/firstAidContent.json').lengthSync(), lessThan(300 * 1024));
  });
}
