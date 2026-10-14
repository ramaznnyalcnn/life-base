import 'dart:convert';

import 'package:drift/drift.dart';

import '../household/household.dart';
import '../sync/local_sync.dart';
import 'app_database.dart';

/// Collection names shared with the server's `SYNC_COLLECTIONS`.
abstract final class SyncCollections {
  static const events = 'events';
  static const medications = 'medications';
  static const doseLogs = 'dose_logs';
  static const notes = 'notes';
  static const noteItems = 'note_items';
}

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();
DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
double? _num(Object? value) => value is num ? value.toDouble() : null;
Object? _json(String? raw) => raw == null ? null : jsonDecode(raw);
String? _encode(Object? value) => value == null ? null : jsonEncode(value);
int? _int(Object? value) => value is num ? value.toInt() : null;
String _notify(Object? value) => value is String && value.isNotEmpty ? value : notifyAll;

final eventCodec = SyncRowCodec<LocalEvent>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'title': r.title,
    'notes': r.notes,
    'starts_at': _iso(r.startsAt),
    'ends_at': _iso(r.endsAt),
    'all_day': r.allDay,
    'color': r.color,
    'important': r.important,
    'recurrence': _json(r.recurrence),
    'reminders': _json(r.reminders),
    'created_by': r.createdBy,
    'notify': r.notify,
  },
  fromBody: (id, b, ms) => LocalEventsCompanion.insert(
    id: id,
    updatedAtMs: ms,
    title: b['title'] as String? ?? '',
    notes: Value(b['notes'] as String?),
    startsAt: _date(b['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    endsAt: Value(_date(b['ends_at'])),
    allDay: Value(b['all_day'] == true),
    color: Value((b['color'] as num?)?.toInt()),
    important: Value(b['important'] == true),
    recurrence: Value(_encode(b['recurrence'])),
    reminders: Value(_encode(b['reminders'] ?? const []) ?? '[]'),
    createdBy: Value(_int(b['created_by'])),
    notify: Value(_notify(b['notify'])),
  ),
);

final medicationCodec = SyncRowCodec<LocalMedication>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'name': r.name,
    'form': r.form,
    'dose_amount': r.doseAmount,
    'dose_unit': r.doseUnit,
    'meal_relation': r.mealRelation,
    'notes': r.notes,
    'schedule': _json(r.schedule),
    'starts_on': _iso(r.startsOn),
    'ends_on': _iso(r.endsOn),
    'stock': r.stock,
    'stock_alert': r.stockAlert,
    'alarm': _json(r.alarm),
    'active': r.active,
    'created_by': r.createdBy,
    'notify': r.notify,
  },
  fromBody: (id, b, ms) => LocalMedicationsCompanion.insert(
    id: id,
    updatedAtMs: ms,
    name: b['name'] as String? ?? '',
    form: Value(b['form'] as String? ?? 'tablet'),
    doseAmount: Value(_num(b['dose_amount']) ?? 1),
    doseUnit: Value(b['dose_unit'] as String? ?? 'tablet'),
    mealRelation: Value(b['meal_relation'] as String?),
    notes: Value(b['notes'] as String?),
    schedule: _encode(b['schedule'] ?? const {'mode': 'asNeeded'})!,
    startsOn: _date(b['starts_on']) ?? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    endsOn: Value(_date(b['ends_on'])),
    stock: Value(_num(b['stock'])),
    stockAlert: Value(_num(b['stock_alert'])),
    alarm: Value(_encode(b['alarm'] ?? const {}) ?? '{}'),
    active: Value(b['active'] != false),
    createdBy: Value(_int(b['created_by'])),
    notify: Value(_notify(b['notify'])),
  ),
);

final doseLogCodec = SyncRowCodec<LocalDoseLog>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'medication_id': r.medicationId,
    'scheduled_for': _iso(r.scheduledFor),
    'status': r.status,
    'acted_at': _iso(r.actedAt),
    'snoozed_until': _iso(r.snoozedUntil),
  },
  fromBody: (id, b, ms) => LocalDoseLogsCompanion.insert(
    id: id,
    updatedAtMs: ms,
    medicationId: b['medication_id'] as String? ?? id.split('@').first,
    scheduledFor: _date(b['scheduled_for']) ?? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    status: b['status'] as String? ?? 'taken',
    actedAt: Value(_date(b['acted_at'])),
    snoozedUntil: Value(_date(b['snoozed_until'])),
  ),
);

