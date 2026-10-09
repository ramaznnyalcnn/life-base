import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/calendar_store.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/modules/calendar/data/events_repository.dart';

void main() {
  late AppDatabase db;
  late EventsRepository repo;
  var changes = 0;
  var ids = 0;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    changes = 0;
    ids = 0;
    repo = EventsRepository(db, onChanged: () => changes++, newId: () => 'new${++ids}');
  });
  tearDown(() => db.close());

  Future<List<CalendarEvent>> live() async =>
      (await (db.select(db.localEvents)..where((t) => t.deletedAtMs.isNull())).get()).map(CalendarEvent.fromRow).toList();

  Future<List<String>> occurrences() async => occurrencesIn(await live(), DateTime(2026, 10, 1), DateTime(2026, 10, 31))
      .map((o) => '${o.event.title} ${o.start.day}@${o.start.hour}')
      .toList();

  final daily = CalendarEvent(
    id: 's',
    title: 'Spor',
    startsAt: DateTime(2026, 10, 5, 18),
    endsAt: DateTime(2026, 10, 5, 19),
    recurrence: RecurrenceRule(freq: RecurrenceFreq.daily, until: DateTime(2026, 10, 9)),
    reminders: const [ReminderSpec.before(Duration(minutes: 30))],
  );

  EventOccurrence on(CalendarEvent e, int day) => e.occurrencesBetween(DateTime(2026, 10, day), DateTime(2026, 10, day)).single;

  test('save round-trips every field and marks the row for sync', () async {
    await repo.save(daily.copyWith(notes: 'Salon', color: 0xFF2F5E9E, important: true));

    final row = await db.select(db.localEvents).getSingle();
    expect(row.dirty, isTrue);
    expect(changes, 1);
    final back = CalendarEvent.fromRow(row);
    expect(back.startsAt, DateTime(2026, 10, 5, 18));
    expect(back.notes, 'Salon');
    expect(back.recurrence, daily.recurrence);
    expect(back.reminders, daily.reminders);
    expect(back.important, isTrue);
  });

  test('all-day events keep their date regardless of timezone', () async {
    await repo.save(CalendarEvent(id: 'a', title: 'Bayram', startsAt: DateTime(2026, 10, 29), allDay: true));
    expect((await live()).single.startsAt, DateTime(2026, 10, 29));
  });

  test('edit only this occurrence: series skips that day, a one-off takes its place', () async {
    await repo.save(daily);
    final occurrence = on(daily, 7);

    await repo.updateOccurrence(occurrence, daily.copyWith(title: 'Spor (geç)', startsAt: DateTime(2026, 10, 7, 20), endsAt: DateTime(2026, 10, 7, 21)), SeriesScope.thisOne);

    expect(await occurrences(), ['Spor 5@18', 'Spor 6@18', 'Spor (geç) 7@20', 'Spor 8@18', 'Spor 9@18']);
  });

  test('edit this and following: series ends the day before, a new series continues', () async {
    await repo.save(daily);

    await repo.updateOccurrence(on(daily, 8), daily.copyWith(startsAt: DateTime(2026, 10, 8, 7), endsAt: DateTime(2026, 10, 8, 8)), SeriesScope.thisAndFollowing);

    expect(await occurrences(), ['Spor 5@18', 'Spor 6@18', 'Spor 7@18', 'Spor 8@7', 'Spor 9@7']);
  });

  test('edit all moves the whole series by the same amount', () async {
    await repo.save(daily);

    await repo.updateOccurrence(on(daily, 7), daily.copyWith(startsAt: DateTime(2026, 10, 7, 17), endsAt: DateTime(2026, 10, 7, 18)), SeriesScope.all);

    expect(await occurrences(), ['Spor 5@17', 'Spor 6@17', 'Spor 7@17', 'Spor 8@17', 'Spor 9@17']);
    expect(await live(), hasLength(1));
  });

  test('delete scopes', () async {
    await repo.save(daily);
    await repo.deleteOccurrence(on(daily, 6), SeriesScope.thisOne);
    expect(await occurrences(), ['Spor 5@18', 'Spor 7@18', 'Spor 8@18', 'Spor 9@18']);

    final series = (await live()).single;
    await repo.deleteOccurrence(on(series, 8), SeriesScope.thisAndFollowing);
    expect(await occurrences(), ['Spor 5@18', 'Spor 7@18']);

    await repo.deleteOccurrence(on((await live()).single, 7), SeriesScope.all);
    expect(await live(), isEmpty);
    expect((await db.select(db.localEvents).getSingle()).dirty, isTrue, reason: 'tombstone waits for sync');
  });
}
