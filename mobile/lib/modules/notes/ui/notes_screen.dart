import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/calendar/calendar_store.dart';
import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/notes/note.dart';
import '../../../core/notes/notes_store.dart';
import 'note_editor_page.dart';
import 'notes_format.dart';

enum _Filter { all, lists, calendar }

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open([Note? note, bool list = false]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoteEditorPage(initial: note, startAsList: list)));

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final notes = ref.watch(notesProvider).value ?? const <Note>[];
    final items = ref.watch(noteItemsProvider).value ?? const <String, List<NoteItem>>{};
    final events = {for (final e in ref.watch(localEventsProvider).value ?? const <CalendarEvent>[]) e.id: e};
    final query = _search.text.trim().toLowerCase();

    final visible = notes.where((note) {
      if (note.archived) return false;
      if (_filter == _Filter.lists && !note.isList) return false;
      if (_filter == _Filter.calendar && events[note.eventId] == null) return false;
      if (query.isEmpty) return true;
      final haystack = [note.title, note.body, ...?items[note.id]?.map((i) => i.content)].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return ModuleScaffold(
      module: LbModule.notes,
      title: 'Notlar',
      addLabel: 'Not',
      addPageBuilder: (context) => const NoteEditorPage(),
      body: ListView(padding: moduleListPadding(context, hasAddButton: true), children: [
        if (notes.isEmpty)
          NeuSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sticky_note_2_rounded, color: t.module(LbModule.notes), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Aklına geleni yaz. "Yarın 15:00 dişçi" gibi bir tarih yazarsan takvime eklemeyi önerir.',
                      style: TextStyle(color: t.muted)),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                FilledButton.tonalIcon(onPressed: _open, icon: const Icon(Icons.edit_note_rounded), label: const Text('Not yaz')),
                FilledButton.tonalIcon(onPressed: () => _open(null, true), icon: const Icon(Icons.checklist_rounded), label: const Text('Liste başlat')),
              ]),
            ]),
          )
        else ...[
          NeuSurface(
            sunken: true,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            radius: LbTokens.radiusSmall + 6,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Notlarda ara',
                prefixIcon: const Icon(Icons.search_rounded),
                border: InputBorder.none,
                filled: false,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(tooltip: 'Temizle', icon: const Icon(Icons.close_rounded), onPressed: _search.clear),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final (filter, label) in const [(_Filter.all, 'Tümü'), (_Filter.lists, 'Listeler'), (_Filter.calendar, 'Takvimde')])
              ChoiceChip(label: Text(label), selected: _filter == filter, onSelected: (_) => setState(() => _filter = filter)),
          ]),
          const SizedBox(height: 12),
          if (visible.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Eşleşen not yok.', style: TextStyle(color: t.muted))),
          for (final note in visible)
            _NoteCard(note: note, items: items[note.id] ?? const [], event: events[note.eventId], onTap: () => _open(note)),
        ],
      ]),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.items, required this.event, required this.onTap});
  final Note note;
  final List<NoteItem> items;
  final CalendarEvent? event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final tint = noteColor(context, note.color);
    final done = items.where((i) => i.done).length;
    final preview = note.isList
        ? items.where((i) => !i.done).take(3).map((i) => '○ ${i.content}').join('\n')
        : note.body.trim().split('\n').where((l) => l.trim().isNotEmpty).skip(note.title.trim().isEmpty ? 1 : 0).take(3).join('\n');
    final heading = note.heading.isEmpty ? (note.isList ? 'Liste' : 'Başlıksız not') : note.heading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 6,
          padding: EdgeInsets.zero,
          color: tint == null ? null : Color.alphaBlend(tint.withValues(alpha: .10), t.base),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (note.pinned) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 16, color: t.muted)),
                if (note.isList) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.checklist_rounded, size: 18, color: tint ?? t.module(LbModule.notes))),
                Expanded(
                  child: Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (note.shared) Icon(Icons.group_rounded, size: 18, color: t.muted),
                if (note.isList && items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('$done/${items.length}', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
                  ),
              ]),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.muted, height: 1.35)),
              ],
              if (event != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.event_available_rounded, size: 16, color: t.module(LbModule.calendar)),
                  const SizedBox(width: 6),
                  Text(eventWhen(event!.startsAt, allDay: event!.allDay),
                      style: TextStyle(color: t.module(LbModule.calendar), fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
