import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/google_projection.dart';

void main() {
  final start = DateTime(2026, 10, 5, 18, 30); // Monday

  CalendarEvent event(RecurrenceRule? rule, {bool allDay = false}) => CalendarEvent(
        id: 'e1',
        title: 'Spor',
        notes: 'Salon',
        startsAt: allDay ? DateTime(2026, 10, 5) : start,
        endsAt: allDay ? DateTime(2026, 10, 6) : start.add(const Duration(hours: 1)),
        allDay: allDay,
        recurrence: rule,
      );

  test('repeat rules become RRULEs', () {
    expect(toRrule(event(const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 3))), 'FREQ=DAILY;INTERVAL=3');
    expect(toRrule(event(const RecurrenceRule(freq: RecurrenceFreq.weekly, weekdays: [1, 3]))), 'FREQ=WEEKLY;BYDAY=MO,WE');
    expect(toRrule(event(const RecurrenceRule(freq: RecurrenceFreq.weekly))), 'FREQ=WEEKLY;BYDAY=MO');
    expect(toRrule(event(const RecurrenceRule(freq: RecurrenceFreq.monthly))), 'FREQ=MONTHLY;BYMONTHDAY=5');
    expect(toRrule(event(RecurrenceRule(freq: RecurrenceFreq.yearly, until: DateTime(2030, 1, 1)), allDay: true)), 'FREQ=YEARLY;UNTIL=20300101');
    expect(
      toRrule(event(RecurrenceRule(freq: RecurrenceFreq.daily, until: DateTime(2026, 10, 9)))),
      'FREQ=DAILY;UNTIL=${DateTime(2026, 10, 9, 23, 59, 59).toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z',
    );
  });

  test('one-off events carry an end, repeating ones a duration and exdates', () {
    final once = projectionPayload(event(null));
    expect(once['id'], 'local:e1');
    expect(once['ends_at'], start.add(const Duration(hours: 1)).toUtc().toIso8601String());
    expect(once.containsKey('rrule'), isFalse);

    final series = projectionPayload(event(RecurrenceRule(freq: RecurrenceFreq.daily, exdates: [DateTime(2026, 10, 7)])));
    expect(series.containsKey('ends_at'), isFalse);
    expect(series['duration'], 'P3600S');
    expect(series['exdate'], isNotEmpty);

    final allDay = projectionPayload(event(const RecurrenceRule(freq: RecurrenceFreq.yearly), allDay: true));
    expect(allDay['starts_at'], '2026-10-05T00:00:00.000Z');
    expect(allDay['duration'], 'P1D');
  });
}