/// Notes of one space: `me` (personal sync) or `household` (shared sync).
SyncRowCodec<LocalNote> noteCodecFor(String space) => SyncRowCodec<LocalNote>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'title': r.title,
    'body': r.body,
    'kind': r.kind,
    'pinned': r.pinned,
    'color': r.color,
    'event_id': r.eventId,
    'archived': r.archived,
    'created_by': r.createdBy,
  },
  fromBody: (id, b, ms) => LocalNotesCompanion.insert(
    id: id,
    updatedAtMs: ms,
    title: Value(b['title'] as String? ?? ''),
    body: Value(b['body'] as String? ?? ''),
    kind: Value(b['kind'] as String? ?? 'note'),
    pinned: Value(b['pinned'] == true),
    color: Value((b['color'] as num?)?.toInt()),
    eventId: Value(b['event_id'] as String?),
    archived: Value(b['archived'] == true),
    space: Value(space),
    createdBy: Value(_int(b['created_by'])),
  ),
);

SyncRowCodec<LocalNoteItem> noteItemCodecFor(String space) => SyncRowCodec<LocalNoteItem>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'note_id': r.noteId,
    'content': r.content,
    'done': r.done,
    'position': r.position,
    'done_by': r.doneBy,
  },
  fromBody: (id, b, ms) => LocalNoteItemsCompanion.insert(
    id: id,
    updatedAtMs: ms,
    noteId: b['note_id'] as String? ?? '',
    content: Value(b['content'] as String? ?? ''),
    done: Value(b['done'] == true),
    position: Value(_num(b['position']) ?? 0),
    doneBy: Value((b['done_by'] as num?)?.toInt()),
    space: Value(space),
  ),
);

/// Backed up to this account alone: nothing any more, everything is
/// household-shared (see [sharedSyncCollections]).
List<SyncCollection> localSyncCollections(AppDatabase db) => const [];

/// What the household shares: everything local-first.
List<SyncCollection> sharedSyncCollections(AppDatabase db) => [
      DriftSyncCollection(db, db.localEvents, SyncCollections.events, eventCodec),
      DriftSyncCollection(db, db.localMedications, SyncCollections.medications, medicationCodec),
      DriftSyncCollection(db, db.localDoseLogs, SyncCollections.doseLogs, doseLogCodec),
      DriftSyncCollection(db, db.localNotes, SyncCollections.notes, noteCodecFor('household')),
      DriftSyncCollection(db, db.localNoteItems, SyncCollections.noteItems, noteItemCodecFor('household')),
    ];

/// Joined a household for the first time: this phone's data goes to it.
/// Every row is queued again, notes from before sharing included.
Future<void> adoptIntoHousehold(AppDatabase db) => db.transaction(() async {
      await db.update(db.localEvents).write(const LocalEventsCompanion(dirty: Value(true)));
      await db.update(db.localMedications).write(const LocalMedicationsCompanion(dirty: Value(true)));
      await db.update(db.localDoseLogs).write(const LocalDoseLogsCompanion(dirty: Value(true)));
      await db.update(db.localNotes).write(const LocalNotesCompanion(dirty: Value(true), space: Value('household')));
      await db.update(db.localNoteItems).write(const LocalNoteItemsCompanion(dirty: Value(true), space: Value('household')));
    });

/// Drops the shared data the server has (left the household, or it
/// changed). Unsent edits stay and go to whichever household comes next.
Future<void> clearSharedSpace(AppDatabase db) => db.transaction(() async {
      await (db.delete(db.localEvents)..where((t) => t.dirty.not())).go();
      await (db.delete(db.localMedications)..where((t) => t.dirty.not())).go();
      await (db.delete(db.localDoseLogs)..where((t) => t.dirty.not())).go();
      await (db.delete(db.localNotes)..where((t) => t.dirty.not())).go();
      await (db.delete(db.localNoteItems)..where((t) => t.dirty.not())).go();
    });
