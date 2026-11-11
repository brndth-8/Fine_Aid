import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../i18n/assessment_strings.dart';
import '../../../i18n/checklist_strings.dart';
import '../../../core/widgets/medication_picker.dart';
import '../../../data/health_profile_summary.dart';
import '../../../services/health_profile_service.dart';

class HealthChecklistScreen extends StatefulWidget {
  /// A saved Health Profile to start from. When given, the screen edits that
  /// profile (it saves and goes back) instead of being the first-time setup.
  final Map<String, dynamic>? initialProfile;

  const HealthChecklistScreen({super.key, this.initialProfile});

  bool get isEditing => initialProfile != null;

  @override
  State<HealthChecklistScreen> createState() => _HealthChecklistScreenState();
}

// The allergy types under "Common Allergies": the stored id and its icon.
const List<(String, IconData)> _allergyTypes = [
  ('rhinitis', Icons.local_florist_outlined),
  ('food', Icons.restaurant),
  ('skin', Icons.back_hand),
  ('insect', Icons.bug_report_outlined),
  ('drug', Icons.medication_outlined),
  ('latex', Icons.pan_tool_outlined),
];

// Diabetes types (single choice). The stored id is saved as
// `healthProfile.diabetesType`.
const List<String> _diabetesTypes = [
  'type1',
  'type2',
  'gestational',
  'prediabetes',
];

// Blood disorder types (single choice). The stored id is saved as
// `healthProfile.bloodDisorderType`.
const List<String> _bloodDisorderTypes = ['hemophiliaA', 'other'];

const Color _maroon = Color(0xFF780000);
const Color _cardTint = Color(0xFFF9EFEF);
const Color _iconTint = Color(0xFFF6D9D9);

class _HealthChecklistScreenState extends State<HealthChecklistScreen> {
  bool _diabetes = false;
  String? _diabetesType;
  bool _hemophilia = false;
  String? _bloodDisorderType;
  // "Other": a condition that is not listed, typed in by the user.
  bool _otherCondition = false;
  final _otherController = TextEditingController();
  List<String> _medications = [];
  final Set<String> _allergies = {};
  bool _allergiesExpanded = false;
  bool _diabetesExpanded = false;
  bool _bloodExpanded = false;
  bool _noneOfTheAbove = false;
  bool _isLoading = false;

