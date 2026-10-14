import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/events_repository.dart';
import 'package:lifebase_mobile/core/notes/note.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/storage/sync_collections.dart';
import 'package:lifebase_mobile/core/sync/local_sync.dart';
import 'package:lifebase_mobile/modules/notes/data/notes_repository.dart';

/// Records what was pushed; pull serves [pages] once.
class RecordingServer implements SyncTransport {
  final pushed = <SyncDocument>[];
  List<SyncDocument> pages = [];
  Future<void> Function()? beforePull;

  @override
  Future<PushResult> push(List<SyncDocument> changes) async {
    pushed.addAll(changes);
    return PushResult(applied: changes.map((c) => c.key).toSet(), stale: const [], cursor: 0);
  }

  @override
  Future<PullResult> pull(int since) async {
    await beforePull?.call();
    final page = pages;
    pages = [];
    return PullResult(changes: page, cursor: since + page.length, hasMore: false);
  }
}

void main() {
  late AppDatabase db;
  late EventsRepository events;
  late NotesRepository notes;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    events = EventsRepository(db, me: () => 7);
    notes = NotesRepository(db, events: events, defaultReminders: () => const [], me: () => 7);
  });
  tearDown(() => db.close());

  LocalSyncEngine sharedEngine(RecordingServer server) =>
      LocalSyncEngine(database: db, transport: server, collections: sharedSyncCollections(db), cursorKey: 'shared.cursor');

  test('everything goes to the household; nothing stays personal', () async {
    await notes.save(const Note(id: 'n', title: 'Market', kind: NoteKind.list));
    await notes.saveItem(const NoteItem(id: 'i1', noteId: 'n', content: 'Süt'));
    await events.save(CalendarEvent(id: 'e', title: 'Diş', startsAt: DateTime(2026, 10, 20, 9)));

    final personal = RecordingServer();
    final shared = RecordingServer();
    await LocalSyncEngine(database: db, transport: personal, collections: localSyncCollections(db)).run();
    await sharedEngine(shared).run();

    expect(personal.pushed, isEmpty);
    expect(shared.pushed.map((d) => d.key), unorderedEquals(['notes/n', 'note_items/i1', 'events/e']));
  });

  test('who added an item and whose phone reminds travel with it', () async {
    await events.save(CalendarEvent(id: 'e', title: 'Diş', startsAt: DateTime(2026, 10, 20, 9), notify: '3'));
    final shared = RecordingServer();
    await sharedEngine(shared).run();
    expect(shared.pushed.single.body, containsPair('created_by', 7));
    expect(shared.pushed.single.body, containsPair('notify', '3'));

    final other = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(other.close);
    await LocalSyncEngine(
      database: other,
      transport: RecordingServer()..pages = shared.pushed,
      collections: sharedSyncCollections(other),
    ).run();
    final pulled = CalendarEvent.fromRow(await other.select(other.localEvents).getSingle());
    expect((pulled.createdBy, pulled.notify), (7, '3'));
  });

  test('an edit by the other person keeps the original owner', () async {
    await notes.save(const Note(id: 'n', title: 'Market'));
    final theirs = NotesRepository(db, events: events, defaultReminders: () => const [], me: () => 9);
    await theirs.save(const Note(id: 'n', title: 'Market ve fırın'));
    final row = await db.select(db.localNotes).getSingle();
    expect((row.title, row.createdBy), ('Market ve fırın', 7));
  });

  test('a shared line pulled from the household lands in the shared space', () async {
    final shared = RecordingServer()
      ..pages = [
        SyncDocument(collection: 'note_items', id: 'x', updatedAt: DateTime.utc(2026, 10, 9), body: const {'note_id': 'ours', 'content': 'Ekmek', 'done': true, 'done_by': 2}),
      ];
    await sharedEngine(shared).run();
    final row = await db.select(db.localNoteItems).getSingle();
    expect((row.space, row.done, row.doneBy), ('household', true, 2));
  });

  test('a household change drops synced rows but keeps unsent edits', () async {
    await notes.save(const Note(id: 'sent', title: 'Gönderildi'));
    await events.save(CalendarEvent(id: 'e', title: 'Gönderildi', startsAt: DateTime(2026, 10, 20, 9)));
    await sharedEngine(RecordingServer()).run();
    await notes.save(const Note(id: 'unsent', title: 'Henüz gitmedi'));

    await clearSharedSpace(db);

    expect((await db.select(db.localNotes).get()).map((n) => n.id), ['unsent']);
    expect(await db.select(db.localEvents).get(), isEmpty);
  });

  test('joining a household queues everything already on the phone', () async {
    await db.into(db.localNotes).insert(LocalNotesCompanion.insert(id: 'old', updatedAtMs: 1, dirty: const Value(false), title: const Value('Eski')));
    await db.into(db.localEvents).insert(
          LocalEventsCompanion.insert(id: 'e', updatedAtMs: 1, title: 'Eski', startsAt: DateTime.utc(2026, 10, 1), dirty: const Value(false)),
        );

    await adoptIntoHousehold(db);

    final note = await db.select(db.localNotes).getSingle();
    expect((note.dirty, note.space), (true, 'household'));
    expect((await db.select(db.localEvents).getSingle()).dirty, isTrue);
  });
}
