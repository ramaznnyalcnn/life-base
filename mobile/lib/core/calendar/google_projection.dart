import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'calendar_event.dart';
import 'calendar_store.dart';

const _days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String _two(int v) => v.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
String _utcStamp(DateTime d) {
  final u = d.toUtc();
  return '${_date(u)}T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
}

/// RFC 5545 rule for the Calendar Provider, e.g. `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE`.
String toRrule(CalendarEvent event) {
  final rule = event.recurrence!;
  final parts = <String>[
    'FREQ=${switch (rule.freq) {
      RecurrenceFreq.daily => 'DAILY',
      RecurrenceFreq.weekly => 'WEEKLY',
      RecurrenceFreq.monthly => 'MONTHLY',
      RecurrenceFreq.yearly => 'YEARLY',
    }}',
    if (rule.interval > 1) 'INTERVAL=${rule.interval}',
    if (rule.freq == RecurrenceFreq.weekly)
      'BYDAY=${(rule.weekdays.isEmpty ? [event.startsAt.weekday] : rule.weekdays).map((d) => _days[d - 1]).join(',')}',
    if (rule.freq == RecurrenceFreq.monthly) 'BYMONTHDAY=${event.startsAt.day}',
  ];
  final until = rule.until;
  if (until != null) {
    // Inclusive last day: all-day rules use a date, timed ones the day's end.
    parts.add(event.allDay ? 'UNTIL=${_date(until)}' : 'UNTIL=${_utcStamp(DateTime(until.year, until.month, until.day, 23, 59, 59))}');
  }
  return parts.join(';');
}

/// One provider event per LifeBase event, as the native side expects it.
Map<String, Object?> projectionPayload(CalendarEvent event) {
  final start = event.allDay ? DateTime.utc(event.startsAt.year, event.startsAt.month, event.startsAt.day) : event.startsAt.toUtc();
  final rule = event.recurrence;
  return {
    'id': 'local:${event.id}',
    'title': event.title,
    'notes': event.notes ?? '',
    'all_day': event.allDay,
    'starts_at': start.toIso8601String(),
    if (rule == null) 'ends_at': start.add(event.duration).toIso8601String(),
    if (rule != null) ...{
      'rrule': toRrule(event),
      'duration': event.allDay ? 'P${event.duration.inDays.clamp(1, 3650)}D' : 'P${event.duration.inSeconds}S',
      'exdate': [
        for (final day in rule.exdates)
          event.allDay ? _date(day) : _utcStamp(DateTime(day.year, day.month, day.day, event.startsAt.hour, event.startsAt.minute)),
      ].join(','),
    },
  };
}

/// Mirrors local events into the connected Google calendar shortly after
/// they change. Does nothing until a Google account is connected.
final googleProjectionProvider = Provider<void>((ref) {
  Timer? debounce;
  ref.listen(localEventsProvider, (_, next) {
    final events = next.value;
    if (events == null) return;
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () async {
      try {
        await ref.read(platformBridgeProvider).projectLocalEvents(jsonEncode([for (final e in events) projectionPayload(e)]));
      } on Object {
        // Not on Android or no calendar permission: the app works without it.
      }
    });
  }, fireImmediately: true);
  ref.onDispose(() => debounce?.cancel());
});
