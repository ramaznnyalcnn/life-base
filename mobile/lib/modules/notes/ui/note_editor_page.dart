import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_store.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/notes/date_hint.dart';
import '../../../core/notes/note.dart';
import '../../../core/notes/notes_store.dart';
import '../../../core/routes.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/notes_repository.dart';
import 'notes_format.dart';

/// Write a note or a checklist. Saves as you type (like Apple Notes); an
/// empty new note is never stored.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.initial, this.startAsList = false});

  final Note? initial;
  final bool startAsList;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _newItem = TextEditingController();
  final _newItemFocus = FocusNode();
  bool _stored = false;
  Timer? _debounce;

  // Kept in fields: dispose may still save, and `ref` is gone by then.
  late final NotesRepository _repo;
  List<NoteItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _repo = ref.read(notesRepositoryProvider);
    _note = widget.initial ?? Note(id: _repo.newId(), kind: widget.startAsList ? NoteKind.list : NoteKind.note);
    _stored = widget.initial != null;
    _title = TextEditingController(text: _note.title)..addListener(_changed);
    _body = TextEditingController(text: _note.body)..addListener(_changed);
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _flush();
    }
    _title.dispose();
    _body.dispose();
    _newItem.dispose();
    _newItemFocus.dispose();
    super.dispose();
  }

  Note get _current => _note.copyWith(title: _title.text, body: _body.text);

  bool get _empty => _title.text.trim().isEmpty && _body.text.trim().isEmpty && _items.isEmpty;

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    if (!_stored && _empty) return;
    _stored = true;
    _note = _current;
    await _repo.save(_note);
  }

  Future<void> _update(Note note) async {
    setState(() => _note = note.copyWith(title: _title.text, body: _body.text));
    _stored = true;
    await _repo.save(_note);
  }

  Future<void> _ensureStored() async {
    if (_stored) return;
    _stored = true;
    _note = _current;
    await _repo.save(_note);
  }

  // Checklist ---------------------------------------------------------------

  Future<void> _addItem(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    await _ensureStored();
    final items = _items;
    final last = items.isEmpty ? 0.0 : items.map((i) => i.position).reduce((a, b) => a > b ? a : b);
    await _repo.saveItem(NoteItem(id: _repo.newId(), noteId: _note.id, content: content, position: last + 1), shared: _note.shared);
    _newItem.clear();
    _newItemFocus.requestFocus();
  }

  Future<void> _toggle(NoteItem item, int me) => _repo.saveItem(
        NoteItem(id: item.id, noteId: item.noteId, content: item.content, done: !item.done, position: item.position, doneBy: item.done ? null : me),
        shared: _note.shared,
      );

  Future<void> _reorder(List<NoteItem> open, int from, int to) async {
    if (to > from) to -= 1;
    final moved = open.removeAt(from);
    open.insert(to, moved);
    final before = to == 0 ? null : open[to - 1].position;
    final after = to == open.length - 1 ? null : open[to + 1].position;
    final position = before == null ? (after ?? 1) - 1 : (after == null ? before + 1 : (before + after) / 2);
    await _repo.saveItem(
      NoteItem(id: moved.id, noteId: moved.noteId, content: moved.content, done: moved.done, position: position, doneBy: moved.doneBy),
      shared: _note.shared,
    );
  }

  /// Note ↔ list: lines become items and back.
  Future<void> _switchKind() async {
    await _ensureStored();
    if (_note.isList) {
      final lines = _items.map((i) => '${i.done ? '✓ ' : ''}${i.content}').join('\n');
      for (final item in _items) {
        await _repo.deleteItem(item.id);
      }
      _body.text = [_body.text.trim(), lines].where((s) => s.isNotEmpty).join('\n');
      await _update(_note.copyWith(kind: NoteKind.note));
    } else {
      final lines = _body.text.split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*[-•*]\s*'), '').trim()).where((l) => l.isNotEmpty).toList();
      for (var i = 0; i < lines.length; i++) {
        await _repo.saveItem(NoteItem(id: _repo.newId(), noteId: _note.id, content: lines[i], position: i + 1.0), shared: _note.shared);
      }
      _body.text = '';
      await _update(_note.copyWith(kind: NoteKind.list, body: ''));
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not silinsin mi?'),
        content: Text(_note.eventId == null ? 'Bu not ve listesi silinir.' : 'Not silinir; takvimdeki etkinlik kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    _debounce?.cancel();
    if (_stored) await _repo.delete(_note.id);
    _stored = false;
    _title.clear();
    _body.clear();
    navigator.pop();
  }

  Future<void> _unlink() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Takvimden kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Bağı kaldır')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Etkinliği sil')),
        ],
      ),
    );
    if (choice == null) return;
    final note = await _repo.removeFromCalendar(_current, deleteEvent: choice);
    setState(() => _note = note);
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final items = _items = ref.watch(noteItemsProvider).value?[_note.id] ?? const <NoteItem>[];
    final open = items.where((i) => !i.done).toList();
    final done = items.where((i) => i.done).toList();
    final me = ref.watch(walletMeProvider);
    final event = _note.eventId == null
        ? null
        : ref.watch(localEventsProvider).value?.where((e) => e.id == _note.eventId).firstOrNull;
    final text = [_title.text, _body.text, ...items.where((i) => !i.done).map((i) => i.content)].join('\n');
    final hint = _note.eventId == null ? findDateHint(text, DateTime.now()) : null;
    final tint = noteColor(context, _note.color);

    return Scaffold(
      backgroundColor: tint == null ? null : Color.alphaBlend(tint.withValues(alpha: .08), t.base),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _note.pinned ? 'Sabitlemeyi kaldır' : 'Sabitle',
            icon: Icon(_note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
            onPressed: () => _update(_note.copyWith(pinned: !_note.pinned)),
          ),
          IconButton(
            tooltip: _note.isList ? 'Nota çevir' : 'Listeye çevir',
            icon: Icon(_note.isList ? Icons.notes_rounded : Icons.checklist_rounded),
            onPressed: _switchKind,
          ),
          PopupMenuButton<String>(
            tooltip: 'Diğer',
            onSelected: (value) {
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Sil'))],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          decoration: const InputDecoration(hintText: 'Başlık', border: InputBorder.none, filled: false),
        ),
        if (!_note.isList)
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: t.onBase, height: 1.45, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Not… (ör. "yarın 15:00 dişçi" yazarsan takvime eklemeyi öneririm)',
              border: InputBorder.none,
              filled: false,
            ),
          )
        else ...[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (from, to) => _reorder([...open], from, to),
            children: [
              for (var i = 0; i < open.length; i++)
                _ItemRow(key: ValueKey(open[i].id), item: open[i], index: i, onToggle: () => _toggle(open[i], me), repo: _repo, shared: _note.shared),
            ],
          ),
          Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.add_rounded, color: t.muted),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _newItem,
                focusNode: _newItemFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Madde ekle', border: InputBorder.none, filled: false),
                onSubmitted: _addItem,
              ),
            ),
          ]),
          if (done.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text('${done.length} madde tamam', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
            ),
            for (final item in done) _ItemRow(key: ValueKey(item.id), item: item, onToggle: () => _toggle(item, me), repo: _repo, shared: _note.shared),
          ],
        ],
        const SizedBox(height: 16),
        if (event != null)
          NeuSurface(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(children: [
              Icon(Icons.event_available_rounded, color: t.module(LbModule.calendar)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Takvimde: ${eventWhen(event.startsAt, allDay: event.allDay)}',
                    style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: () => context.go(AppRoutes.calendar), child: const Text('Aç')),
              IconButton(tooltip: 'Takvimden kaldır', onPressed: _unlink, icon: const Icon(Icons.link_off_rounded)),
            ]),
          )
        else if (hint != null)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(Icons.event_rounded, color: t.module(LbModule.calendar)),
              label: Text('Takvime ekle: ${eventWhen(hint.start, allDay: !hint.hasTime)}'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                _debounce?.cancel();
                await _ensureStored();
                final linked = await _repo.addToCalendar(_current, hint);
                if (!mounted) return;
                setState(() => _note = linked);
                messenger.showSnackBar(SnackBar(content: Text('Takvime eklendi: ${eventWhen(hint.start, allDay: !hint.hasTime)}')));
              },
            ),
          ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, children: [
          for (final (index, color) in noteColors(context).indexed)
            Semantics(
              button: true,
              selected: (_note.color ?? -1) == index,
              label: 'Renk ${index + 1}',
              child: GestureDetector(
                onTap: () => _update((_note.color == index) ? _note.copyWith(clearColor: true) : _note.copyWith(color: index)),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: _note.color == index ? t.onBase : Colors.transparent, width: 2.5),
                  ),
                ),
              ),
            ),
        ]),
        if (_note.updatedAtMs > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Düzenlendi: ${DateFormat('d MMM HH:mm', 'tr_TR').format(DateTime.fromMillisecondsSinceEpoch(_note.updatedAtMs))}',
              style: TextStyle(color: t.muted, fontSize: 12),
            ),
          ),
      ]),
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({super.key, required this.item, required this.onToggle, required this.repo, required this.shared, this.index});
  final NoteItem item;
  final int? index;
  final VoidCallback onToggle;
  final NotesRepository repo;
  final bool shared;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final _controller = TextEditingController(text: widget.item.content);
  Timer? _debounce;

  @override
  void didUpdateWidget(_ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.content != _controller.text && !(_debounce?.isActive ?? false)) _controller.text = widget.item.content;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _edited(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final i = widget.item;
      widget.repo.saveItem(NoteItem(id: i.id, noteId: i.noteId, content: text, done: i.done, position: i.position, doneBy: i.doneBy), shared: widget.shared);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Row(children: [
      if (widget.index != null)
        ReorderableDragStartListener(
          index: widget.index!,
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.drag_indicator_rounded, color: t.muted, size: 20)),
        )
      else
        const SizedBox(width: 28),
      Checkbox(value: widget.item.done, onChanged: (_) => widget.onToggle()),
      Expanded(
        child: TextField(
          controller: _controller,
          onChanged: _edited,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: widget.item.done ? t.muted : t.onBase,
            decoration: widget.item.done ? TextDecoration.lineThrough : null,
          ),
          decoration: const InputDecoration(border: InputBorder.none, filled: false, isDense: true),
        ),
      ),
      IconButton(
        tooltip: 'Maddeyi sil',
        icon: Icon(Icons.close_rounded, size: 18, color: t.muted),
        onPressed: () => widget.repo.deleteItem(widget.item.id),
      ),
    ]);
  }
}
