import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/meds/med_reminders.dart';
import 'package:lifebase_mobile/core/meds/medication.dart';
import 'package:lifebase_mobile/core/notifications/notifications.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final now = DateTime(2026, 10, 9, 8, 0);
  final vitamin = Medication(
    id: 'm1',
    name: 'D vitamini',
    schedule: const MedSchedule.daily(['09:00']),
    startsOn: DateTime(2026, 10, 1),
    mealRelation: 'after_meal',
    alarm: const AlarmSettings(repeatEveryMinutes: 5, maxRepeats: 2),
  );
  final dose = ScheduledDose(vitamin, DateTime(2026, 10, 9, 9));

  LocalDoseLog log(String status, {DateTime? snoozedUntil}) => LocalDoseLog(
        id: dose.id,
        medicationId: 'm1',
        scheduledFor: dose.at.toUtc(),
        status: status,
        snoozedUntil: snoozedUntil?.toUtc(),
        updatedAtMs: 1,
        dirty: false,
      );

  List<String> today(List<PlannedNotification> planned) => [
        for (final n in planned)
          if (n.at.day == 9) '${n.at.hour}:${n.at.minute.toString().padLeft(2, '0')}',
      ];

  test('an unanswered dose rings, then repeats maxRepeats times', () {
    final planned = planMedReminders([vitamin], const {}, now, horizon: const Duration(hours: 12));
    expect(today(planned), ['9:00', '9:05', '9:10']);
    expect(planned.first.channel, NotificationChannel.medsAlarm);
    expect(planned.first.fullScreen, isTrue);
    expect(planned.first.actions.map((a) => a.$1), ['take', 'snooze', 'skip']);
    expect(planned.first.body, '1 tablet · Yemekten sonra · 09:00');
    expect(planned[1].body, startsWith('Hâlâ alınmadı'));
    expect(planned.map((n) => n.id).toSet(), hasLength(3), reason: 'each ring has its own stable id');
  });

  test('taken or skipped doses stop ringing; a snooze moves the rings', () {
    expect(planMedReminders([vitamin], {dose.id: log('taken')}, now, horizon: const Duration(hours: 12)), isEmpty);
    expect(planMedReminders([vitamin], {dose.id: log('skipped')}, now, horizon: const Duration(hours: 12)), isEmpty);

    final at = DateTime(2026, 10, 9, 9, 2);
    final snoozed = planMedReminders([vitamin], {dose.id: log('snoozed', snoozedUntil: DateTime(2026, 10, 9, 9, 12))}, at,
        horizon: const Duration(hours: 12));
    expect(today(snoozed), ['9:12', '9:17', '9:22']);
  });

  test('rings already in the past are not scheduled again', () {
    final planned = planMedReminders([vitamin], const {}, DateTime(2026, 10, 9, 9, 6), horizon: const Duration(hours: 12));
    expect(today(planned), ['9:10']);
  });

  test('as-needed medications never ring', () {
    final prn = vitamin.copyWith(schedule: const MedSchedule(mode: ScheduleMode.asNeeded));
    expect(planMedReminders([prn], const {}, now), isEmpty);
  });

  test('payloads carry the dose id; answered doses are silenced on screen by id', () {
    final planned = planMedReminders([vitamin], const {}, now, horizon: const Duration(hours: 12));
    expect(doseIdFromPayload(planned[1].payload), dose.id);
    expect(doseIdFromPayload('cal|x|1'), isNull);

    final shown = [planned.first.id, 99];
    final at = DateTime(2026, 10, 9, 9, 1);
    expect(answeredShownAlarms(shown, const {}, at), isEmpty);
    expect(answeredShownAlarms(shown, {dose.id: log('taken')}, at), [planned.first.id]);
    expect(answeredShownAlarms(shown, {dose.id: log('snoozed', snoozedUntil: DateTime(2026, 10, 9, 9, 11))}, at), [planned.first.id]);
    expect(answeredShownAlarms(shown, {dose.id: log('cleared')}, at), isEmpty);
  });

  test('dose ids round-trip', () {
    final parsed = parseDoseLogId(dose.id)!;
    expect(parsed.medicationId, 'm1');
    expect(parsed.at, dose.at);
    expect(parseDoseLogId('nonsense'), isNull);
  });
}
