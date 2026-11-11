import 'package:flutter/material.dart';
import '../../data/medications.dart';
import '../../i18n/assessment_strings.dart';

/// Adds [name] to [list] (trimmed, single spaces) unless it is blank or
/// already there (not case sensitive). Returns a new list.
List<String> withMedication(List<String> list, String name) {
  final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return list;
  if (list.any((m) => m.toLowerCase() == clean.toLowerCase())) return list;
  return [...list, clean.length > 60 ? clean.substring(0, 60) : clean];
}

/// "Medications you are taking": the user types a name, the list below the
/// field narrows to matching medicines (see data/medications.dart) and a tap
/// adds one. A name that is not in the list can be added as typed. What was
/// added shows as removable chips.
class MedicationPicker extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MedicationPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<MedicationPicker> createState() => _MedicationPickerState();
}

class _MedicationPickerState extends State<MedicationPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String name) {
    widget.onChanged(withMedication(widget.selected, name));
    setState(_controller.clear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AssessmentStrings.of(context);
    final typed = _controller.text.trim();
    final matches = searchMedications(typed, exclude: widget.selected);
    final alreadyChosen = widget.selected.any(
      (m) => m.toLowerCase() == typed.toLowerCase(),
    );
    // Offer the typed text itself when it is not an exact known name.
    final canAddTyped =
        typed.isNotEmpty && !alreadyChosen && !isKnownMedication(typed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => v.trim().isEmpty ? null : _add(v),
          decoration: InputDecoration(
            hintText: s.medicationHint,
            prefixIcon: const Icon(Icons.medication_outlined),
            isDense: true,
          ),
        ),
        for (final name in matches)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.add_circle_outline, size: 20),
            title: Text(name),
            onTap: () => _add(name),
          ),
        if (canAddTyped)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.edit_outlined, size: 20),
            title: Text(s.addFormat(typed)),
            onTap: () => _add(typed),
          ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final name in widget.selected)
                InputChip(
                  label: Text(name, style: theme.textTheme.bodySmall),
                  deleteButtonTooltipMessage: s.medicationRemove,
                  onDeleted: () => widget.onChanged([
                    for (final m in widget.selected)
                      if (m != name) m,
                  ]),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
