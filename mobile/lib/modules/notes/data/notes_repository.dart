import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/calendar/events_repository.dart';
import '../../../core/calendar/reminder_defaults.dart';
import '../../../core/notes/date_hint.dart';
import '../../../core/notes/note.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/local_sync.dart';
import '../../../core/sync/sync_controller.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) => NotesRepository(
      ref.watch(databaseProvider),
      events: ref.watch(eventsRepositoryProvider),
      defaultReminders: () => ref.read(defaultRemindersProvider),
      onChanged: () => ref.read(syncControllerProvider.notifier).requestSync(),
    ));

/// Note and checklist writes; every write is stamped and queued for sync.
class NotesRepository {
  NotesRepository(this._db, {required EventsRepository events, required List<ReminderSpec> Function() defaultReminders, void Function()? onChanged})
      : _events = events,
        _defaultReminders = defaultReminders,
        _onChanged = onChanged ?? (() {});

  final AppDatabase _db;
  final EventsRepository _events;
  final List<ReminderSpec> Function() _defaultReminders;
  final void Function() _onChanged;

  String newId() => const Uuid().v4();

  Future<LocalNote?> _note(String id) => (_db.select(_db.localNotes)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<LocalNoteItem?> _item(String id) => (_db.select(_db.localNoteItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> save(Note note) async {
    await _db.transaction(() async {
      final previous = await _note(note.id);
      await _db.into(_db.localNotes).insertOnConflictUpdate(LocalNotesCompanion.insert(
            id: note.id,
            updatedAtMs: nextStamp(previous?.updatedAtMs),
            deletedAtMs: const Value(null),
            dirty: const Value(true),
            title: Value(note.title.trim()),
            body: Value(note.body),
            kind: Value(note.kind.name),
            pinned: Value(note.pinned),
            color: Value(note.color),
            eventId: Value(note.eventId),
            archived: Value(note.archived),
            space: Value(note.shared ? 'household' : 'me'),
          ));
    });
    await _syncEvent(note);
    _onChanged();
  }

  /// Deletes the note and its lines. A calendar event made from it stays.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final row = await _note(id);
      if (row == null) return;
      final stamp = nextStamp(row.updatedAtMs);
      await (_db.update(_db.localNotes)..where((t) => t.id.equals(id)))
          .write(LocalNotesCompanion(deletedAtMs: Value(stamp), updatedAtMs: Value(stamp), dirty: const Value(true)));
      for (final item in await (_db.select(_db.localNoteItems)..where((t) => t.noteId.equals(id) & t.deletedAtMs.isNull())).get()) {
        final itemStamp = nextStamp(item.updatedAtMs);
        await (_db.update(_db.localNoteItems)..where((t) => t.id.equals(item.id)))
            .write(LocalNoteItemsCompanion(deletedAtMs: Value(itemStamp), updatedAtMs: Value(itemStamp), dirty: const Value(true)));
      }
    });
    _onChanged();
  }

  // Checklist ---------------------------------------------------------------

  Future<void> saveItem(NoteItem item, {bool shared = false}) async {
    await _db.transaction(() async {
      final previous = await _item(item.id);
      await _db.into(_db.localNoteItems).insertOnConflictUpdate(LocalNoteItemsCompanion.insert(
            id: item.id,
            noteId: item.noteId,
            updatedAtMs: nextStamp(previous?.updatedAtMs),
            deletedAtMs: const Value(null),
            dirty: const Value(true),
            content: Value(item.content),
            done: Value(item.done),
            position: Value(item.position),
            doneBy: Value(item.doneBy),
            space: Value(shared ? 'household' : 'me'),
          ));
    });
    _onChanged();
  }

  Future<void> deleteItem(String id) async {
    await _db.transaction(() async {
      final row = await _item(id);
      if (row == null) return;
      final stamp = nextStamp(row.updatedAtMs);
      await (_db.update(_db.localNoteItems)..where((t) => t.id.equals(id)))
          .write(LocalNoteItemsCompanion(deletedAtMs: Value(stamp), updatedAtMs: Value(stamp), dirty: const Value(true)));
    });
    _onChanged();
  }

  // Calendar ----------------------------------------------------------------

  /// Turns the note into a calendar event at [hint] and links them.
  Future<Note> addToCalendar(Note note, DateHint hint) async {
    final text = note.title.trim().isNotEmpty ? note.title : note.body.trim().split('\n').first;
    // The hint may come from another line; only strip date words found here.
    final own = findDateHint(text, hint.start);
    final title = own == null ? text.trim() : withoutHint(text, own);
    final event = CalendarEvent(
      id: _events.newId(),
      title: title.isEmpty ? 'Not' : title,
      notes: _eventNotes(note),
      startsAt: hint.start,
      endsAt: hint.hasTime ? hint.start.add(const Duration(hours: 1)) : null,
      allDay: !hint.hasTime,
      reminders: _defaultReminders(),
    );
    await _events.save(event);
    final linked = note.copyWith(eventId: event.id);
    await save(linked);
    return linked;
  }

  /// Unlinks the event; [deleteEvent] also removes it from the calendar.
  Future<Note> removeFromCalendar(Note note, {required bool deleteEvent}) async {
    if (deleteEvent && note.eventId != null) await _events.delete(note.eventId!);
    final unlinked = note.copyWith(clearEvent: true);
    await save(unlinked);
    return unlinked;
  }

  /// Keeps a linked event's text in step with the note (its time stays as
  /// the calendar has it).
  Future<void> _syncEvent(Note note) async {
    final eventId = note.eventId;
    if (eventId == null) return;
    final event = await _events.find(eventId);
    if (event == null) return;
    final notes = _eventNotes(note);
    if (event.notes != notes) await _events.save(event.copyWith(notes: notes));
  }

  static String? _eventNotes(Note note) {
    final body = note.body.trim();
    return body.isEmpty ? null : body;
  }
}
