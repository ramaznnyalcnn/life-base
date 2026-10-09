import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/modules/calendar/data/server_import.dart';

void main() {
  test('server events keep their times and turn reminders into offsets', () {
    final start = DateTime(2026, 10, 12, 10);
    final event = eventFromServer({
      'id': 12,
      'title': 'Diş hekimi',
      'description': 'Kontrol',
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': start.add(const Duration(minutes: 45)).toUtc().toIso8601String(),
      'is_all_day': false,
      'is_important': true,
      'reminders': [
        {'remind_at': start.subtract(const Duration(hours: 1)).toUtc().toIso8601String()},
        {'remind_at': start.subtract(const Duration(days: 1)).toUtc().toIso8601String()},
      ],
    });

    expect(event.id, 'srv-event-12');
    expect(event.startsAt, start);
    expect(event.endsAt, start.add(const Duration(minutes: 45)));
    expect(event.notes, 'Kontrol');
    expect(event.important, isTrue);
    expect(event.reminders, const [ReminderSpec.before(Duration(hours: 1)), ReminderSpec.before(Duration(days: 1))]);
  });

  test('server routines become weekly repeating events (0 = Monday)', () {
    final event = routineFromServer({
      'id': 3,
      'title': 'Spor',
      'weekdays': [0, 2],
      'starts_on': '2026-10-05',
      'ends_on': '2026-12-31',
      'start_time': '18:00:00',
      'end_time': '19:30:00',
      'interval_weeks': 2,
      'is_all_day': false,
    });

    expect(event.id, 'srv-routine-3');
    expect(event.startsAt, DateTime(2026, 10, 5, 18));
    expect(event.duration, const Duration(minutes: 90));
    expect(event.recurrence, RecurrenceRule(freq: RecurrenceFreq.weekly, interval: 2, weekdays: const [1, 3], until: DateTime(2026, 12, 31)));
    expect(event.occurrencesBetween(DateTime(2026, 10, 5), DateTime(2026, 10, 25)).map((o) => o.start.day), [5, 7, 19, 21]);
  });
}
