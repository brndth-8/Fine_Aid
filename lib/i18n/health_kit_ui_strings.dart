import 'health_kit_locale.dart';

/// Static (non-content) UI labels on the First Aid Health Kit screen,
/// keyed by a short semantic key rather than the English sentence so a
/// later English wording change can't silently break the Tagalog lookup.
class HealthKitStrings {
  static const Map<String, String> _en = {
    'bannerBody':
        'A pre-loaded library for basic first aid guidance. Works '
        'completely offline - no Wi-Fi or data needed.',
    'categoryPrompt': 'What type of injury do you need help with?',
    'categoryHint': 'Select an injury type',
    'concernLabel': 'Describe your concern (optional)',
    'concernHint': 'eg, "The scratch is still painful after three days."',
    'startQuestions': 'Start Questions',
    'questionDialogTitle': 'Question {n} of {total}',
    'yes': 'Yes',
    'no': 'No',
    'redFlagInterstitialTitle': 'Professional Consultation Recommended',
    'continueLabel': 'Continue',
    'yourConcern': 'Your Concern',
    'redFlagSummary':
        'Based on your answers, this may need professional evaluation. '
        'The steps below are basic first aid only — please also seek '
        'medical care.',
    'basicFirstAidSteps': 'Basic First Aid Steps',
    'watchFor': 'Watch For',
    'seekCareIfPrefix': 'Seek professional care if: ',
    'resultDisclaimer':
        'This is general first aid guidance based on your answers, not '
        'a medical diagnosis or a substitute for professional care.',
    'savedToJournal': 'Saved to Health Journal',
    'saveToJournal': 'Save to Health Journal',
    'updateJournalEntry': 'Update Journal Entry',
    'saving': 'Saving...',
    'askFollowUp': 'Ask a follow-up question',
    'followUpSubtitle':
        'Optional - type or record your question. Recording and '
        "transcribing work offline; getting an answer still needs an "
        'internet connection.',
    'followUpHint': 'Ask a follow-up question...',
    'chooseDifferentInjury': 'Choose a Different Injury',
    'languageToggleLabel': 'Language',
  };

  static const Map<String, String> _tl = {
    'bannerBody':
        'Isang naka-preload na sanggunian para sa pangunahing first aid. '
        'Gumagana nang lubusang offline - hindi kailangan ng Wi-Fi o data.',
    'categoryPrompt':
        'Anong uri ng sugat o problema ang kailangan mo ng tulong?',
    'categoryHint': 'Pumili ng uri ng sugat',
    'concernLabel': 'Ilarawan ang iyong alalahanin (opsyonal)',
    'concernHint':
        'hal, "Masakit pa rin ang kalmot kahit tatlong araw na ang nakalipas."',
    'startQuestions': 'Simulan ang mga Tanong',
    'questionDialogTitle': 'Tanong {n} ng {total}',
    'yes': 'Oo',
    'no': 'Hindi',
    'redFlagInterstitialTitle':
        'Inirerekomenda ang Konsultasyon sa Propesyonal',
    'continueLabel': 'Magpatuloy',
    'yourConcern': 'Ang Iyong Alalahanin',
    'redFlagSummary':
        'Batay sa iyong mga sagot, maaaring kailanganin nito ang pagsusuri '
        'ng propesyonal. Ang mga hakbang sa ibaba ay pangunahing first '
        'aid lamang — mangyaring humingi rin ng medikal na tulong.',
    'basicFirstAidSteps': 'Pangunahing Hakbang sa First Aid',
    'watchFor': 'Bantayan',
    'seekCareIfPrefix': 'Humingi ng tulong medikal kung: ',
    'resultDisclaimer':
        'Ito ay pangkalahatang gabay sa first aid batay sa iyong mga '
        'sagot, hindi isang medikal na diagnosis o kapalit ng '
        'propesyonal na pangangalaga.',
    'savedToJournal': 'Na-save sa Health Journal',
    'saveToJournal': 'I-save sa Health Journal',
    'updateJournalEntry': 'I-update ang Journal Entry',
    'saving': 'Sine-save...',
    'askFollowUp': 'Magtanong ng karagdagang tanong',
    'followUpSubtitle':
        'Opsyonal - i-type o i-record ang iyong tanong. Gumagana offline '
        'ang pag-record at pag-transcribe; kailangan pa rin ng internet '
        'para makakuha ng sagot.',
    'followUpHint': 'Magtanong ng karagdagang tanong...',
    'chooseDifferentInjury': 'Pumili ng Ibang Sugat',
    'languageToggleLabel': 'Wika',
  };

  static String of(String key, HealthKitLocale locale) {
    final map = locale == HealthKitLocale.tl ? _tl : _en;
    return map[key] ?? _en[key] ?? key;
  }

  static String questionDialogTitle(int n, int total, HealthKitLocale locale) {
    return of(
      'questionDialogTitle',
      locale,
    ).replaceFirst('{n}', '$n').replaceFirst('{total}', '$total');
  }
}
