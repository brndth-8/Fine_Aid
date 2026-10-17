import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../i18n/checklist_strings.dart';

class HealthChecklistScreen extends StatefulWidget {
  const HealthChecklistScreen({super.key});

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

const Color _maroon = Color(0xFF780000);
const Color _cardTint = Color(0xFFF9EFEF);
const Color _iconTint = Color(0xFFF6D9D9);

class _HealthChecklistScreenState extends State<HealthChecklistScreen> {
  bool _diabetes = false;
  bool _hemophilia = false;
  final Set<String> _allergies = {};
  bool _allergiesExpanded = false;
  bool _noneOfTheAbove = false;
  bool _isLoading = false;

  // Any selected allergy type means "has allergies" — the same
  // `severeAllergies` flag the rest of the app reads.
  bool get _hasAllergies => _allergies.isNotEmpty;

  void _toggleNoneOfTheAbove(bool? value) {
    setState(() {
      _noneOfTheAbove = value ?? false;
      if (_noneOfTheAbove) {
        _diabetes = false;
        _hemophilia = false;
        _allergies.clear();
      }
    });
  }

  void _toggleCondition(void Function(bool) setter, bool? value) {
    setState(() {
      setter(value ?? false);
      if (value == true) _noneOfTheAbove = false;
    });
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
                'hemophiliaOrBloodDisorders': _hemophilia,
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
        await AuthService().markOnboardingComplete(user.uid);
      }

      if (!mounted) return;
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
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _cardTint,
          borderRadius: BorderRadius.circular(18),
          border: _allergiesExpanded
              ? Border.all(color: _maroon, width: 1.4)
              : null,
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  setState(() => _allergiesExpanded = !_allergiesExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    _iconBox(Icons.coronavirus_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.commonAllergies,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.severeAllergiesInfo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _allergiesExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _maroon,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            if (_allergiesExpanded)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _allergyTypes.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.grey),
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
                              child: Text(
                                _allergyLabel(s, _allergyTypes[i].$1),
                                style: theme.textTheme.bodyMedium,
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
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ChecklistStrings.of(context);
    final canContinue =
        _diabetes || _hemophilia || _hasAllergies || _noneOfTheAbove;

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
                    _conditionTile(
                      icon: Icons.water_drop_outlined,
                      title: s.diabetes,
                      description: s.diabetesInfo,
                      value: _diabetes,
                      onChanged: (v) =>
                          _toggleCondition((val) => _diabetes = val, v),
                    ),
                    _conditionTile(
                      icon: Icons.bloodtype_outlined,
                      title: s.hemophilia,
                      description: s.hemophiliaInfo,
                      value: _hemophilia,
                      onChanged: (v) =>
                          _toggleCondition((val) => _hemophilia = val, v),
                    ),
                    _allergyGroup(s),
                    _conditionTile(
                      icon: Icons.edit_note,
                      title: s.noneOfTheAbove,
                      description: s.noneInfo,
                      value: _noneOfTheAbove,
                      onChanged: _toggleNoneOfTheAbove,
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
                        s.continueButton,
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
