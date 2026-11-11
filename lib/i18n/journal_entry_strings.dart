import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the Health Journal "Add new entry" screen (the redesigned form,
/// the category pop-ups and the Injury type choice), English + Tagalog.
/// Category and Deep/Minor *explanations* live in classification_strings.dart
/// (one source for the whole app); pain wording is in pain_strings.dart.
/// Review the Tagalog before release.
class JournalEntryStrings {
  final String screenTitle;
  final String addImageSubtitle;
  final String titleLabel;
  final String titleHint;
  final String dateLabel;
  final String feelingLabel;
  final String feelingHint;
  final String categoryHeading;
  final String save;
  final String cancel;
  final String confirm;

  final String injuryTypeTitle;
  final String injuryTypePrompt;
  final String deep;
  final String minor;
  // Add Entry > Injury > Deep: what the "Deep" choice describes.
  final String deepDescription;
  // The "Professional care recommended" pop-up (Injury > Deep).
  final String careTitle;
  final String careBody;
  final String careNote;
  final String careContinue;
  final String selectedFormat; // {category}

  final String titleRequired;
  final String categoryRequired;
  final String painRequired;
  final String itchRequired;
  final String saveFailed;

  /// Display names of the four journal categories. The stored value (the
  /// map key, English) never changes — only what is shown.
  final Map<String, String> categoryNames;
  final String injurySubtitle;

  final List<String> weekdays; // Monday..Sunday
  final List<String> months; // January..December

  // Journal list date filter.
  final String filterByDate;
  final String clearFilter;
  final String noEntriesInRange;

  const JournalEntryStrings({
    required this.screenTitle,
    required this.addImageSubtitle,
    required this.titleLabel,
    required this.titleHint,
    required this.dateLabel,
    required this.feelingLabel,
    required this.feelingHint,
    required this.categoryHeading,
    required this.save,
    required this.cancel,
    required this.confirm,
    required this.injuryTypeTitle,
    required this.injuryTypePrompt,
    required this.deep,
    required this.minor,
    required this.deepDescription,
    required this.careTitle,
    required this.careBody,
    required this.careNote,
    required this.careContinue,
    required this.selectedFormat,
    required this.titleRequired,
    required this.categoryRequired,
    required this.painRequired,
    required this.itchRequired,
    required this.saveFailed,
    required this.categoryNames,
    required this.injurySubtitle,
    required this.weekdays,
    required this.months,
    required this.filterByDate,
    required this.clearFilter,
    required this.noEntriesInRange,
  });

  static JournalEntryStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  /// "Sunday, October 11".
  String formatDate(DateTime d) =>
      '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';

  /// Shown name of a stored Deep / Minor value.
  String subTypeName(String? value) =>
      value == 'Deep' ? deep : (value == 'Minor' ? minor : '');

  static const en = JournalEntryStrings(
    screenTitle: 'Health Journal',
    addImageSubtitle: 'Take or choose a photo of your condition',
    titleLabel: 'Title',
    titleHint: 'Add Title',
    dateLabel: 'Date',
    feelingLabel: 'How are you feeling today?',
    feelingHint: 'Write your thoughts, symptoms, or how you feel...',
    categoryHeading: 'Category',
    save: 'Save Entry',
    cancel: 'Cancel',
    confirm: 'Confirm',
    injuryTypeTitle: 'Injury type',
    injuryTypePrompt: 'Choose the one that best describes your injury.',
    deep: 'Deep',
    minor: 'Minor',
    deepDescription:
        'The wound is deep, and fat or muscle may be partly visible. The '
        'edges of the wound are gaping apart. Bleeding continues even after '
        '10 minutes of firm pressure, or the wound was caused by a dirty or '
        'sharp object that pierced the skin.',
    careTitle: 'Professional care recommended',
    careBody:
        'We recommend seeking professional medical help to ensure proper '
        'care.',
    careNote:
        'You can use this journal to monitor your recovery and track your '
        'aftercare.',
    careContinue: 'Continue to journal',
    selectedFormat: 'Selected: {category}',
    titleRequired: 'Please add a title.',
    categoryRequired: 'Please select a category.',
    painRequired: 'Please rate your pain.',
    itchRequired: 'Please rate your itchiness.',
    saveFailed: 'Could not save entry. Please try again.',
    categoryNames: {
      'Injury (Wounds/laceration/Abrasion)': 'Injury',
      'Burns': 'Burns',
      'Skin Issues': 'Skin Issues',
      'Scratch': 'Scratch',
      'Animal Scratch': 'Animal Scratch',
    },
    injurySubtitle: '(Wounds, Laceration/ Abrasion)',
    filterByDate: 'Filter by date',
    clearFilter: 'Clear date filter',
    noEntriesInRange: 'No entries in this date range.',
    weekdays: [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    months: [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
  );

  static const tl = JournalEntryStrings(
    screenTitle: 'Health Journal',
    addImageSubtitle: 'Kumuha o pumili ng larawan ng iyong kondisyon',
    titleLabel: 'Pamagat',
    titleHint: 'Magdagdag ng Pamagat',
    dateLabel: 'Petsa',
    feelingLabel: 'Kumusta ang pakiramdam mo ngayon?',
    feelingHint:
        'Isulat ang iyong iniisip, mga sintomas, o kung ano ang '
        'nararamdaman mo...',
    categoryHeading: 'Kategorya',
    save: 'I-save ang Entry',
    cancel: 'Kanselahin',
    confirm: 'Kumpirmahin',
    injuryTypeTitle: 'Uri ng pinsala',
    injuryTypePrompt: 'Piliin ang pinakaangkop sa iyong pinsala.',
    deep: 'Malalim',
    minor: 'Maliit',
    deepDescription:
        'Malalim ang sugat at maaaring bahagyang makita ang taba o kalamnan. '
        'Nakabuka ang mga gilid ng sugat. Patuloy ang pagdurugo kahit '
        'nadiinan na ito nang 10 minuto, o dulot ito ng marumi o matulis na '
        'bagay na bumaon sa balat.',
    careTitle: 'Inirerekomenda ang propesyonal na pangangalaga',
    careBody:
        'Inirerekomenda naming humingi ng tulong medikal mula sa propesyonal '
        'para masiguro ang tamang pangangalaga.',
    careNote:
        'Maaari mong gamitin ang journal na ito para subaybayan ang iyong '
        'paggaling at ang iyong aftercare.',
    careContinue: 'Magpatuloy sa journal',
    selectedFormat: 'Napili: {category}',
    titleRequired: 'Magdagdag ng pamagat.',
    categoryRequired: 'Pumili ng kategorya.',
    painRequired: 'I-rate ang iyong sakit.',
    itchRequired: 'I-rate ang iyong pangangati.',
    saveFailed: 'Hindi ma-save ang entry. Pakisubukan muli.',
    categoryNames: {
      'Injury (Wounds/laceration/Abrasion)': 'Pinsala',
      'Burns': 'Paso',
      'Skin Issues': 'Problema sa Balat',
      'Scratch': 'Kalmot',
      'Animal Scratch': 'Kalmot ng Hayop',
    },
    injurySubtitle: '(Sugat, Hiwa/ Galos)',
    filterByDate: 'I-filter ayon sa petsa',
    clearFilter: 'I-clear ang filter ng petsa',
    noEntriesInRange: 'Walang entry sa saklaw ng petsang ito.',
    weekdays: [
      'Lunes',
      'Martes',
      'Miyerkules',
      'Huwebes',
      'Biyernes',
      'Sabado',
      'Linggo',
    ],
    months: [
      'Enero',
      'Pebrero',
      'Marso',
      'Abril',
      'Mayo',
      'Hunyo',
      'Hulyo',
      'Agosto',
      'Setyembre',
      'Oktubre',
      'Nobyembre',
      'Disyembre',
    ],
  );
}
