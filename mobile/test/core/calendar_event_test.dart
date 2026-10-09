import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';

CalendarEvent event({
  DateTime? start,
  Duration length = const Duration(hours: 1),
  RecurrenceRule? rule,
  bool allDay = false,
  List<ReminderSpec> reminders = const [],
}) {
  final s = start ?? DateTime(2026, 10, 5, 9, 30); // Monday
  return CalendarEvent(id: 'e', title: 'x', startsAt: s, endsAt: s.add(length), allDay: allDay, recurrence: rule, reminders: reminders);
}

List<String> days(List<EventOccurrence> list) =>
    list.map((o) => '${o.start.month}/${o.start.day} ${o.start.hour}:${o.start.minute.toString().padLeft(2, '0')}').toList();

void main() {
  test('one-off event appears only on its day', () {
    final e = event();
    expect(e.occurrencesBetween(DateTime(2026, 10, 5), DateTime(2026, 10, 5)), hasLength(1));
    expect(e.occurrencesBetween(DateTime(2026, 10, 6), DateTime(2026, 10, 30)), isEmpty);
  });

  test('every N days keeps the wall-clock time', () {
    final e = event(rule: const RecurrenceRule(freq: RecurrenceFreq.daily, interval: 3));
    expect(days(e.occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 14))),
        ['10/5 9:30', '10/8 9:30', '10/11 9:30', '10/14 9:30']);
    // Window far after the start still lands on the right cadence.
    // 5 Oct + 3k: 31 Dec (+87) and 3 Jan (+90).
    expect(days(e.occurrencesBetween(DateTime(2027, 1, 1), DateTime(2027, 1, 4))), ['1/3 9:30']);
  });

  test('weekly on chosen weekdays, every other week, until a date', () {
    final e = event(
      rule: RecurrenceRule(freq: RecurrenceFreq.weekly, interval: 2, weekdays: const [1, 3], until: DateTime(2026, 10, 21)),
    );
    expect(days(e.occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 30))),
        ['10/5 9:30', '10/7 9:30', '10/19 9:30', '10/21 9:30']);
  });

  test('monthly skips months that lack the day instead of overflowing', () {
    final e = event(start: DateTime(2026, 1, 31, 8), rule: const RecurrenceRule(freq: RecurrenceFreq.monthly));
    expect(days(e.occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 5, 31))), ['1/31 8:00', '3/31 8:00', '5/31 8:00']);
  });

  test('yearly repeats on the same date', () {
    final e = event(start: DateTime(2026, 3, 14, 0), allDay: true, length: const Duration(days: 1), rule: const RecurrenceRule(freq: RecurrenceFreq.yearly));
    expect(e.occurrencesBetween(DateTime(2028, 3, 14), DateTime(2028, 3, 14)), hasLength(1));
    expect(e.occurrencesBetween(DateTime(2028, 3, 15), DateTime(2028, 12, 31)), isEmpty);
  });

  test('removed days (exdates) are skipped', () {
    final e = event(rule: RecurrenceRule(freq: RecurrenceFreq.daily, exdates: [DateTime(2026, 10, 6)]));
    expect(days(e.occurrencesBetween(DateTime(2026, 10, 5), DateTime(2026, 10, 7))), ['10/5 9:30', '10/7 9:30']);
  });

  test('a multi-day event shows on every day it covers', () {
    final e = event(start: DateTime(2026, 10, 9, 22), length: const Duration(hours: 4));
    expect(e.occurrencesBetween(DateTime(2026, 10, 10), DateTime(2026, 10, 10)), hasLength(1));
    final trip = event(start: DateTime(2026, 10, 9), allDay: true, length: const Duration(days: 3));
    expect(trip.occurrencesBetween(DateTime(2026, 10, 11), DateTime(2026, 10, 11)), hasLength(1));
    expect(trip.occurrencesBetween(DateTime(2026, 10, 12), DateTime(2026, 10, 12)), isEmpty);
  });

  test('reminders: offsets per occurrence, fixed times only for one-off events, all-day at 09:00', () {
    final at = DateTime.utc(2026, 10, 4, 18);
    final once = event(reminders: [const ReminderSpec.before(Duration(minutes: 10)), ReminderSpec.at(at)]);
    final times = once.occurrencesBetween(DateTime(2026, 10, 5), DateTime(2026, 10, 5)).single.reminderTimes();
    expect(times.map((r) => r.at), [DateTime(2026, 10, 5, 9, 20), at]);

    final series = event(rule: const RecurrenceRule(freq: RecurrenceFreq.daily), reminders: [ReminderSpec.at(at), const ReminderSpec.before(Duration(days: 1))]);
    expect(series.occurrencesBetween(DateTime(2026, 10, 6), DateTime(2026, 10, 6)).single.reminderTimes().map((r) => r.index), [1]);

    final allDay = event(start: DateTime(2026, 10, 5), allDay: true, length: const Duration(days: 1), reminders: const [ReminderSpec.before(Duration.zero)]);
    expect(allDay.occurrencesBetween(DateTime(2026, 10, 5), DateTime(2026, 10, 5)).single.reminderTimes().single.at, DateTime(2026, 10, 5, 9));
  });

  test('rule and reminder JSON round-trip', () {
    final rule = RecurrenceRule(freq: RecurrenceFreq.weekly, interval: 2, weekdays: const [5, 1], until: DateTime(2027, 1, 1), exdates: [DateTime(2026, 11, 2)]);
    expect(RecurrenceRule.fromJson(rule.toJson()), rule);
    expect(RecurrenceRule.fromJson(rule.toJson()).weekdays, [1, 5]);
    const reminder = ReminderSpec.before(Duration(hours: 1), priority: ReminderPriority.high);
    expect(ReminderSpec.fromJson(reminder.toJson()), reminder);
  });
}
