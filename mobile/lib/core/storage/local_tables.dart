import 'package:drift/drift.dart';

/// Columns every local-first table carries for document sync.
///
/// `updatedAtMs` is the last-writer-wins clock (milliseconds: two edits in
/// the same second must still order). `deletedAtMs` marks a tombstone and
/// `dirty` means the row has changes the server has not accepted yet.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get updatedAtMs => integer()();
  IntColumn get deletedAtMs => integer().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Calendar events. Reminders and recurrence travel with the event as JSON so
/// one event is one sync document.
class LocalEvents extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().nullable()();
  BoolColumn get important => boolean().withDefault(const Constant(false))();

  /// `{"freq": "daily|weekly|monthly|everyNDays", "interval": 1, "weekdays": [1,3], "until": "..."}`
  TextColumn get recurrence => text().nullable()();

  /// `[{"offsetMinutes": 10, "priority": "normal"}, {"at": "2026-10-09T08:00:00Z"}]`
  TextColumn get reminders => text().withDefault(const Constant('[]'))();
}

class LocalMedications extends Table with SyncColumns {
  TextColumn get name => text()();

  /// tablet, capsule, syrup, drops, injection, other
  TextColumn get form => text().withDefault(const Constant('tablet'))();
  RealColumn get doseAmount => real().withDefault(const Constant(1))();
  TextColumn get doseUnit => text().withDefault(const Constant('tablet'))();

  /// before_meal, after_meal, with_meal, empty_stomach, any
  TextColumn get mealRelation => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// `{"mode": "times|weekdays|everyNDays|everyNHours|asNeeded", "times": ["09:00"], ...}`
  TextColumn get schedule => text()();
  DateTimeColumn get startsOn => dateTime()();
  DateTimeColumn get endsOn => dateTime().nullable()();
  RealColumn get stock => real().nullable()();
  RealColumn get stockAlert => real().nullable()();

  /// `{"fullScreen": true, "snoozeMinutes": 10, "repeatEveryMinutes": 5, "maxRepeats": 3}`
  TextColumn get alarm => text().withDefault(const Constant('{}'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// One row per scheduled dose that was acted on. The id is
/// `<medicationId>@<scheduledFor UTC ISO>`, so the same dose marked on two
/// devices converges on one document.
class LocalDoseLogs extends Table with SyncColumns {
  TextColumn get medicationId => text()();
  DateTimeColumn get scheduledFor => dateTime()();

  /// taken, snoozed, skipped
  TextColumn get status => text()();
  DateTimeColumn get actedAt => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
}

/// Small key/value store for sync bookkeeping (pull cursor, last run).
class SyncStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
