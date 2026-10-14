import 'package:flutter/foundation.dart';

import '../storage/app_database.dart';

enum NoteKind { note, list }

@immutable
class Note {
  const Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.kind = NoteKind.note,
    this.pinned = false,
    this.color,
    this.eventId,
    this.archived = false,
    this.shared = true,
    this.updatedAtMs = 0,
    this.createdBy,
  });

  factory Note.fromRow(LocalNote row) => Note(
        id: row.id,
        title: row.title,
        body: row.body,
        kind: row.kind == 'list' ? NoteKind.list : NoteKind.note,
        pinned: row.pinned,
        color: row.color,
        eventId: row.eventId,
        archived: row.archived,
        shared: row.space == 'household',
        updatedAtMs: row.updatedAtMs,
        createdBy: row.createdBy,
      );

  final String id;
  final String title;
  final String body;
  final NoteKind kind;
  final bool pinned;
  final int? color;

  /// Calendar event made from this note.
  final String? eventId;
  final bool archived;

  /// Shared with the household (every note is, since everything is shared;
  /// only rows from before that are not).
  final bool shared;
  final int updatedAtMs;

  /// Household member who added it.
  final int? createdBy;

  bool get isList => kind == NoteKind.list;

  /// Title, or the first line of the text.
  String get heading {
    if (title.trim().isNotEmpty) return title.trim();
    final line = body.trim().split('\n').first.trim();
    return line;
  }

  Note copyWith({
    String? title,
    String? body,
    NoteKind? kind,
    bool? pinned,
    int? color,
    bool clearColor = false,
    String? eventId,
    bool clearEvent = false,
    bool? archived,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        kind: kind ?? this.kind,
        pinned: pinned ?? this.pinned,
        color: clearColor ? null : color ?? this.color,
        eventId: clearEvent ? null : eventId ?? this.eventId,
        archived: archived ?? this.archived,
        shared: shared,
        updatedAtMs: updatedAtMs,
        createdBy: createdBy,
      );
}

@immutable
class NoteItem {
  const NoteItem({required this.id, required this.noteId, required this.content, this.done = false, this.position = 0, this.doneBy});

  factory NoteItem.fromRow(LocalNoteItem row) =>
      NoteItem(id: row.id, noteId: row.noteId, content: row.content, done: row.done, position: row.position, doneBy: row.doneBy);

  final String id;
  final String noteId;
  final String content;
  final bool done;
  final double position;
  final int? doneBy;
}

/// Open items first (in order), ticked ones after.
List<NoteItem> orderedItems(Iterable<NoteItem> items) => [...items]..sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    return a.position.compareTo(b.position);
  });
