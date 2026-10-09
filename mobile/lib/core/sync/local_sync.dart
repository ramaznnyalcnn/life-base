import 'package:drift/drift.dart';

import '../storage/app_database.dart';

/// One record as it travels to and from `/api/v3/sync`.
class SyncDocument {
  const SyncDocument({
    required this.collection,
    required this.id,
    required this.updatedAt,
    this.deleted = false,
    this.body,
    this.seq = 0,
  });

  factory SyncDocument.fromJson(Map<String, Object?> json) => SyncDocument(
        collection: json['collection']! as String,
        id: json['id']! as String,
        updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
        deleted: json['deleted'] as bool? ?? false,
        body: json['body'] == null ? null : Map<String, Object?>.from(json['body']! as Map),
        seq: (json['seq'] as num?)?.toInt() ?? 0,
      );

  final String collection;
  final String id;
  final DateTime updatedAt;
  final bool deleted;
  final Map<String, Object?>? body;
  final int seq;

  String get key => '$collection/$id';

  Map<String, Object?> toJson() => {
        'collection': collection,
        'id': id,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
        'body': deleted ? null : body,
      };
}

class PushResult {
  const PushResult({required this.applied, required this.stale, required this.cursor});
  final Set<String> applied;
  final List<SyncDocument> stale;
  final int cursor;
}

class PullResult {
  const PullResult({required this.changes, required this.cursor, required this.hasMore});
  final List<SyncDocument> changes;
  final int cursor;
  final bool hasMore;
}

/// The server is unreachable (no network, timeout, 5xx). Retry later.
class SyncOfflineException implements Exception {
  const SyncOfflineException();
}

/// The session token was rejected. Sync waits until the user signs in again.
class SyncUnauthorizedException implements Exception {
  const SyncUnauthorizedException();
}

/// The server refused the request itself (e.g. validation). Needs attention;
/// retrying unchanged will not help.
class SyncRejectedException implements Exception {
  const SyncRejectedException(this.statusCode);
  final int statusCode;
}

abstract interface class SyncTransport {
  Future<PushResult> push(List<SyncDocument> changes);
  Future<PullResult> pull(int since);
}

/// Bridges one local table to the document sync.
abstract interface class SyncCollection {
  String get name;

  /// Local rows the server has not accepted yet.
  Future<List<SyncDocument>> dirty();

  /// The server accepted [sent]; clear `dirty` unless the row changed since.
  Future<void> markClean(SyncDocument sent);

  /// A document from another device (pull): newest write wins, deletion is final.
  Future<void> applyRemote(SyncDocument remote);

  /// The server refused [sent] because its copy wins; adopt [server] unless
  /// the row was edited again after [sent] was read.
  Future<void> applyStale(SyncDocument server, SyncDocument sent);
}

/// How to turn one table's rows into document bodies and back.
class SyncRowCodec<R> {
  const SyncRowCodec({required this.meta, required this.toBody, required this.fromBody});

  final ({String id, int updatedAtMs, int? deletedAtMs, bool dirty}) Function(R row) meta;
  final Map<String, Object?> Function(R row) toBody;

  /// Builds a full row from a document body. Unknown keys are ignored and
  /// missing ones fall back to defaults, so older and newer clients coexist.
  final Insertable<R> Function(String id, Map<String, Object?> body, int updatedAtMs) fromBody;
}

class DriftSyncCollection<T extends SyncColumns, R> implements SyncCollection {
  DriftSyncCollection(this._db, this._table, this.name, this._codec);

  final AppDatabase _db;
  final TableInfo<T, R> _table;
  final SyncRowCodec<R> _codec;

  @override
  final String name;

