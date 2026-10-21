import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/network_error.dart';
import '../../../i18n/calendar_strings.dart';
import 'entry_detail_screen.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Journal Calendar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(child: Text('Not signed in'))
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

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            _buildCalendarCard(theme, markedDates),
                            const SizedBox(height: 20),
                            Text(
                              CalendarStrings.of(
                                context,
                              ).monthDay(_selectedDate),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (snapshot.hasError)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  isNetworkError(snapshot.error!)
                                      ? noInternetMessage
                                      : 'Could not load entries for this '
                                            'day. Please try again.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                            else if (!snapshot.hasData)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (selectedEntries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'No journal entries for this day.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              ...selectedEntries.map(
                                (entry) =>
                                    _buildEntryTile(theme, entry.$1, entry.$2),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
              Icons.calendar_today,
              color: theme.colorScheme.primary,
              size: 20,
            ),
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
                  if (timeText.isNotEmpty)
                    Text(timeText, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
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

    void changeMonth(int by) => setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + by,
      );
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  c.months[_displayedMonth.month - 1].toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
            if (!onCurrentMonth)
              TextButton(
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(now.year, now.month);
                  _selectedDate = today;
                }),
                child: Text(c.jumpToToday),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: 32,
                    child: Text(
                      c.weekdays[i],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: i == 0
                            ? Colors.red.shade400
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              // Days still to come are dimmed.
                              color: isToday
                                  ? Colors.white
                                  : (thisDate.isAfter(today)
                                        ? Colors.grey.shade500
                                        : null),
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
          ],
        ),
      ),
    );
  }
}
