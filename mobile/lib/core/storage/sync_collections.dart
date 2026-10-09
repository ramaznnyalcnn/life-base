import 'dart:convert';

import 'package:drift/drift.dart';

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

final noteCodec = SyncRowCodec<LocalNote>(
  meta: (r) => (id: r.id, updatedAtMs: r.updatedAtMs, deletedAtMs: r.deletedAtMs, dirty: r.dirty),
  toBody: (r) => {
    'title': r.title,
    'body': r.body,
    'kind': r.kind,
    'pinned': r.pinned,
    'color': r.color,
    'event_id': r.eventId,
    'archived': r.archived,
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
  ),
);

final noteItemCodec = SyncRowCodec<LocalNoteItem>(
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
  ),
);

List<SyncCollection> localSyncCollections(AppDatabase db) => [
      DriftSyncCollection(db, db.localEvents, SyncCollections.events, eventCodec),
      DriftSyncCollection(db, db.localMedications, SyncCollections.medications, medicationCodec),
      DriftSyncCollection(db, db.localDoseLogs, SyncCollections.doseLogs, doseLogCodec),
      DriftSyncCollection(db, db.localNotes, SyncCollections.notes, noteCodec),
      DriftSyncCollection(db, db.localNoteItems, SyncCollections.noteItems, noteItemCodec),
    ];
