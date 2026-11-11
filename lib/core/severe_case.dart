import '../services/api/gemini_service.dart';

/// A severe or very severe result: an emergency, not first aid. These get a
/// "seek medical consultation immediately" pop-up and a nearby-hospitals
/// button instead of first aid steps. True when the AI marked it an
/// emergency, or saw heavy bleeding or a deep wound (eg exposed flesh).
bool isSevereCase(WoundAssessment a) =>
    a.isWound &&
    a.error == null &&
    (a.triage == TriageLevel.emergency ||
        a.visibleBleeding == 'severe' ||
        a.apparentDepth == 'deep');
