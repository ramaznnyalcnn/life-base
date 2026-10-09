import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/meds/medication.dart';
import 'package:lifebase_mobile/core/meds/meds_store.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';

Medication med(MedSchedule schedule, {DateTime? endsOn, double? stock, double amount = 1}) => Medication(
      id: 'm1',
      name: 'D vitamini',
      schedule: schedule,
      startsOn: DateTime(2026, 10, 5), // Monday
      endsOn: endsOn,
      stock: stock,
      doseAmount: amount,
    );

List<String> times(List<ScheduledDose> doses) =>
    doses.map((d) => '${d.at.day} ${d.at.hour.toString().padLeft(2, '0')}:${d.at.minute.toString().padLeft(2, '0')}').toList();

void main() {
  final from = DateTime(2026, 10, 5);

  test('N times a day, within the course', () {
    final m = med(const MedSchedule.daily(['21:30', '09:00']), endsOn: DateTime(2026, 10, 6));
    expect(times(m.dosesBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 10))), ['5 09:00', '5 21:30', '6 09:00', '6 21:30']);
  });

  test('chosen weekdays', () {
    final m = med(const MedSchedule(mode: ScheduleMode.weekdays, weekdays: [1, 5], times: ['08:00']));
    expect(times(m.dosesBetween(from, DateTime(2026, 10, 13))), ['5 08:00', '9 08:00', '12 08:00']);
  });

  test('every N days counts from the start date', () {
    final m = med(const MedSchedule(mode: ScheduleMode.everyNDays, intervalDays: 3, times: ['10:00']));
    expect(times(m.dosesBetween(DateTime(2026, 10, 6), DateTime(2026, 10, 15))), ['8 10:00', '11 10:00', '14 10:00']);
  });

  test('every N hours runs continuously across midnight', () {
    final m = med(const MedSchedule(mode: ScheduleMode.everyNHours, intervalHours: 8, times: ['06:00']));
    expect(times(m.dosesBetween(DateTime(2026, 10, 6), DateTime(2026, 10, 7))), ['6 06:00', '6 14:00', '6 22:00']);
  });

  test('as needed and inactive medications have no schedule', () {
    expect(med(const MedSchedule(mode: ScheduleMode.asNeeded)).dosesBetween(from, DateTime(2026, 11, 1)), isEmpty);
    expect(med(const MedSchedule.daily(['09:00'])).copyWith(active: false).dosesBetween(from, DateTime(2026, 11, 1)), isEmpty);
  });

  test('dose status: pending, missed after two hours, answered states', () {
    final dose = ScheduledDose(med(const MedSchedule.daily(['09:00'])), DateTime(2026, 10, 9, 9));
    expect(doseStatus(dose, null, DateTime(2026, 10, 9, 10)), DoseStatus.pending);
    expect(doseStatus(dose, null, DateTime(2026, 10, 9, 11, 1)), DoseStatus.missed);
  });

  test('labels and ids', () {
    expect(med(const MedSchedule.daily(['09:00']), amount: 2.5).copyWith(doseUnit: 'ml').doseLabel, '2,5 ml');
    expect(doseLogId('m1', DateTime.utc(2026, 10, 9, 6)), 'm1@2026-10-09T06:00:00Z');
  });

  group('dose actions', () {
    late AppDatabase db;
    late DoseActions actions;
    var changes = 0;
    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      changes = 0;
      actions = DoseActions(db, onChanged: () => changes++);
      await db.into(db.localMedications).insert(med(const MedSchedule.daily(['09:00']), stock: 10, amount: 2).toRow(1));
    });
    tearDown(() => db.close());

    Future<double?> stock() async => (await db.select(db.localMedications).getSingle()).stock;
    Future<DoseStatus> status(ScheduledDose dose) async {
      final logs = {for (final l in await db.select(db.localDoseLogs).get()) l.id: l};
      return doseStatus(dose, logs[dose.id], DateTime(2026, 10, 9, 9, 5));
    }

    test('taking uses stock once, undo returns it, the same dose can be taken again', () async {
      final m = Medication.fromRow(await db.select(db.localMedications).getSingle());
      final dose = m.dosesBetween(DateTime(2026, 10, 9), DateTime(2026, 10, 10)).single;

      await actions.take(dose);
      await actions.take(dose);
      expect(await stock(), 8);
      expect(await status(dose), DoseStatus.taken);

      await actions.undo(dose);
      expect(await stock(), 10);
      expect(await status(dose), DoseStatus.pending);
      final log = await db.select(db.localDoseLogs).getSingle();
      expect(log.deletedAtMs, isNull, reason: 'undo must not tombstone the sync document');

      await actions.skip(dose);
      expect(await status(dose), DoseStatus.skipped);
      expect(await stock(), 10);
      expect(changes, 4);
    });

    test('snooze is a state until it runs out', () async {
      final m = Medication.fromRow(await db.select(db.localMedications).getSingle());
      final dose = ScheduledDose(m, DateTime.now().subtract(const Duration(minutes: 5)));
      await actions.snooze(dose, 10);
      final log = await db.select(db.localDoseLogs).getSingle();
      expect(doseStatus(dose, log, DateTime.now()), DoseStatus.snoozed);
      expect(doseStatus(dose, log, DateTime.now().add(const Duration(minutes: 11))), DoseStatus.pending);
    });

    test('medication rows round-trip', () async {
      final original = med(const MedSchedule(mode: ScheduleMode.weekdays, weekdays: [2, 4], times: ['08:00', '20:00']), endsOn: DateTime(2026, 12, 31), stock: 30)
          .copyWith(form: 'capsule', mealRelation: 'after_meal', notes: 'Bol su', alarm: const AlarmSettings(fullScreen: false, maxRepeats: 5));
      await db.into(db.localMedications).insertOnConflictUpdate(original.copyWith(id: 'm2').toRow(5));
      final back = Medication.fromRow(await (db.select(db.localMedications)..where((t) => t.id.equals('m2'))).getSingle());
      expect(back.schedule, original.schedule);
      expect(back.alarm, original.alarm);
      expect(back.startsOn, DateTime(2026, 10, 5));
      expect(back.endsOn, DateTime(2026, 12, 31));
      expect(back.mealRelation, 'after_meal');
      expect(back.form, 'capsule');
    });
  });
}
