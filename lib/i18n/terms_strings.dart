import 'package:flutter/widgets.dart';
import 'app_language.dart';
import 'legal_content.dart';

/// One block of the Terms & Conditions: a heading, then an optional
/// paragraph and/or a bullet list (in that order).
///
/// [subheader] draws the heading one level down (a heading inside a main
/// section); [warning] draws the paragraph as a boxed notice, for the
/// disclaimers that must stand out. An empty [header] draws no heading (the
/// opening paragraph).
class TermsSection {
  final String header;
  final bool subheader;
  final String? paragraph;
  final bool warning;
  final List<String> bullets;

  const TermsSection({
    required this.header,
    this.subheader = false,
    this.paragraph,
    this.warning = false,
    this.bullets = const [],
  });
}

/// Terms & Conditions screen text. The body is the same whatever the app
/// language is: "WITH TAGALOG TRANSLATION.pdf", word for word, each English
/// paragraph followed by its Filipino translation (see legal_content.dart).
/// Only the title and the buttons follow the app language.
class TermsStrings {
  final String title;
  final String scrollHint;
  final String agree;
  final String saveError;
  final List<TermsSection> sections;

  const TermsStrings({
    required this.title,
    required this.scrollHint,
    required this.agree,
    required this.saveError,
    required this.sections,
  });

  static TermsStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  static const en = TermsStrings(
    title: 'Terms & Conditions',
    scrollHint: 'Please scroll to the end to continue.',
    agree: 'I Agree & Continue',
    saveError: 'Could not save your acceptance. Please try again.',
    sections: kTermsSections,
  );

  static const tl = TermsStrings(
    title: 'Mga Tuntunin at Kundisyon',
    scrollHint: 'Mag-scroll hanggang dulo para makapagpatuloy.',
    agree: 'Sumasang-ayon Ako at Magpatuloy',
    saveError: 'Hindi na-save ang iyong pagsang-ayon. Pakisubukang muli.',
    sections: kTermsSections,
  );
}