  Future<R?> _find(String id) => (_db.select(_table)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _write(String id, Map<String, Expression<Object>> values) =>
      (_db.update(_table)..where((t) => t.id.equals(id))).write(RawValuesInsertable(values));

  @override
  Future<List<SyncDocument>> dirty() async {
    final rows = await (_db.select(_table)..where((t) => t.dirty.equals(true))).get();
    return [
      for (final row in rows)
        () {
          final meta = _codec.meta(row);
          final deleted = meta.deletedAtMs != null;
          return SyncDocument(
            collection: name,
            id: meta.id,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(meta.updatedAtMs, isUtc: true),
            deleted: deleted,
            body: deleted ? null : _codec.toBody(row),
          );
        }(),
    ];
  }

  @override
  Future<void> markClean(SyncDocument sent) =>
      (_db.update(_table)
            ..where((t) => t.id.equals(sent.id) & t.updatedAtMs.equals(sent.updatedAt.millisecondsSinceEpoch)))
          .write(RawValuesInsertable({'dirty': const Constant(false)}));

  @override
  Future<void> applyRemote(SyncDocument remote) => _db.transaction(() async {
        final local = await _find(remote.id);
        final remoteMs = remote.updatedAt.millisecondsSinceEpoch;
        if (local == null) {
          if (!remote.deleted) await _adopt(remote);
          return;
        }
        final meta = _codec.meta(local);
        if (meta.deletedAtMs != null && !meta.dirty) return; // Already gone here.
        if (remote.deleted) {
          await _tombstone(remote.id, remoteMs);
        } else if (!meta.dirty || remoteMs > meta.updatedAtMs) {
          await _adopt(remote);
        }
        // Otherwise the local edit is newer and will be pushed next.
      });

  @override
  Future<void> applyStale(SyncDocument server, SyncDocument sent) => _db.transaction(() async {
        final local = await _find(server.id);
        if (local != null && _codec.meta(local).updatedAtMs != sent.updatedAt.millisecondsSinceEpoch) return;
        if (server.deleted) {
          if (local != null) await _tombstone(server.id, server.updatedAt.millisecondsSinceEpoch);
        } else {
          await _adopt(server);
        }
      });

  Future<void> _adopt(SyncDocument doc) async {
    await _db.into(_table).insertOnConflictUpdate(_codec.fromBody(doc.id, doc.body ?? const {}, doc.updatedAt.millisecondsSinceEpoch));
    await _write(doc.id, {'dirty': const Constant(false), 'deleted_at_ms': const Constant(null)});
  }

  Future<void> _tombstone(String id, int atMs) => _write(id, {
        'deleted_at_ms': Constant(atMs),
        'updated_at_ms': Constant(atMs),
        'dirty': const Constant(false),
      });
}

enum SyncOutcomeKind { synced, offline, unauthorized, failed }

class SyncOutcome {
  const SyncOutcome(this.kind, {this.pushed = 0, this.pulled = 0, this.statusCode});
  final SyncOutcomeKind kind;
  final int pushed;
  final int pulled;

  /// HTTP status of a [SyncOutcomeKind.failed] run.
  final int? statusCode;
}

/// Push local changes, then pull everyone else's, for every collection.
class LocalSyncEngine {
  LocalSyncEngine({
    required AppDatabase database,
    required SyncTransport transport,
    required List<SyncCollection> collections,
    this.cursorKey = 'sync.cursor',
    this.batchSize = 200,
  })  : _database = database,
        _transport = transport,
        _collections = {for (final c in collections) c.name: c};

  final AppDatabase _database;
  final SyncTransport _transport;
  final Map<String, SyncCollection> _collections;
  final String cursorKey;
  final int batchSize;

  Future<SyncOutcome>? _running;

  /// Runs one sync; concurrent callers share the run in progress.
  Future<SyncOutcome> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<SyncOutcome> _run() async {
    try {
      final pushed = await _push();
      final pulled = await _pull();
      return SyncOutcome(SyncOutcomeKind.synced, pushed: pushed, pulled: pulled);
    } on SyncOfflineException {
      return const SyncOutcome(SyncOutcomeKind.offline);
    } on SyncUnauthorizedException {
      return const SyncOutcome(SyncOutcomeKind.unauthorized);
    } on SyncRejectedException catch (error) {
      return SyncOutcome(SyncOutcomeKind.failed, statusCode: error.statusCode);
    }
  }

  Future<int> _push() async {
    final pending = [for (final collection in _collections.values) ...await collection.dirty()];
    var accepted = 0;
    for (var start = 0; start < pending.length; start += batchSize) {
      final batch = pending.sublist(start, (start + batchSize).clamp(0, pending.length));
      final result = await _transport.push(batch);
      final sentByKey = {for (final doc in batch) doc.key: doc};
      for (final doc in batch) {
        if (result.applied.contains(doc.key)) {
          await _collections[doc.collection]!.markClean(doc);
          accepted += 1;
        }
      }
      for (final server in result.stale) {
        final sent = sentByKey[server.key];
        if (sent != null) await _collections[server.collection]?.applyStale(server, sent);
      }
    }
    return accepted;
  }

  Future<int> _pull() async {
    var cursor = int.tryParse(await _database.syncState(cursorKey) ?? '') ?? 0;
    var pulled = 0;
    while (true) {
      final page = await _transport.pull(cursor);
      for (final doc in page.changes) {
        await _collections[doc.collection]?.applyRemote(doc);
      }
      pulled += page.changes.length;
      cursor = page.cursor;
      await _database.setSyncState(cursorKey, '$cursor');
      if (!page.hasMore) return pulled;
    }
  }
}

/// Next write stamp for a row: now, but always after its previous stamp so a
/// later edit wins even if the clock did not move (or moved back).
int nextStamp(int? previousMs, {DateTime? now}) {
  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return previousMs != null && ms <= previousMs ? previousMs + 1 : ms;
}
