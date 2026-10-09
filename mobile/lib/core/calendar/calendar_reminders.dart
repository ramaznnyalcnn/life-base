import 'package:intl/intl.dart';

import '../notifications/notifications.dart';
import 'calendar_event.dart';
import 'calendar_store.dart';

const calendarNotificationGroup = 'cal';

/// Reminders of local events that fire within [horizon] from [now].
///
/// Android caps an app at ~500 pending alarms, so the soonest [max] are kept
/// and the window is re-planned whenever events change or the app resumes.
List<PlannedNotification> planCalendarReminders(
  List<CalendarEvent> events,
  DateTime now, {
  Duration horizon = const Duration(days: 14),
  int max = 300,
}) {
  final end = now.add(horizon);
  // Reminders can fire up to days before their occurrence, so look further
  // ahead than the horizon for occurrences.
  final occurrences = occurrencesIn(events, now.subtract(const Duration(days: 1)), end.add(const Duration(days: 31)));
  final planned = <PlannedNotification>[];
  for (final occurrence in occurrences) {
    for (final reminder in occurrence.reminderTimes()) {
      if (!reminder.at.isAfter(now) || reminder.at.isAfter(end)) continue;
      planned.add(PlannedNotification(
        group: calendarNotificationGroup,
        key: '${occurrence.key}#${reminder.index}',
        title: occurrence.event.title,
        body: reminderBody(occurrence, reminder.at),
        at: reminder.at,
        channel: reminder.spec.priority == ReminderPriority.high || occurrence.event.important
            ? NotificationChannel.calendarHigh
            : NotificationChannel.calendar,
      ));
    }
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned.take(max).toList();
}

/// "10 dk sonra · 09:30", "Şimdi · 09:30", "Yarın · tüm gün" (+ note).
String reminderBody(EventOccurrence occurrence, DateTime firesAt) {
  final event = occurrence.event;
  final start = occurrence.start;
  final String when;
  if (event.allDay) {
    final days = DateTime(start.year, start.month, start.day).difference(DateTime(firesAt.year, firesAt.month, firesAt.day)).inDays;
    when = '${switch (days) { 0 => 'Bugün', 1 => 'Yarın', _ => DateFormat('d MMMM EEEE', 'tr_TR').format(start) }} · tüm gün';
  } else {
    final lead = start.difference(firesAt);
    final time = DateFormat('HH:mm').format(start);
    when = lead.inMinutes <= 0 ? 'Şimdi · $time' : '${formatLead(lead)} sonra · $time';
  }
  final note = event.notes?.trim();
  return note == null || note.isEmpty ? when : '$when\n$note';
}

/// 10 dk · 1 sa · 1 sa 30 dk · 2 gün
String formatLead(Duration lead) {
  if (lead.inMinutes < 60) return '${lead.inMinutes} dk';
  if (lead.inHours < 24) {
    final minutes = lead.inMinutes % 60;
    return minutes == 0 ? '${lead.inHours} sa' : '${lead.inHours} sa $minutes dk';
  }
  final hours = lead.inHours % 24;
  return hours == 0 ? '${lead.inDays} gün' : '${lead.inDays} gün $hours sa';
}
