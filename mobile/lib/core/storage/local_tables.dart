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

/// Notes and checklists. `space` is `me` (backed up to this account) or
/// `household` (shared with the household).
class LocalNotes extends Table with SyncColumns {
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// note, list
  TextColumn get kind => text().withDefault(const Constant('note'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().nullable()();

  /// The calendar event made from this note, if any.
  TextColumn get eventId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get space => text().withDefault(const Constant('me'))();
}

/// Checklist lines, one document each, so two people can tick different
/// lines of the same list at once.
class LocalNoteItems extends Table with SyncColumns {
  TextColumn get noteId => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  RealColumn get position => real().withDefault(const Constant(0))();

  /// User id that ticked it (shared lists).
  IntColumn get doneBy => integer().nullable()();
  TextColumn get space => text().withDefault(const Constant('me'))();
}

/// Small key/value store for sync bookkeeping (pull cursor, last run).
class SyncStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

// Wallet: a mirror of the server-authoritative wallet (pull), plus an outbox
// of writes not yet confirmed. Money is integer kuruş.

@DataClassName('WalletAccountRow')
class WalletAccounts extends Table {
  TextColumn get id => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get ownerId => integer()();
  TextColumn get name => text()();

  /// cash, bank, credit_card
  TextColumn get type => text()();
  TextColumn get bank => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('TRY'))();

  /// Cards: minus the debt (available = limit + balance).
  IntColumn get balanceCents => integer()();
  IntColumn get openingCents => integer().withDefault(const Constant(0))();
  IntColumn get limitCents => integer().nullable()();
  IntColumn get statementDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();

  /// personal, shared
  TextColumn get visibility => text().withDefault(const Constant('personal'))();
  TextColumn get last4 => text().nullable()();
  TextColumn get network => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get iban => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WalletTransactionRow')
class WalletTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();

  /// expense, income, payment
  TextColumn get kind => text()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get category => text().nullable()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get statementMonth => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdBy => integer()();
  TextColumn get installmentGroup => text().nullable()();
  IntColumn get installmentIndex => integer().nullable()();
  IntColumn get installmentCount => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WalletTransferRow')
class WalletTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get fromAccountId => text()();
  TextColumn get toAccountId => text()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get createdBy => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Manual "paid" override of a card statement; id `<accountId>:<yyyy-MM>`.
@DataClassName('WalletMarkRow')
class WalletStatementMarks extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  DateTimeColumn get month => dateTime()();
  BoolColumn get paid => boolean()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Wallet writes waiting for the server, oldest first. Each names the
/// accounts it touches: a write waits for earlier writes on the same account,
/// and a conflict or failure holds only those accounts.
@DataClassName('WalletOutboxRow')
class WalletOutbox extends Table {
  TextColumn get requestId => text()();

  /// Queue order (timestamps are only second-precise).
  IntColumn get seq => integer()();
  TextColumn get operationKey => text()();

  /// The full operation envelope (request_id, operation_key, values).
  TextColumn get payload => text()();

  /// Comma-separated account ids.
  TextColumn get accountKeys => text()();

  /// pending, sent (accepted, waiting for the pull that includes it),
  /// conflict, failed
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// 409: the server's current record; failed: the error message.
  TextColumn get detail => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {requestId};
}
