import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'calendar_event.dart';

/// Every live (not deleted) local calendar event, kept up to date.
final localEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.localEvents)..where((t) => t.deletedAtMs.isNull()))
      .watch()
      .map((rows) => rows.map(CalendarEvent.fromRow).toList());
});

/// Occurrences overlapping the local-date range, ordered by start
/// (all-day first within a day).
List<EventOccurrence> occurrencesIn(List<CalendarEvent> events, DateTime from, DateTime to) {
  final result = [for (final event in events) ...event.occurrencesBetween(from, to)];
  result.sort((a, b) {
    final byDay = DateTime(a.start.year, a.start.month, a.start.day).compareTo(DateTime(b.start.year, b.start.month, b.start.day));
    if (byDay != 0) return byDay;
    if (a.event.allDay != b.event.allDay) return a.event.allDay ? -1 : 1;
    return a.start.compareTo(b.start);
  });
  return result;
}
