import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/providers.dart';
import 'events_repository.dart';

const _importKey = 'import.server_calendar';

/// Server event → local event. Ids are derived from the server id, so every
/// device importing the same record converges on one document.
CalendarEvent eventFromServer(Map<String, Object?> json) {
  final allDay = json['is_all_day'] == true;
  final start = DateTime.parse(json['starts_at']! as String).toLocal();
  final endRaw = json['ends_at'] as String?;
  final offsets = <int>{
    for (final reminder in (json['reminders'] as List? ?? const []).cast<Map>())
      start.difference(DateTime.parse(reminder['remind_at'] as String).toLocal()).inMinutes,
  }.where((m) => m >= 0).toList()
    ..sort();
  return CalendarEvent(
    id: 'srv-event-${json['id']}',
    title: json['title'] as String? ?? '',
    notes: json['description'] as String?,
    startsAt: allDay ? DateTime(start.year, start.month, start.day) : start,
    endsAt: endRaw == null ? null : DateTime.parse(endRaw).toLocal(),
    allDay: allDay,
    important: json['is_important'] == true,
    reminders: [for (final m in offsets) ReminderSpec.before(Duration(minutes: m))],
  );
}

/// Server routine (weekdays 0 = Monday) → weekly repeating local event.
CalendarEvent routineFromServer(Map<String, Object?> json) {
  final day = DateTime.parse(json['starts_on']! as String);
  (int, int) time(Object? raw) {
    final parts = (raw as String).split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  final allDay = json['is_all_day'] == true || json['start_time'] == null;
  final (sh, sm) = allDay ? (0, 0) : time(json['start_time']);
  final start = DateTime(day.year, day.month, day.day, sh, sm);
  DateTime? end;
  if (allDay) {
    end = start.add(const Duration(days: 1));
  } else if (json['end_time'] != null) {
    final (eh, em) = time(json['end_time']);
    end = DateTime(day.year, day.month, day.day, eh, em);
  }
  final until = json['ends_on'] as String?;
  return CalendarEvent(
    id: 'srv-routine-${json['id']}',
    title: json['title'] as String? ?? '',
    notes: json['description'] as String?,
    startsAt: start,
    endsAt: end,
    allDay: allDay,
    important: json['is_important'] == true,
    recurrence: RecurrenceRule(
      freq: RecurrenceFreq.weekly,
      interval: (json['interval_weeks'] as num?)?.toInt() ?? 1,
      weekdays: [for (final d in (json['weekdays'] as List).cast<num>()) d.toInt() + 1],
      until: until == null ? null : DateTime.parse(until),
    ),
  );
}

/// Moves server-side events and routines on-device once. Records that
/// already exist locally (edited, or imported by another device) are kept.
final serverCalendarImportProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  if (api == null || await db.syncState(_importKey) == 'done') return 0;
  final repo = ref.read(eventsRepositoryProvider);
  try {
    final incoming = [
      ...(await api.legacyEvents()).where((e) => e['is_completed'] != true).map(eventFromServer),
      ...(await api.legacyRoutines()).where((r) => r['is_active'] != false).map(routineFromServer),
    ];
    var imported = 0;
    for (final event in incoming) {
      final row = await (db.select(db.localEvents)..where((t) => t.id.equals(event.id))).getSingleOrNull();
      if (row != null) continue;
      await repo.save(event);
      imported++;
    }
    await db.setSyncState(_importKey, 'done');
    return imported;
  } on Object {
    // Offline or an older server: try again on the next start.
    return 0;
  }
});
