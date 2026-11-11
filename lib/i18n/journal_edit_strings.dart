import 'package:flutter/widgets.dart';
import 'app_language.dart';

/// Text for the journal entry menu (Edit / Delete) and the Edit entry screen,
/// English + Tagalog. Review the Tagalog before release.
class JournalEditStrings {
  final String menuTooltip;
  final String edit;
  final String delete;
  final String editTitle;
  final String titleLabel;
  final String notesLabel;
  final String photosLabel;
  final String photosHint;
  final String newPhoto;
  final String titleRequired;
  final String save;
  final String saving;
  final String saved;
  final String saveFailed;
  final String photosCount; // uses {n}

  const JournalEditStrings({
    required this.menuTooltip,
    required this.edit,
    required this.delete,
    required this.editTitle,
    required this.titleLabel,
    required this.notesLabel,
    required this.photosLabel,
    required this.photosHint,
    required this.newPhoto,
    required this.titleRequired,
    required this.save,
    required this.saving,
    required this.saved,
    required this.saveFailed,
    required this.photosCount,
  });

  static JournalEditStrings of(BuildContext context) =>
      AppLanguageScope.isTagalog(context) ? tl : en;

  String photosCountFormat(int n) => photosCount.replaceFirst('{n}', '$n');

  static const en = JournalEditStrings(
    menuTooltip: 'More options',
    edit: 'Edit',
    delete: 'Delete',
    editTitle: 'Edit entry',
    titleLabel: 'Title',
    notesLabel: 'Notes',
    photosLabel: 'Photos',
    photosHint:
        'Add a new photo from time to time to keep a visual record of how it '
        'is healing.',
    newPhoto: 'New',
    titleRequired: 'Please enter a title.',
    save: 'Save changes',
    saving: 'Saving...',
    saved: 'Entry updated.',
    saveFailed: 'Could not save your changes. Please try again.',
    photosCount: 'Photos ({n})',
  );

  static const tl = JournalEditStrings(
    menuTooltip: 'Iba pang opsyon',
    edit: 'I-edit',
    delete: 'Burahin',
    editTitle: 'I-edit ang entry',
    titleLabel: 'Pamagat',
    notesLabel: 'Mga tala',
    photosLabel: 'Mga larawan',
    photosHint:
        'Magdagdag ng bagong larawan paminsan-minsan para magkaroon ng '
        'talaan kung paano ito gumagaling.',
    newPhoto: 'Bago',
    titleRequired: 'Maglagay ng pamagat.',
    save: 'I-save ang mga pagbabago',
    saving: 'Sine-save...',
    saved: 'Na-update ang entry.',
    saveFailed: 'Hindi na-save ang iyong mga pagbabago. Pakisubukang muli.',
    photosCount: 'Mga larawan ({n})',
  );
}
