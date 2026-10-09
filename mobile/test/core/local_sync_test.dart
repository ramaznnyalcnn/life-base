import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/storage/sync_collections.dart';
import 'package:lifebase_mobile/core/sync/local_sync.dart';

/// In-memory stand-in for /api/v3/sync with the backend's rules: newest
/// updated_at wins, deletion is final, every stored change takes the next seq.
class FakeServer implements SyncTransport {
  final docs = <String, SyncDocument>{};
  var seq = 0;
  var offline = false;
  var pushCalls = 0;

  @override
  Future<PushResult> push(List<SyncDocument> changes) async {
    if (offline) throw const SyncOfflineException();
    pushCalls += 1;
    final applied = <String>{};
    final stale = <SyncDocument>[];
    for (final change in changes) {
      final existing = docs[change.key];
      if (existing == null || (!existing.deleted && change.updatedAt.isAfter(existing.updatedAt))) {
        docs[change.key] = _stored(change);
        applied.add(change.key);
      } else if (existing.deleted && change.deleted) {
        applied.add(change.key);
      } else {
        stale.add(existing);
      }
    }
    return PushResult(applied: applied, stale: stale, cursor: seq);
  }

  SyncDocument _stored(SyncDocument change) => SyncDocument(
        collection: change.collection,
        id: change.id,
        updatedAt: change.updatedAt,
        deleted: change.deleted,
        body: change.body,
        seq: ++seq,
      );

  @override
  Future<PullResult> pull(int since) async {
    if (offline) throw const SyncOfflineException();
    final changes = docs.values.where((d) => d.seq > since).toList()..sort((a, b) => a.seq.compareTo(b.seq));
    final page = changes.take(2).toList(); // Small pages exercise the cursor loop.
    return PullResult(changes: page, cursor: page.isEmpty ? since : page.last.seq, hasMore: changes.length > 2);
  }
}

class Device {
  Device(FakeServer server) : db = AppDatabase(executor: NativeDatabase.memory()) {
    engine = LocalSyncEngine(database: db, transport: server, collections: localSyncCollections(db));
  }

  final AppDatabase db;
  late final LocalSyncEngine engine;

  Future<void> saveEvent(String id, String title, {required int at}) => db.into(db.localEvents).insertOnConflictUpdate(
        LocalEventsCompanion.insert(
          id: id,
          title: title,
          startsAt: DateTime.utc(2026, 10, 9, 9),
          updatedAtMs: at,
          dirty: const Value(true),
        ),
      );

  Future<void> deleteEvent(String id, {required int at}) =>
      (db.update(db.localEvents)..where((t) => t.id.equals(id))).write(
        LocalEventsCompanion(deletedAtMs: Value(at), updatedAtMs: Value(at), dirty: const Value(true)),
      );

  Future<LocalEvent?> event(String id) => (db.select(db.localEvents)..where((t) => t.id.equals(id))).getSingleOrNull();
}

