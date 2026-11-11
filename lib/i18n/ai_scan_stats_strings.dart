import 'package:flutter/widgets.dart';
import '../services/ai_scan_stats_service.dart';
import 'app_language.dart';

/// Text for the "About the AI scan" screen and the "Are you satisfied with
/// the result?" prompt, English + Tagalog. Neutral wording only: the numbers
/// describe how often the scan completes, not medical accuracy. Review the
/// Tagalog before release.
class AiScanStatsStrings {
  final String settingsLabel;
  final String screenTitle;
  final String intro;
  final String noDataYet;
  final String totalScans;
  final String completed;
  final String failed;
  final String noWoundFound;
  final String ratedCorrect;
  final String ratedNotCorrect;
  final String successRate;
  final String failureRate;
  final String accuracyRate;
  final String reliability;
  final String scanSummary;
  final String noFeedbackYet;
  final String reliabilityNote;
  final String whyFailed;
  final String guestNote;
  final String feedbackQuestion;
  final String yes;
  final String no;
  final String feedbackThanks;
  final Map<ScanFailureReason, String> reasons;

  const AiScanStatsStrings({
    required this.settingsLabel,
    required this.screenTitle,
    required this.intro,
    required this.noDataYet,
    required this.totalScans,
    required this.completed,
    required this.failed,
    required this.noWoundFound,
    required this.ratedCorrect,
    required this.ratedNotCorrect,
    required this.successRate,
    required this.failureRate,
    required this.accuracyRate,
    required this.reliability,
    required this.scanSummary,
    required this.noFeedbackYet,
    required this.reliabilityNote,
    required this.whyFailed,
    required this.guestNote,
    required this.feedbackQuestion,
    required this.yes,
    required this.no,
    required this.feedbackThanks,
    required this.reasons,
  });

  static AiScanStatsStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  /// "83.3%", or [noDataYet] / [noFeedbackYet] when there is nothing to show.
  String percent(double? value, {String? missing}) =>
      value == null ? (missing ?? noDataYet) : '${value.toStringAsFixed(1)}%';

  static const en = AiScanStatsStrings(
    settingsLabel: 'About the AI scan',
    screenTitle: 'About the AI scan',
    intro:
        'How often the AI scan completes on this account. The AI scan is a '
        'preliminary assessment tool, not a diagnosis.',
    noDataYet: 'No data yet',
    totalScans: 'Scans made',
    completed: 'Completed with a result',
    failed: 'Did not complete',
    noWoundFound: 'No wound found',
    ratedCorrect: 'Satisfied',
    ratedNotCorrect: 'Not satisfied',
    successRate: 'Success rate',
    failureRate: 'Failure rate',
    accuracyRate: 'Satisfaction (of rated scans)',
    reliability: 'Reliability',
    scanSummary: 'Scan Summary',
    noFeedbackYet: 'No feedback yet',
    reliabilityNote:
        'Reliability = scans that completed and were not rated "not '
        'satisfied", out of all scans.',
    whyFailed: 'Why scans did not complete',
    guestNote:
        'Not signed in: these numbers are kept on this phone only. Log in to '
        'keep them with your account.',
    feedbackQuestion: 'Are you satisfied with the result?',
    yes: 'Yes',
    no: 'No',
    feedbackThanks: 'Thanks for the feedback.',
    reasons: {
      ScanFailureReason.offline: 'No internet connection',
      ScanFailureReason.timeout: 'Took too long',
      ScanFailureReason.serverError: 'Service error',
      ScanFailureReason.unreadableResponse: 'Result could not be read',
      ScanFailureReason.unreadableImage: 'Photo could not be read',
      ScanFailureReason.lowConfidence: 'Low confidence in the result',
    },
  );

  static const tl = AiScanStatsStrings(
    settingsLabel: 'Tungkol sa AI scan',
    screenTitle: 'Tungkol sa AI scan',
    intro:
        'Gaano kadalas natatapos ang AI scan sa account na ito. Ang AI scan '
        'ay isang paunang kasangkapan sa pagsusuri, hindi isang diagnosis.',
    noDataYet: 'Wala pang datos',
    totalScans: 'Mga scan na ginawa',
    completed: 'Natapos na may resulta',
    failed: 'Hindi natapos',
    noWoundFound: 'Walang nakitang sugat',
    ratedCorrect: 'Nasiyahan',
    ratedNotCorrect: 'Hindi nasiyahan',
    successRate: 'Rate ng tagumpay',
    failureRate: 'Rate ng pagkabigo',
    accuracyRate: 'Kasiyahan (ng mga na-rate na scan)',
    reliability: 'Pagkakatiwalaan',
    scanSummary: 'Buod ng mga Scan',
    noFeedbackYet: 'Wala pang feedback',
    reliabilityNote:
        'Pagkakatiwalaan = mga scan na natapos at hindi na-rate na "hindi '
        'nasiyahan", mula sa lahat ng scan.',
    whyFailed: 'Bakit hindi natapos ang mga scan',
    guestNote:
        'Hindi naka-sign in: sa teleponong ito lang naka-save ang mga bilang '
        'na ito. Mag-log in para maitago ang mga ito sa iyong account.',
    feedbackQuestion: 'Nasiyahan ka ba sa resulta?',
    yes: 'Oo',
    no: 'Hindi',
    feedbackThanks: 'Salamat sa feedback.',
    reasons: {
      ScanFailureReason.offline: 'Walang koneksyon sa internet',
      ScanFailureReason.timeout: 'Natagalan nang husto',
      ScanFailureReason.serverError: 'Problema sa serbisyo',
      ScanFailureReason.unreadableResponse: 'Hindi mabasa ang resulta',
      ScanFailureReason.unreadableImage: 'Hindi mabasa ang larawan',
      ScanFailureReason.lowConfidence: 'Mababang kumpiyansa sa resulta',
    },
  );
}
