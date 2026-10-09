import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/calendar/events_repository.dart';
import 'package:lifebase_mobile/core/notes/note.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/storage/sync_collections.dart';
import 'package:lifebase_mobile/core/sync/local_sync.dart';
import 'package:lifebase_mobile/modules/notes/data/notes_repository.dart';

/// Records what was pushed; pull serves [pages] once.
class RecordingServer implements SyncTransport {
  final pushed = <String>[];
  List<SyncDocument> pages = [];
  Future<void> Function()? beforePull;

  @override
  Future<PushResult> push(List<SyncDocument> changes) async {
    pushed.addAll(changes.map((c) => c.key));
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
  late NotesRepository notes;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    notes = NotesRepository(db, events: EventsRepository(db), defaultReminders: () => const []);
  });
  tearDown(() => db.close());

  test('personal and shared sync each push only their own space', () async {
    await notes.save(const Note(id: 'mine', title: 'Kişisel'));
    await notes.save(const Note(id: 'ours', title: 'Market', kind: NoteKind.list, shared: true));
    await notes.saveItem(const NoteItem(id: 'i1', noteId: 'ours', content: 'Süt'), shared: true);

    final personal = RecordingServer();
    final shared = RecordingServer();
    await LocalSyncEngine(database: db, transport: personal, collections: localSyncCollections(db)).run();
    await LocalSyncEngine(database: db, transport: shared, collections: sharedSyncCollections(db), cursorKey: 'shared.cursor').run();

    expect(personal.pushed, ['notes/mine']);
    expect(shared.pushed, unorderedEquals(['notes/ours', 'note_items/i1']));
  });

  test('a shared line pulled from the household lands in the shared space', () async {
    final shared = RecordingServer()
      ..pages = [
        SyncDocument(collection: 'note_items', id: 'x', updatedAt: DateTime.utc(2026, 10, 9), body: const {'note_id': 'ours', 'content': 'Ekmek', 'done': true, 'done_by': 2}),
      ];
    await LocalSyncEngine(database: db, transport: shared, collections: sharedSyncCollections(db), cursorKey: 'shared.cursor').run();
    final row = await db.select(db.localNoteItems).getSingle();
    expect((row.space, row.done, row.doneBy), ('household', true, 2));
  });

  test('a reset drops the old household rows before the snapshot', () async {
    await notes.save(const Note(id: 'old', title: 'Eski hane', shared: true));
    await notes.save(const Note(id: 'mine', title: 'Kişisel'));
    final shared = RecordingServer()..beforePull = () => clearSharedSpace(db);
    await LocalSyncEngine(database: db, transport: shared, collections: sharedSyncCollections(db), cursorKey: 'shared.cursor').run();
    expect((await db.select(db.localNotes).get()).map((n) => n.id), ['mine']);
  });

  test('sharing moves the note and its lines under new ids', () async {
    await notes.save(const Note(id: 'n', title: 'Market', kind: NoteKind.list));
    await notes.saveItem(const NoteItem(id: 'i', noteId: 'n', content: 'Süt', position: 1));

    final moved = await notes.setShared(const Note(id: 'n', title: 'Market', kind: NoteKind.list), shared: true);

    final live = await (db.select(db.localNotes)..where((t) => t.deletedAtMs.isNull())).get();
    expect(live.single.id, moved.id);
    expect(live.single.space, 'household');
    final items = await (db.select(db.localNoteItems)..where((t) => t.deletedAtMs.isNull())).get();
    expect((items.single.noteId, items.single.content, items.single.space), (moved.id, 'Süt', 'household'));
    final old = await (db.select(db.localNotes)..where((t) => t.id.equals('n'))).getSingle();
    expect(old.deletedAtMs, isNotNull);
  });
}