  // Any selected allergy type means "has allergies" — the same
  // `severeAllergies` flag the rest of the app reads.
  bool get _hasAllergies => _allergies.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final saved = widget.initialProfile;
    if (saved != null) _loadFrom(saved);
  }

  // Starts the form from a saved profile. A saved type that is no longer an
  // option (eg an old answer that is no longer offered) counts as unanswered,
  // so the person can pick a real one.
  void _loadFrom(Map<String, dynamic> saved) {
    _diabetes = saved['diabetes'] == true;
    final diabetesType = saved['diabetesType'];
    _diabetesType = _diabetesTypes.contains(diabetesType)
        ? diabetesType as String
        : null;
    _hemophilia = saved['hemophiliaOrBloodDisorders'] == true;
    final bloodType = saved['bloodDisorderType'];
    _bloodDisorderType = _bloodDisorderTypes.contains(bloodType)
        ? bloodType as String
        : null;
    final known = _allergyTypes.map((a) => a.$1).toSet();
    _allergies.addAll(
      ((saved['allergyTypes'] as List?) ?? const [])
          .map((e) => '$e')
          .where(known.contains),
    );
    _allergiesExpanded = _allergies.isNotEmpty;
    _diabetesExpanded = _diabetes;
    _bloodExpanded = _hemophilia;
    final other = (saved['otherCondition'] as String?)?.trim();
    if (other != null && other.isNotEmpty) {
      _otherCondition = true;
      _otherController.text = other;
    }
    _noneOfTheAbove =
        saved['noneOfTheAbove'] == true &&
        !(_diabetes || _hemophilia || _hasAllergies || _otherCondition);
    _medications = profileMedications(saved);
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _toggleNoneOfTheAbove(bool? value) {
    setState(() {
      _noneOfTheAbove = value ?? false;
      if (_noneOfTheAbove) {
        _diabetes = false;
        _diabetesType = null;
        _hemophilia = false;
        _bloodDisorderType = null;
        _otherCondition = false;
        _otherController.clear();
        _allergies.clear();
      }
    });
  }

  // Diabetes / blood disorders are chosen by picking one of their types (tap
  // the chosen one again to clear it). A saved profile that has the condition
  // but no type shows a row of its own to uncheck.
  void _pickDiabetesType(String id) {
    final had = _diabetes;
    setState(() {
      if (_diabetesType == id) {
        _diabetes = false;
        _diabetesType = null;
      } else {
        _diabetes = true;
        _diabetesType = id;
        _noneOfTheAbove = false;
      }
    });
    if (!had && _diabetes) _showDisclaimer();
  }

  void _pickBloodType(String id) {
    final had = _hemophilia;
    setState(() {
      if (_bloodDisorderType == id) {
        _hemophilia = false;
        _bloodDisorderType = null;
      } else {
        _hemophilia = true;
        _bloodDisorderType = id;
        _noneOfTheAbove = false;
      }
    });
    if (!had && _hemophilia) _showDisclaimer();
  }

  // The "specify your health condition" box: a typed condition counts as
  // "other".
  void _otherChanged(String text) {
    setState(() {
      _otherCondition = text.trim().isNotEmpty;
      if (_otherCondition) _noneOfTheAbove = false;
    });
  }

  // One shared pop-up for every condition that gets checked (never on
  // uncheck). It only informs: the selection is already made, saving isn't
  // blocked, and it is shown one at a time.
  bool _disclaimerOpen = false;
  Future<void> _showDisclaimer() async {
    if (_disclaimerOpen || !mounted) return;
    _disclaimerOpen = true;
    final s = ChecklistStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(s.disclaimer),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.disclaimerOk),
          ),
        ],
      ),
    );
    _disclaimerOpen = false;
  }

  void _toggleAllergy(String id, bool? value) {
    setState(() {
      if (value == true) {
        _allergies.add(id);
        _noneOfTheAbove = false;
      } else {
        _allergies.remove(id);
      }
    });
    if (value == true) _showDisclaimer();
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'healthProfile': {
                'diabetes': _diabetes,
                // Which type, when one was chosen (null otherwise).
                'diabetesType': _diabetes ? _diabetesType : null,
                'hemophiliaOrBloodDisorders': _hemophilia,
                // Which blood disorder, when one was chosen (null otherwise).
                'bloodDisorderType': _hemophilia ? _bloodDisorderType : null,
                // A condition the user typed because it was not listed.
                'otherCondition': _otherCondition
                    ? _otherController.text.trim()
                    : null,
                'medications': _medications,
                'severeAllergies': _hasAllergies,
                // Which kinds of allergy (an addition; the flag above is
                // what the rest of the app reads).
                'allergyTypes': _allergies.toList(),
                'noneOfTheAbove': _noneOfTheAbove,
              },
              'healthProfileSavedAt': FieldValue.serverTimestamp(),
              'healthProfileComplete': true,
            })
            .timeout(const Duration(seconds: 10));
        if (!widget.isEditing) {
          await AuthService().markOnboardingComplete(user.uid);
        }
      }

      if (!mounted) return;
      if (widget.isEditing) {
        // Edited from the Profile: show the new answers there.
        HealthProfileService().clear();
        Navigator.pop(context, true);
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
        arguments: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChecklistStrings.of(context).saveError)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _checkbox(bool value, void Function(bool?) onChanged) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: _maroon,
      side: BorderSide(color: Colors.grey.shade600, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _iconTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _maroon, size: 22),
    );
  }

  Widget _conditionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required void Function(bool?) onChanged,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardTint,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    _iconBox(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _checkbox(value, onChanged),
                  ],
                ),
              ),
            ),
            ?extra,
          ],
        ),
      ),
    );
  }

  (String, String) _diabetesTypeText(ChecklistStrings s, String id) =>
      switch (id) {
        'type1' => (s.diabetesType1, s.diabetesType1Info),
        'type2' => (s.diabetesType2, s.diabetesType2Info),
        'gestational' => (s.diabetesGestational, s.diabetesGestationalInfo),
        _ => (s.diabetesPrediabetes, s.diabetesPrediabetesInfo),
      };

  (String, String) _bloodDisorderTypeText(ChecklistStrings s, String id) =>
      switch (id) {
        'hemophiliaA' => (s.hemophiliaA, s.hemophiliaAInfo),
        _ => (s.bloodDisorderOther, s.bloodDisorderOtherInfo),
      };

  /// A beige card that opens (chevron) to a white list. The open card gets a
  /// maroon outline; a closed one that has something chosen shows a tick.
  Widget _accordion({
    required IconData icon,
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget body,
    String? description,
    bool chosen = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _cardTint,
          borderRadius: BorderRadius.circular(18),
          border: expanded ? Border.all(color: _maroon, width: 1.4) : null,
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _iconBox(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.black,
                            ),
                          ),
                          if (description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (chosen && !expanded)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle,
                          color: _maroon,
                          size: 20,
                        ),
                      ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _maroon,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: body,
              ),
          ],
        ),
      ),
    );
  }

  /// The white list inside a condition: one checkbox row per type (a name and
  /// a line about it). [unspecifiedLabel] adds a first, ticked row for a saved
  /// condition that has no type, so it can still be unticked.
  Widget _typeRows({
    required List<String> ids,
    required String? selected,
    required (String, String) Function(String id) textOf,
    required ValueChanged<String> onPick,
    String? unspecifiedLabel,
    VoidCallback? onClearUnspecified,
  }) {
    final theme = Theme.of(context);
    Widget row(String title, String? info, bool value, VoidCallback onTap) =>
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyMedium),
                      if (info != null)
                        Text(
                          info,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _checkbox(value, (_) => onTap()),
            ],
          ),
        );
    final rows = <Widget>[
      if (unspecifiedLabel != null)
        row(unspecifiedLabel, null, true, onClearUnspecified ?? () {}),
      for (final id in ids)
        row(textOf(id).$1, textOf(id).$2, selected == id, () => onPick(id)),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: Colors.grey.shade400),
          rows[i],
        ],
      ],
    );
  }

  // "Please specify your health condition/s": a pill box, always shown.
  Widget _specifyCondition(ChecklistStrings s) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.specifyCondition,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherController,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _otherChanged,
            decoration: InputDecoration(
              hintText: s.specifyConditionHint,
              counterText: '',
              fillColor: const Color(0xFFF1F1F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  String _allergyLabel(ChecklistStrings s, String id) => switch (id) {
    'rhinitis' => s.allergyRhinitis,
    'food' => s.allergyFood,
    'skin' => s.allergySkin,
    'insect' => s.allergyInsect,
    'drug' => s.allergyDrug,
    _ => s.allergyLatex,
  };

  // "Common Allergies": a card that opens to the six allergy types.
  Widget _allergyGroup(ChecklistStrings s) {
    final theme = Theme.of(context);
    return _accordion(
      icon: Icons.coronavirus_outlined,
      title: s.commonAllergies,
      description: s.severeAllergiesInfo,
      expanded: _allergiesExpanded,
      chosen: _hasAllergies,
      onTap: () => setState(() => _allergiesExpanded = !_allergiesExpanded),
      body: Column(
        children: [
          for (var i = 0; i < _allergyTypes.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade400),
            InkWell(
              onTap: () => _toggleAllergy(
                _allergyTypes[i].$1,
                !_allergies.contains(_allergyTypes[i].$1),
              ),
              child: Row(
                children: [
                  Icon(_allergyTypes[i].$2, color: _maroon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _allergyLabel(s, _allergyTypes[i].$1),
                          style: theme.textTheme.bodyMedium,
                        ),
                        // Examples help people recognise what counts as a
                        // food allergy.
                        if (_allergyTypes[i].$1 == 'food')
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              s.foodAllergyExamples,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _checkbox(
                    _allergies.contains(_allergyTypes[i].$1),
                    (v) => _toggleAllergy(_allergyTypes[i].$1, v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ChecklistStrings.of(context);
    final a = AssessmentStrings.of(context);
    final hasCondition =
        _diabetes ||
        _hemophilia ||
        _hasAllergies ||
        _noneOfTheAbove ||
        _otherCondition;
    // "Other" needs its condition typed before Continue.
    final canContinue =
        hasCondition &&
        (!_otherCondition || _otherController.text.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isEditing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    Center(
                      child: Image.asset(
                        'assets/images/FINE_AID_Logo.png',
                        width: 220,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      s.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(s.intro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 18),
                    _accordion(
                      icon: Icons.water_drop_outlined,
                      title: s.diabetes,
                      description: s.diabetesInfo,
                      expanded: _diabetesExpanded,
                      chosen: _diabetes,
                      onTap: () => setState(
                        () => _diabetesExpanded = !_diabetesExpanded,
                      ),
                      body: _typeRows(
                        ids: _diabetesTypes,
                        selected: _diabetesType,
                        textOf: (id) => _diabetesTypeText(s, id),
                        onPick: _pickDiabetesType,
                        unspecifiedLabel: _diabetes && _diabetesType == null
                            ? s.diabetes
                            : null,
                        onClearUnspecified: () =>
                            setState(() => _diabetes = false),
                      ),
                    ),
                    _accordion(
                      icon: Icons.bloodtype_outlined,
                      title: s.hemophilia,
                      description: s.hemophiliaInfo,
                      expanded: _bloodExpanded,
                      chosen: _hemophilia,
                      onTap: () =>
                          setState(() => _bloodExpanded = !_bloodExpanded),
                      body: _typeRows(
                        ids: _bloodDisorderTypes,
                        selected: _bloodDisorderType,
                        textOf: (id) => _bloodDisorderTypeText(s, id),
                        onPick: _pickBloodType,
                        unspecifiedLabel:
                            _hemophilia && _bloodDisorderType == null
                            ? s.hemophilia
                            : null,
                        onClearUnspecified: () =>
                            setState(() => _hemophilia = false),
                      ),
                    ),
                    _allergyGroup(s),
                    _specifyCondition(s),
                    _conditionTile(
                      icon: Icons.edit_note,
                      title: s.noneOfTheAbove,
                      description: s.noneInfo,
                      value: _noneOfTheAbove,
                      onChanged: _toggleNoneOfTheAbove,
                    ),
                    _sectionHeading(a.medicationsTitle),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        s.medicationsInfo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    MedicationPicker(
                      selected: _medications,
                      onChanged: (list) => setState(() => _medications = list),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _iconTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: _maroon,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.privacyTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.privacy,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Continue stays at the bottom of the screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: (_isLoading || !canContinue)
                    ? null
                    : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEditing ? s.saveChanges : s.continueButton,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: canContinue ? Colors.white : null,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
