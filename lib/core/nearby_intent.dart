/// Whether a chat message is asking where to find healthcare near them — a
/// hospital, clinic, doctor, pharmacy, emergency room or similar — in English
/// or Tagalog. Needs BOTH a facility word and a "where / near / find" cue, so
/// "should I see a doctor?" is not taken as a location question.
bool asksForNearbyHealthcare(String message) {
  final text = message.toLowerCase();

  const facilities = [
    'hospital',
    'clinic',
    'doctor',
    'physician',
    'pharmacy',
    'drugstore',
    'drug store',
    'emergency room',
    'emergency department',
    'health center',
    'health centre',
    'medical center',
    'urgent care',
    'healthcare',
    'health care',
    // Tagalog
    'ospital',
    'klinika',
    'doktor',
    'botika',
    'health center',
  ];
  const cues = [
    'where',
    'near',
    'nearest',
    'closest',
    'find',
    'locate',
    'looking for',
    'directions',
    'saan',
    'malapit',
    'hanap',
    'pwede bang puntahan',
  ];
  // "er" on its own (emergency room) needs word boundaries.
  final hasEr = RegExp(r'\ber\b').hasMatch(text);

  final hasFacility = hasEr || facilities.any(text.contains);
  final hasCue = cues.any(text.contains);
  return hasFacility && hasCue;
}
