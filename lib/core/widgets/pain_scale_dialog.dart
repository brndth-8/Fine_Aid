import 'package:flutter/material.dart';
import '../../data/pain_assessment.dart';
import '../../i18n/pain_strings.dart';

/// Asks the user to rate their pain from 0 to 5 (0 = no pain, 5 = worst
/// pain). It cannot be dismissed or skipped — no tap-outside, no back button,
/// no skip button — and "Continue" stays disabled until a number is chosen.
/// Returns the chosen score — or null only if the caller closed the pop-up
/// itself (eg the scan behind it failed).
Future<int?> showPainScaleDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PainScaleDialog(),
  );
}

// The pop-up's two node colours.
const Color _maroonNode = Color(0xFF7A0000);
const Color _grayNode = Color(0xFFB0B0B0);

// Green (no pain) -> dark red (worst), so the scale reads at a glance.
const List<Color> _painColors = [
  Color(0xFF2E7D32),
  Color(0xFF66BB6A),
  Color(0xFFFDD835),
  Color(0xFFFFA726),
  Color(0xFFFF5722),
  Color(0xFF8B0000),
];

/// The 0-5 pain scale: six tappable numbers on a green-to-red line, each with
/// its label underneath. Used by the pain pop-up and the Add Entry form.
class PainScaleSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  /// The pop-up's look: maroon for the chosen number, light gray for the
  /// rest, and a plain gray line. Off = the green-to-red colours used on the
  /// Add Entry form.
  final bool monochrome;

  const PainScaleSelector({
    super.key,
    this.value,
    required this.onChanged,
    this.monochrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = PainStrings.of(context);
    const slot = 40.0; // height of the row holding the circles
    const steps = kPainMax - kPainMin + 1;

    // (No LayoutBuilder: the dialog measures its content intrinsically.)
    return Stack(
      children: [
        // The line behind the circles, from the first to the last centre: the
        // outer 1/12 on each side is empty, the middle 10/12 is the line.
        Positioned(
          left: 0,
          right: 0,
          top: slot / 2 - 2,
          child: Row(
            children: [
              const Spacer(),
              Expanded(
                flex: steps * 2 - 2,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: monochrome ? _grayNode : null,
                    gradient: monochrome
                        ? null
                        : LinearGradient(colors: _painColors),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var n = kPainMin; n <= kPainMax; n++)
              Expanded(
                child: _step(
                  context,
                  n,
                  label: s.rating(n).label,
                  selected: value == n,
                  slot: slot,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _step(
    BuildContext context,
    int n, {
    required String label,
    required bool selected,
    required double slot,
  }) {
    final theme = Theme.of(context);
    final color = monochrome
        ? (selected ? _maroonNode : _grayNode)
        : _painColors[n];
    final size = selected ? 38.0 : 26.0;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Pain $n, $label',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(n),
        child: Column(
          children: [
            SizedBox(
              height: slot,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected || monochrome
                        ? color
                        : color.withValues(alpha: 0.9),
                    border: Border.all(
                      color: Colors.white,
                      width: selected ? 3 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$n',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: monochrome && selected ? _maroonNode : null,
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

class _PainScaleDialog extends StatefulWidget {
  const _PainScaleDialog();

  @override
  State<_PainScaleDialog> createState() => _PainScaleDialogState();
}

class _PainScaleDialogState extends State<_PainScaleDialog> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = PainStrings.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFDEEEC),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.dialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.dialogBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              PainScaleSelector(
                monochrome: true,
                value: _selected,
                onChanged: (n) => setState(() => _selected = n),
              ),
              const SizedBox(height: 12),
              Text(
                _selected == null
                    ? s.chooseHint
                    : '$_selected — ${s.rating(_selected!).label}',
                style: _selected == null
                    ? theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      )
                    : theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _maroonNode,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
            ),
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
            child: Text(s.continueButton),
          ),
        ],
      ),
    );
  }
}
