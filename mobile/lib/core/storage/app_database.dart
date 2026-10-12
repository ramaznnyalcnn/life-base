import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/operation.dart';
import '../sync/queue_policy.dart';
import 'local_tables.dart';

export 'local_tables.dart';

part 'app_database.g.dart';

class CachedDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class QueuedOperations extends Table {
  TextColumn get requestId => text()();
  TextColumn get operationKey => text()();
  TextColumn get payload => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get conflictPayload => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {requestId};
}

@DriftDatabase(tables: [
  CachedDocuments,
  QueuedOperations,
  LocalEvents,
  LocalMedications,
  LocalDoseLogs,
  SyncStates,
  WalletAccounts,
  WalletTransactions,
  WalletTransfers,
  WalletStatementMarks,
  WalletScheduledPayments,
  WalletOutbox,
  LocalNotes,
  LocalNoteItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
      : super(executor ??
            driftDatabase(
              name: 'lifebase',
              // Flutter Web: SQLite compiled to WebAssembly, in a worker (web/).
              web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
            ));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            // Local-first calendar and medication data.
            await migrator.createTable(localEvents);
            await migrator.createTable(localMedications);
            await migrator.createTable(localDoseLogs);
            await migrator.createTable(syncStates);
          }
          if (from < 3) {
            // Wallet mirror and outbox.
            await migrator.createTable(walletAccounts);
            await migrator.createTable(walletTransactions);
            await migrator.createTable(walletTransfers);
            await migrator.createTable(walletStatementMarks);
            await migrator.createTable(walletOutbox);
          }
          if (from < 4) {
            // Notes and checklists.
            await migrator.createTable(localNotes);
            await migrator.createTable(localNoteItems);
          }
          if (from < 5) {
            // Planned wallet payments.
            await migrator.createTable(walletScheduledPayments);
          }
        },
      );

  Future<String?> syncState(String key) async =>
      (await (select(syncStates)..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSyncState(String key, String value) =>
      into(syncStates).insertOnConflictUpdate(SyncStatesCompanion.insert(key: key, value: value));

  /// Removes all local-first data, e.g. when signing out.
  Future<void> clearLocalData() => transaction(() async {
        await delete(localEvents).go();
        await delete(localMedications).go();
        await delete(localDoseLogs).go();
        await delete(syncStates).go();
        await delete(walletAccounts).go();
        await delete(walletTransactions).go();
        await delete(walletTransfers).go();
        await delete(walletStatementMarks).go();
        await delete(walletScheduledPayments).go();
        await delete(walletOutbox).go();
        await delete(localNotes).go();
        await delete(localNoteItems).go();
      });

  Future<void> cache(String key, String payload) => into(cachedDocuments)
      .insertOnConflictUpdate(CachedDocumentsCompanion.insert(
        key: key,
        payload: payload,
        updatedAt: DateTime.now().toUtc(),
      ));

  Future<String?> cached(String key) async =>
      (await (select(cachedDocuments)..where((row) => row.key.equals(key)))
              .getSingleOrNull())
          ?.payload;

  Future<void> clearCache() => delete(cachedDocuments).go();

  Future<void> enqueue({
    required String requestId,
    required String operationKey,
    required String payload,
  }) =>
      into(queuedOperations).insertOnConflictUpdate(
        QueuedOperationsCompanion.insert(
          requestId: requestId,
          operationKey: operationKey,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        ),
      );

  Future<List<QueuedOperation>> pending() async {
    final rows = await (select(queuedOperations)
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
    final outstanding = rows.where((row) => row.state != 'done').toList();
    final pendingCount = QueuePolicy.contiguousPending(
      outstanding.map((row) => row.state),
    ).length;
    return outstanding.take(pendingCount).toList();
  }

  Future<List<QueuedOperation>> conflicts() =>
      (select(queuedOperations)
            ..where((row) => row.state.equals('conflict'))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Stream<int> watchOutstandingCount() => select(queuedOperations)
      .watch()
      .map((rows) => rows.where((row) => row.state != 'done').length);

  Future<void> markDone(String requestId) =>
      (update(queuedOperations)..where((row) => row.requestId.equals(requestId)))
          .write(const QueuedOperationsCompanion(state: Value('done')));

  Future<void> markState(String requestId, String state, {String? conflict}) =>
      (update(queuedOperations)..where((row) => row.requestId.equals(requestId)))
          .write(QueuedOperationsCompanion(
        state: Value(state),
        conflictPayload: Value(conflict),
      ));

  Future<void> acceptServer(String requestId) => markDone(requestId);

  Future<void> resumePaused() =>
      (update(queuedOperations)..where((row) => row.state.equals('paused')))
          .write(const QueuedOperationsCompanion(state: Value('pending')));

  Future<void> retryWithVersion(String requestId, int entityVersion) async {
    final row = await (select(queuedOperations)
          ..where((item) => item.requestId.equals(requestId)))
        .getSingle();
    final operation = OperationEnvelope.decode(row.payload);
    final updated = OperationEnvelope(
      requestId: operation.requestId,
      operationKey: operation.operationKey,
      values: {...operation.values, 'expected_version': entityVersion},
    );
    await (update(queuedOperations)..where((item) => item.requestId.equals(requestId)))
        .write(QueuedOperationsCompanion(
      payload: Value(updated.encode()),
      state: const Value('pending'),
      conflictPayload: const Value(null),
    ));
  }
}
