import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/calendar_strings.dart';
import '../../i18n/date_picker_strings.dart';

/// Reads "MM/DD/YYYY". Returns null when it isn't a real calendar date
/// (wrong shape, month 13, 31 February, …).
DateTime? parseDateInput(String text) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  final day = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime rolls an impossible date over (31 Feb -> 3 Mar); reject that.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// "10/05/2026".
String formatDateInput(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

/// Asks for ONE date, picked on a calendar or typed as MM/DD/YYYY (the two
/// stay in sync). Dates outside [firstDate]..[lastDate] can't be chosen.
/// Returns null when cancelled.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  DateTime? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final result = await showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      isRange: false,
      initialStart: initial,
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
    ),
  );
  return result?.start;
}

/// Asks for a start and an end date: tap two days on the calendar (the range
/// is highlighted) or type both as MM/DD/YYYY. The end can't be before the
/// start; a single day is fine. Returns null when cancelled.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      isRange: true,
      initialStart: initial?.start,
      initialEnd: initial?.end,
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
    ),
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  final bool isRange;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const _AppDatePickerDialog({
    required this.isRange,
    this.initialStart,
    this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  DateTime? _start;
  DateTime? _end;
  String? _startError;
  String? _endError;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    // A single date opens on the value already set, or on today when there
    // is none (and today can be chosen).
    _start =
        _clampOrNull(widget.initialStart) ??
        (widget.isRange ? null : _clampOrNull(DateTime.now()));
    _end = widget.isRange ? _clampOrNull(widget.initialEnd) : null;
    if (_start != null) _startController.text = formatDateInput(_start!);
    if (_end != null) _endController.text = formatDateInput(_end!);
    final shown = _start ?? DateUtils.dateOnly(DateTime.now());
    _month = DateTime(
      shown.year,
      shown.month,
    ).clamp(widget.firstDate, widget.lastDate);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  DateTime? _clampOrNull(DateTime? d) {
    if (d == null) return null;
    final day = DateUtils.dateOnly(d);
    if (day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate)) {
      return null;
    }
    return day;
  }

  bool _selectable(DateTime day) =>
      !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  // ---- calendar taps -> fields ----
  void _onDayTap(DateTime day) {
    if (!_selectable(day)) return;
    setState(() {
      if (!widget.isRange) {
        _start = day;
      } else if (_start == null || _end != null) {
        // First tap (or starting over): a new start, no end yet.
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else {
        _end = day;
      }
      _startError = null;
      _endError = null;
      _startController.text = _start == null ? '' : formatDateInput(_start!);
      _endController.text = _end == null ? '' : formatDateInput(_end!);
    });
  }

  // ---- typing -> calendar ----
  String? _check(String text, DatePickerStrings s) {
    final date = parseDateInput(text);
    if (date == null) return s.invalidDate;
    if (date.isBefore(widget.firstDate)) {
      return s.onOrAfterFormat.replaceFirst(
        '{date}',
        formatDateInput(widget.firstDate),
      );
    }
    if (date.isAfter(widget.lastDate)) {
      return s.onOrBeforeFormat.replaceFirst(
        '{date}',
        formatDateInput(widget.lastDate),
      );
    }
    return null;
  }

  void _onTyped({required bool isStart}) {
    final s = DatePickerStrings.of(context);
    final controller = isStart ? _startController : _endController;
    final text = controller.text;
    setState(() {
      if (text.isEmpty) {
        if (isStart) {
          _start = null;
          _startError = null;
        } else {
          _end = null;
          _endError = null;
        }
        return;
      }
      // Don't scold while the date is still being typed.
      final complete = text.length >= 10;
      final error = complete ? _check(text, s) : null;
      final date = (complete && error == null) ? parseDateInput(text) : null;
      if (isStart) {
        _start = date;
        _startError = error;
        if (date != null) {
          _month = DateTime(date.year, date.month);
        }
      } else {
        _end = date;
        _endError = error;
        if (date != null) {
          _month = DateTime(date.year, date.month);
        }
      }
      if (widget.isRange && _start != null && _end != null) {
        if (_end!.isBefore(_start!)) {
          _endError = s.endBeforeStart;
          _end = null;
        }
      }
    });
  }

  bool get _canConfirm =>
      widget.isRange ? (_start != null && _end != null) : _start != null;

  void _confirm() {
    final start = _start!;
    Navigator.pop(context, DateTimeRange(start: start, end: _end ?? start));
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  bool get _canGoBack => DateTime(
    _month.year,
    _month.month - 1,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month - 1));

  bool get _canGoForward => DateTime(
    _month.year,
    _month.month + 1,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = DatePickerStrings.of(context);
    final c = CalendarStrings.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isRange ? s.titleRange : s.titleSingle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _startController,
                label: widget.isRange ? s.startLabel : s.dateLabel,
                error: _startError,
                onChanged: () => _onTyped(isStart: true),
                s: s,
                name: 'start',
              ),
              if (widget.isRange) ...[
                const SizedBox(height: 10),
                _field(
                  controller: _endController,
                  label: s.endLabel,
                  error: _endError,
                  onChanged: () => _onTyped(isStart: false),
                  s: s,
                  name: 'end',
                ),
              ],
              const SizedBox(height: 14),
              _monthHeader(theme, c, s),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          c.weekdays[i],
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: (i == 0 || i == 6)
                                ? theme.colorScheme.primary
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _grid(theme),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s.cancel),
                  ),
                  ElevatedButton(
                    onPressed: _canConfirm ? _confirm : null,
                    child: Text(s.ok),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A date as three separate boxes (month, day, year): each number can be
  /// changed on its own. The text in [controller] stays "MM/DD/YYYY".
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? error,
    required VoidCallback onChanged,
    required DatePickerStrings s,
    required String name,
  }) {
    return _DateBoxes(
      controller: controller,
      label: label,
      error: error,
      onChanged: onChanged,
      hints: s.hint.split('/'),
      name: name,
    );
  }

  Widget _monthHeader(ThemeData theme, CalendarStrings c, DatePickerStrings s) {
    return Row(
      children: [
        IconButton(
          tooltip: s.previousMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
        ),
        Expanded(
          child: Text(
            // Month names stay in English, even in Filipino.
            '${CalendarStrings.en.months[_month.month - 1]} ${_month.year}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: s.nextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoForward ? () => _shiftMonth(1) : null,
        ),
      ],
    );
  }

  Widget _grid(ThemeData theme) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
    final cellCount = ((lead + daysInMonth + 6) ~/ 7) * 7;
    final today = DateUtils.dateOnly(DateTime.now());

    final rows = <Widget>[];
    for (var row = 0; row < cellCount ~/ 7; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final dayNumber = row * 7 + col - lead + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 40)));
          continue;
        }
        cells.add(
          Expanded(
            child: _dayCell(
              theme,
              DateTime(_month.year, _month.month, dayNumber),
              today,
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }

  Widget _dayCell(ThemeData theme, DateTime day, DateTime today) {
    final primary = theme.colorScheme.primary;
    final isStart = _start != null && DateUtils.isSameDay(day, _start);
    final isEnd = _end != null && DateUtils.isSameDay(day, _end);
    final selected = isStart || isEnd;
    final inRange =
        widget.isRange &&
        _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final enabled = _selectable(day);
    final isToday = DateUtils.isSameDay(day, today);

    final textColor = !enabled
        ? Colors.grey.shade400
        : selected
        ? theme.colorScheme.onPrimary
        : (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday)
        ? primary
        : Colors.black87;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: formatDateInput(day),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
        onTap: enabled ? () => _onDayTap(day) : null,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          // The strip between the two ends of a range.
          color: inRange ? primary.withValues(alpha: 0.14) : null,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? primary : null,
              border: (isToday && !selected)
                  ? Border.all(color: primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: (selected || isToday) ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on DateTime {
  DateTime clamp(DateTime min, DateTime max) {
    final minMonth = DateTime(min.year, min.month);
    final maxMonth = DateTime(max.year, max.month);
    if (isBefore(minMonth)) return minMonth;
    if (isAfter(maxMonth)) return maxMonth;
    return this;
  }
}

/// The month, day and year boxes of one date. The three keep the shared text
/// controller in step ("MM/DD/YYYY") in both directions: typing in a box
/// updates it, and a day picked on the calendar fills the boxes.
class _DateBoxes extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? error;
  final VoidCallback onChanged;

  /// What the boxes show while empty (eg MM, DD, YYYY).
  final List<String> hints;

  /// "start" or "end": the boxes are keyed `<name>-field-mm|dd|yyyy`.
  final String name;

  const _DateBoxes({
    required this.controller,
    required this.label,
    required this.error,
    required this.onChanged,
    required this.hints,
    required this.name,
  });

  @override
  State<_DateBoxes> createState() => _DateBoxesState();
}

class _DateBoxesState extends State<_DateBoxes> {
  final _mm = TextEditingController();
  final _dd = TextEditingController();
  final _yyyy = TextEditingController();
  final _ddFocus = FocusNode();
  final _yyyyFocus = FocusNode();
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
    _pull();
    widget.controller.addListener(_pull);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_pull);
    _mm.dispose();
    _dd.dispose();
    _yyyy.dispose();
    _ddFocus.dispose();
    _yyyyFocus.dispose();
    super.dispose();
  }

  String _compose() {
    final m = _mm.text, d = _dd.text, y = _yyyy.text;
    if (m.isEmpty && d.isEmpty && y.isEmpty) return '';
    if (m.isNotEmpty && d.isNotEmpty && y.length == 4) {
      return '${m.padLeft(2, '0')}/${d.padLeft(2, '0')}/$y';
    }
    return '$m/$d/$y';
  }

  // The shared text changed (a calendar tap): show it in the boxes.
  void _pull() {
    if (_pushing) return;
    final parts = widget.controller.text.split('/');
    String part(int i) => i < parts.length ? parts[i] : '';
    if (_mm.text != part(0)) _mm.text = part(0);
    if (_dd.text != part(1)) _dd.text = part(1);
    if (_yyyy.text != part(2)) _yyyy.text = part(2);
  }

  // A box changed: update the shared text, and tell the dialog.
  void _push({FocusNode? next}) {
    _pushing = true;
    widget.controller.text = _compose();
    _pushing = false;
    widget.onChanged();
    next?.requestFocus();
  }

  Widget _box(
    String key,
    TextEditingController controller,
    String hint,
    int length, {
    FocusNode? focus,
    FocusNode? next,
  }) {
    final hasError = widget.error != null;
    final side = BorderSide(
      color: hasError ? Theme.of(context).colorScheme.error : Colors.grey,
    );
    return TextField(
      key: ValueKey('${widget.name}-field-$key'),
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      onChanged: (v) => _push(next: v.length == length ? next : null),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        enabledBorder: OutlineInputBorder(borderSide: side),
        border: OutlineInputBorder(borderSide: side),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String hint(int i) => i < widget.hints.length ? widget.hints[i] : '';
    const slash = Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('/'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16),
            const SizedBox(width: 6),
            Text(widget.label, style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _box('mm', _mm, hint(0), 2, next: _ddFocus),
            ),
            slash,
            Expanded(
              flex: 2,
              child: _box(
                'dd',
                _dd,
                hint(1),
                2,
                focus: _ddFocus,
                next: _yyyyFocus,
              ),
            ),
            slash,
            Expanded(
              flex: 3,
              child: _box('yyyy', _yyyy, hint(2), 4, focus: _yyyyFocus),
            ),
          ],
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              widget.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
