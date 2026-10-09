import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'note.dart';

/// Every live note, pinned first, then most recently edited.
final notesProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.localNotes)..where((t) => t.deletedAtMs.isNull())).watch().map((rows) => rows.map(Note.fromRow).toList()
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    }));
});

/// Live checklist items by note id.
final noteItemsProvider = StreamProvider<Map<String, List<NoteItem>>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.localNoteItems)..where((t) => t.deletedAtMs.isNull())).watch().map((rows) {
    final byNote = <String, List<NoteItem>>{};
    for (final row in rows) {
      byNote.putIfAbsent(row.noteId, () => []).add(NoteItem.fromRow(row));
    }
    return {for (final entry in byNote.entries) entry.key: orderedItems(entry.value)};
  });
});
