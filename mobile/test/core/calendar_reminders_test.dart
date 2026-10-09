import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/calendar_reminders.dart';
import 'package:lifebase_mobile/core/notifications/notifications.dart';

class FakePort implements NotificationPort {
  final scheduled = <int, PlannedNotification>{};
  final foreign = <int, String>{};
  var scheduleCalls = 0;
  var cancelCalls = 0;

  @override
  Future<List<({int id, String? payload})>> pending() async => [
        for (final n in scheduled.values) (id: n.id, payload: n.payload),
        for (final e in foreign.entries) (id: e.key, payload: e.value),
      ];

  @override
  Future<List<int>> shown() async => const [];

  @override
  Future<void> schedule(PlannedNotification n) async {
    scheduleCalls++;
    scheduled[n.id] = n;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    scheduled.remove(id);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final now = DateTime(2026, 10, 9, 8, 0);

  CalendarEvent meeting({List<ReminderSpec> reminders = const [ReminderSpec.before(Duration(minutes: 10))], RecurrenceRule? rule, bool important = false}) =>
      CalendarEvent(
        id: 'm',
        title: 'Toplantı',
        notes: 'Oda 3',
        startsAt: DateTime(2026, 10, 9, 9, 30),
        endsAt: DateTime(2026, 10, 9, 10, 30),
        reminders: reminders,
        recurrence: rule,
        important: important,
      );

  test('plans upcoming reminders with readable text', () {
    final planned = planCalendarReminders([meeting()], now);

    expect(planned.single.at, DateTime(2026, 10, 9, 9, 20));
    expect(planned.single.title, 'Toplantı');
    expect(planned.single.body, '10 dk sonra · 09:30\nOda 3');
    expect(planned.single.channel, NotificationChannel.calendar);
  });

  test('skips past reminders and those beyond the horizon, caps the count', () {
    final daily = meeting(rule: const RecurrenceRule(freq: RecurrenceFreq.daily));
    final planned = planCalendarReminders([daily], now, horizon: const Duration(days: 3));
    expect(planned.map((n) => n.at.day), [9, 10, 11]);
    expect(planCalendarReminders([daily], now, max: 2), hasLength(2));

    final late = planCalendarReminders([daily], DateTime(2026, 10, 9, 9, 25), horizon: const Duration(days: 1));
    expect(late.map((n) => n.at.day), [10], reason: 'today 09:20 already passed');
  });

  test('important events and high-priority reminders use the loud channel', () {
    expect(planCalendarReminders([meeting(important: true)], now).single.channel, NotificationChannel.calendarHigh);
    final high = meeting(reminders: const [ReminderSpec.before(Duration.zero, priority: ReminderPriority.high)]);
    final n = planCalendarReminders([high], now).single;
    expect(n.channel, NotificationChannel.calendarHigh);
    expect(n.body, startsWith('Şimdi · 09:30'));
  });

  test('lead time formatting', () {
    expect(formatLead(const Duration(minutes: 90)), '1 sa 30 dk');
    expect(formatLead(const Duration(hours: 3)), '3 sa');
    expect(formatLead(const Duration(days: 1)), '1 gün');
  });

  test('notification ids are stable and positive', () {
    expect(notificationId('cal|m@2026-10-09#0'), notificationId('cal|m@2026-10-09#0'));
    expect(notificationId('cal|m@2026-10-09#0'), isNot(notificationId('cal|m@2026-10-09#1')));
    expect(notificationId('x'), greaterThanOrEqualTo(0));
  });

  test('reconcile only touches what changed and leaves other groups alone', () async {
    final port = FakePort()..foreign[42] = 'med|dose|1';
    final first = planCalendarReminders([meeting(reminders: const [ReminderSpec.before(Duration(minutes: 10)), ReminderSpec.before(Duration(minutes: 30))])], now);
    await reconcileNotifications(port, calendarNotificationGroup, first);
    expect(port.scheduled, hasLength(2));

    port.scheduleCalls = 0;
    await reconcileNotifications(port, calendarNotificationGroup, first);
    expect(port.scheduleCalls, 0, reason: 'nothing changed');

    // The 30-minute reminder was removed and the event moved by an hour.
    final moved = meeting().copyWith(startsAt: DateTime(2026, 10, 9, 10, 30), endsAt: DateTime(2026, 10, 9, 11, 30));
    await reconcileNotifications(port, calendarNotificationGroup, planCalendarReminders([moved], now));
    expect(port.scheduled.values.single.at, DateTime(2026, 10, 9, 10, 20));
    expect(port.foreign, contains(42));

    await reconcileNotifications(port, calendarNotificationGroup, const []);
    expect(port.scheduled, isEmpty);
  });
}
