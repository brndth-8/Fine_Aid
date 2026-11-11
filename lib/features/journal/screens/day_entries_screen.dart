import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/network_error.dart';
import '../../../i18n/calendar_strings.dart';
import '../../../services/guest_journal_store.dart';
import 'entry_detail_screen.dart';
import 'journal_entry_menu.dart';

/// The date to show under the calendar when [month] is on view: [selected]'s
/// day of the month, or the month's last day when it is shorter (31 -> 30).
DateTime dateInMonth(DateTime selected, DateTime month) {
  final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
  return DateTime(
    month.year,
    month.month,
    selected.day > lastDay ? lastDay : selected.day,
  );
}

class DayEntriesScreen extends StatefulWidget {
  final DateTime initialDate;

  const DayEntriesScreen({super.key, required this.initialDate});

  @override
  State<DayEntriesScreen> createState() => _DayEntriesScreenState();
}

class _DayEntriesScreenState extends State<DayEntriesScreen> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _selectedDate = DateTime(d.year, d.month, d.day);
    _displayedMonth = DateTime(d.year, d.month);
    // Guest Mode entries live on this phone.
    if (FirebaseAuth.instance.currentUser == null) {
      GuestJournalStore.instance.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Journal Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: user == null
                  ? ValueListenableBuilder<List<GuestJournalEntry>>(
                      valueListenable: GuestJournalStore.instance.entries,
                      builder: (context, all, _) {
                        final byDay =
                            <DateTime, List<(String, Map<String, dynamic>)>>{};
                        for (final e in all) {
                          final d = (e.data['createdAt'] as Timestamp).toDate();
                          byDay
                              .putIfAbsent(
                                DateTime(d.year, d.month, d.day),
                                () => [],
                              )
                              .add((e.id, e.data));
                        }
                        return _dayBody(
                          theme,
                          markedDates: byDay.keys.toSet(),
                          selectedEntries: byDay[_selectedDate] ?? const [],
                        );
                      },
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('journalEntries')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final markedDates = <DateTime>{};
                        final entriesByDay =
                            <DateTime, List<(String, Map<String, dynamic>)>>{};
                        if (snapshot.hasData) {
                          for (final doc in snapshot.data!.docs) {
                            final ts = doc.data()['createdAt'] as Timestamp?;
                            if (ts == null) continue;
                            final date = ts.toDate();
                            final dayKey = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            markedDates.add(dayKey);
                            entriesByDay.putIfAbsent(dayKey, () => []).add((
                              doc.id,
                              doc.data(),
                            ));
                          }
                        }
                        final selectedEntries =
                            entriesByDay[_selectedDate] ?? const [];

                        return _dayBody(
                          theme,
                          markedDates: markedDates,
                          selectedEntries: selectedEntries,
                          snapshot: snapshot,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The calendar and the day's entries. [snapshot] is only given for a
  /// signed-in user (it carries the loading / error states); a guest's
  /// entries are already on the phone.
  Widget _dayBody(
    ThemeData theme, {
    required Set<DateTime> markedDates,
    required List<(String, Map<String, dynamic>)> selectedEntries,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>? snapshot,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildCalendarCard(theme, markedDates),
        const SizedBox(height: 20),
        Text(
          // Month names stay in English, even in Filipino.
          CalendarStrings.en.monthDay(_selectedDate),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 8),
        if (snapshot != null && snapshot.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              isNetworkError(snapshot.error!)
                  ? noInternetMessage
                  : 'Could not load entries for this '
                        'day. Please try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else if (snapshot != null && !snapshot.hasData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (selectedEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No journal entries for this day.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...selectedEntries.map(
            (entry) => _buildEntryTile(theme, entry.$1, entry.$2),
          ),
      ],
    );
  }

  Widget _buildEntryTile(
    ThemeData theme,
    String entryId,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String? ?? 'Untitled';
    final timestamp = data['createdAt'] as Timestamp?;
    final timeText = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EntryDetailScreen(entryId: entryId, data: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 1.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_calendar_outlined,
              color: theme.colorScheme.primary,
              size: 26,
            ),
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
                  if (timeText.isNotEmpty)
                    Text(
                      timeText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            JournalEntryMenu(entryId: entryId, data: data),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(ThemeData theme, Set<DateTime> markedDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final c = CalendarStrings.of(context);
    final onCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;

    // The date shown under the calendar follows the month on view: the same
    // day of the month (or the last day, in a shorter month).
    void changeMonth(int by) => setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + by,
      );
      _selectedDate = dateInMonth(_selectedDate, _displayedMonth);
    });

    return GestureDetector(
      // Swipe left for the next month, right for the previous one.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) changeMonth(1);
        if (v > 200) changeMonth(-1);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1DCDC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDBADAD),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => changeMonth(-1),
                  ),
                  Text(
                    // The month name stays in English (with the year when it
                    // is not this year's).
                    '${CalendarStrings.en.months[_displayedMonth.month - 1].toUpperCase()}'
                    '${_displayedMonth.year == now.year ? '' : ' ${_displayedMonth.year}'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => changeMonth(1),
                  ),
                ],
              ),
            ),
            // Always takes its room (hidden on the current month), so the card
            // is the same height in every month.
            Visibility(
              visible: !onCurrentMonth,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextButton(
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(now.year, now.month);
                  _selectedDate = today;
                }),
                child: Text(c.jumpToToday),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: 38,
                    child: Text(
                      c.weekdays[i],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: (i == 0 || i == 6)
                            ? theme.colorScheme.primary
                            : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              // Always six rows tall, so the card never changes size from one
              // month to the next.
              builder: (context, box) => SizedBox(
                height: 6 * box.maxWidth / 7,
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: firstWeekday + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) return const SizedBox();
                    final day = index - firstWeekday + 1;
                    final thisDate = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month,
                      day,
                    );
                    final isToday = thisDate == today;
                    final isSelected = thisDate == _selectedDate;
                    final hasEntry = markedDates.contains(thisDate);

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = thisDate);
                      },
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: isToday
                                  ? BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Text(
                                '$day',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  // Weekends in maroon; days still to come are
                                  // dimmed.
                                  color: isToday
                                      ? Colors.white
                                      : (thisDate.isAfter(today)
                                            ? Colors.grey.shade500
                                            : (thisDate.weekday ==
                                                          DateTime.saturday ||
                                                      thisDate.weekday ==
                                                          DateTime.sunday
                                                  ? theme.colorScheme.primary
                                                  : null)),
                                  fontWeight: isToday || hasEntry
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 18,
                              height: 2,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                            ),
                            if (hasEntry && !isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