void main() {
  late FakeServer server;
  late Device phone;
  late Device tablet;

  setUp(() {
    server = FakeServer();
    phone = Device(server);
    tablet = Device(server);
  });

  tearDown(() async {
    await phone.db.close();
    await tablet.db.close();
  });

  test('a local event is pushed, marked clean and reaches another device', () async {
    await phone.saveEvent('e1', 'Diş hekimi', at: 1000);

    final outcome = await phone.engine.run();

    expect(outcome.kind, SyncOutcomeKind.synced);
    expect(outcome.pushed, 1);
    expect((await phone.event('e1'))!.dirty, isFalse);
    expect(server.docs['events/e1']!.body!['title'], 'Diş hekimi');

    await tablet.engine.run();
    final copy = (await tablet.event('e1'))!;
    expect(copy.title, 'Diş hekimi');
    expect(copy.dirty, isFalse);
    expect(copy.updatedAtMs, 1000);
  });

  test('concurrent offline edits converge on the newest one everywhere', () async {
    await phone.saveEvent('e1', 'v1', at: 1000);
    await phone.engine.run();
    await tablet.engine.run();

    await phone.saveEvent('e1', 'phone edit', at: 2000);
    await tablet.saveEvent('e1', 'tablet edit (newer)', at: 3000);
    await phone.engine.run();
    await tablet.engine.run();
    await phone.engine.run();

    expect((await phone.event('e1'))!.title, 'tablet edit (newer)');
    expect((await tablet.event('e1'))!.title, 'tablet edit (newer)');
    expect((await phone.event('e1'))!.dirty, isFalse);
  });

  test('an older edit pushed late adopts the server copy instead of looping', () async {
    await tablet.saveEvent('e1', 'newer', at: 5000);
    await tablet.engine.run();
    await phone.saveEvent('e1', 'older', at: 4000);

    await phone.engine.run();
    final calls = server.pushCalls;
    await phone.engine.run();

    expect((await phone.event('e1'))!.title, 'newer');
    expect((await phone.event('e1'))!.dirty, isFalse);
    expect(server.pushCalls, calls, reason: 'nothing left to push');
  });

  test('a deletion wins over a later edit from a stale device', () async {
    await phone.saveEvent('e1', 'v1', at: 1000);
    await phone.engine.run();
    await tablet.engine.run();

    await phone.deleteEvent('e1', at: 2000);
    await tablet.saveEvent('e1', 'edited offline', at: 9000);
    await phone.engine.run();
    await tablet.engine.run();

    expect((await tablet.event('e1'))!.deletedAtMs, isNotNull);
    expect((await tablet.event('e1'))!.dirty, isFalse);
    expect(server.docs['events/e1']!.deleted, isTrue);
  });

  test('an edit made while a push is in flight stays dirty', () async {
    await phone.saveEvent('e1', 'sent', at: 1000);
    final sent = (await localSyncCollections(phone.db).first.dirty()).single;
    await phone.saveEvent('e1', 'typed after sending', at: 1001);

    await localSyncCollections(phone.db).first.markClean(sent);

    expect((await phone.event('e1'))!.dirty, isTrue);
  });

  test('offline sync keeps changes queued and resumes later', () async {
    await phone.saveEvent('e1', 'offline', at: 1000);
    server.offline = true;

    expect((await phone.engine.run()).kind, SyncOutcomeKind.offline);
    expect((await phone.event('e1'))!.dirty, isTrue);

    server.offline = false;
    expect((await phone.engine.run()).pushed, 1);
  });

  test('pull follows the cursor across pages and remembers it', () async {
    for (var i = 0; i < 5; i++) {
      await phone.saveEvent('e$i', 'event $i', at: 1000 + i);
    }
    await phone.engine.run();

    final outcome = await tablet.engine.run();

    expect(outcome.pulled, 5);
    expect(await tablet.db.select(tablet.db.localEvents).get(), hasLength(5));
    expect(await tablet.db.syncState('sync.cursor'), '5');
    expect((await tablet.engine.run()).pulled, 0);
  });

  test('medications and dose logs round-trip through their document bodies', () async {
    await phone.db.into(phone.db.localMedications).insert(LocalMedicationsCompanion.insert(
          id: 'm1',
          name: 'D vitamini',
          schedule: '{"mode":"times","times":["09:00","21:30"]}',
          startsOn: DateTime.utc(2026, 10, 1),
          updatedAtMs: 1000,
          doseAmount: const Value(2),
          stock: const Value(30),
        ));
    final scheduled = DateTime.utc(2026, 10, 9, 6);
    await phone.db.into(phone.db.localDoseLogs).insert(LocalDoseLogsCompanion.insert(
          id: 'm1@${scheduled.toIso8601String()}',
          medicationId: 'm1',
          scheduledFor: scheduled,
          status: 'taken',
          updatedAtMs: 1001,
          actedAt: Value(scheduled.add(const Duration(minutes: 3))),
        ));
    await phone.engine.run();
    await tablet.engine.run();

    final med = await tablet.db.select(tablet.db.localMedications).getSingle();
    expect(med.name, 'D vitamini');
    expect(med.doseAmount, 2);
    expect(med.stock, 30);
    expect(med.schedule, '{"mode":"times","times":["09:00","21:30"]}');
    final dose = await tablet.db.select(tablet.db.localDoseLogs).getSingle();
    expect(dose.status, 'taken');
    // Drift hands DateTimes back in local time; the instant must match.
    expect(dose.scheduledFor.isAtSameMomentAs(scheduled), isTrue);
  });

  test('concurrent run() calls share one sync', () async {
    await phone.saveEvent('e1', 'x', at: 1000);

    await Future.wait([phone.engine.run(), phone.engine.run()]);

    expect(server.pushCalls, 1);
  });

  test('write stamps always move forward', () {
    final now = DateTime.fromMillisecondsSinceEpoch(5000);
    expect(nextStamp(null, now: now), 5000);
    expect(nextStamp(4000, now: now), 5000);
    expect(nextStamp(5000, now: now), 5001);
    expect(nextStamp(9000, now: now), 9001, reason: 'clock moved back');
  });
}
