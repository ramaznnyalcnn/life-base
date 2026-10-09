import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/calendar/reminder_defaults.dart';
import '../../../core/calendar/reminder_picker.dart';
import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../data/events_repository.dart';
import 'calendar_format.dart';
import 'series_scope_dialog.dart';

/// Add or edit one event. With [occurrence] set, edits that appearance of a
/// (possibly repeating) event and asks which part of the series to change.
class EventEditPage extends ConsumerStatefulWidget {
  const EventEditPage({super.key, this.initial, this.occurrence, this.day});

  /// Prefilled values (editing or duplicating). Null creates a new event.
  final CalendarEvent? initial;
  final EventOccurrence? occurrence;

  /// Day to place a new event on.
  final DateTime? day;

  @override
  ConsumerState<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends ConsumerState<EventEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late CalendarEvent _event;
  late final CalendarEvent _original;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _event = initial;
    } else {
      final now = DateTime.now();
      final day = widget.day ?? now;
      final sameDay = DateUtils.isSameDay(day, now);
      final start = DateTime(day.year, day.month, day.day, sameDay ? now.hour + 1 : 9);
      _event = CalendarEvent(
        id: ref.read(eventsRepositoryProvider).newId(),
        title: '',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        reminders: ref.read(defaultRemindersProvider),
      );
    }
    _original = _event;
    _title = TextEditingController(text: _event.title)..addListener(() => setState(() {}));
    _notes = TextEditingController(text: _event.notes ?? '')..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  CalendarEvent get _current => _event.copyWith(
        title: _title.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        clearNotes: _notes.text.trim().isEmpty,
      );

  bool get _dirty {
    final now = _current, was = _original;
    return now.title != was.title.trim() ||
        now.notes != was.notes ||
        now.startsAt != was.startsAt ||
        now.endsAt != was.endsAt ||
        now.allDay != was.allDay ||
        now.color != was.color ||
        now.important != was.important ||
        now.recurrence != was.recurrence ||
        !_sameReminders(now.reminders, was.reminders);
  }

  static bool _sameReminders(List<ReminderSpec> a, List<ReminderSpec> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  String? get _problem {
    if (_title.text.trim().isEmpty) return 'Başlık gerekli';
    final end = _event.endsAt;
    if (end != null && end.isBefore(_event.startsAt)) return 'Bitiş, başlangıçtan önce olamaz';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final repo = ref.read(eventsRepositoryProvider);
    final occurrence = widget.occurrence;
    if (occurrence != null) {
      final scope = occurrence.isRecurring ? await askSeriesScope(context, verb: 'Değiştir') : SeriesScope.all;
      if (scope == null) return;
      await repo.updateOccurrence(occurrence, _current, scope);
    } else {
      await repo.save(_current);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<DateTime?> _pick(DateTime value, {required bool withTime}) async {
    final date = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null || !mounted) return null;
    if (!withTime) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final value = await _pick(_event.startsAt, withTime: !_event.allDay);
    if (value == null) return;
    // Keep the duration when the start moves.
    final length = _event.endsAt?.difference(_event.startsAt);
    setState(() => _event = _event.copyWith(startsAt: value, endsAt: length == null ? null : value.add(length)));
  }

  Future<void> _pickEnd() async {
    final value = await _pick(_event.endsAt ?? _event.startsAt, withTime: !_event.allDay);
    if (value != null) setState(() => _event = _event.copyWith(endsAt: value));
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final dateFmt = DateFormat('d MMM y, EEE', 'tr_TR');
    final timeFmt = DateFormat('HH:mm');
    final end = _event.endsAt ?? _event.startsAt;
    return AddPageScaffold(
      title: _isNew ? 'Yeni etkinlik' : 'Etkinliği düzenle',
      dirty: _dirty,
      onSave: _save,
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        TextField(
          controller: _title,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          decoration: const InputDecoration(hintText: 'Başlık'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Not (isteğe bağlı)'),
        ),
        const SizedBox(height: 20),
        _Section(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tüm gün'),
            value: _event.allDay,
            onChanged: (value) => setState(() {
              final s = _event.startsAt;
              final e = _event.endsAt ?? s;
              _event = value
                  ? _event.copyWith(allDay: true, startsAt: DateTime(s.year, s.month, s.day), endsAt: DateTime(e.year, e.month, e.day))
                  : _event.copyWith(allDay: false, startsAt: DateTime(s.year, s.month, s.day, 9), endsAt: DateTime(e.year, e.month, e.day, 10));
            }),
          ),
          _PickerRow(
            label: 'Başlangıç',
            value: _event.allDay ? dateFmt.format(_event.startsAt) : '${dateFmt.format(_event.startsAt)}  ${timeFmt.format(_event.startsAt)}',
            onTap: _pickStart,
          ),
          _PickerRow(
            label: 'Bitiş',
            value: _event.allDay ? dateFmt.format(end) : '${dateFmt.format(end)}  ${timeFmt.format(end)}',
            onTap: _pickEnd,
          ),
        ]),
        const SizedBox(height: 16),
        _Section(children: [
          _PickerRow(
            label: 'Tekrar',
            value: _event.recurrence == null ? 'Tekrarlanmaz' : recurrenceLabel(_event.recurrence!, _event.startsAt),
            onTap: () async {
              final result = await showModalBottomSheet<_RuleChoice>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _RecurrenceSheet(rule: _event.recurrence, start: _event.startsAt),
              );
              if (result != null) {
                setState(() => _event = result.rule == null ? _event.copyWith(clearRecurrence: true) : _event.copyWith(recurrence: result.rule));
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Önemli'),
            subtitle: const Text('Hatırlatmalar yüksek öncelikle gelir'),
            value: _event.important,
            onChanged: (value) => setState(() => _event = _event.copyWith(important: value)),
          ),
          const SizedBox(height: 4),
          Text('Renk', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _ColorDot(color: null, selected: _event.color == null, onTap: () => setState(() => _event = _event.copyWith(clearColor: true))),
            for (final c in eventColors)
              _ColorDot(color: c, selected: _event.color == c, onTap: () => setState(() => _event = _event.copyWith(color: c))),
          ]),
          const SizedBox(height: 8),
        ]),
        const SizedBox(height: 16),
        _Section(children: [
          Text('Hatırlatmalar', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ReminderListEditor(
            reminders: _event.reminders,
            allowFixedTime: _event.recurrence == null,
            initialFixedTime: _event.startsAt.subtract(const Duration(hours: 1)),
            onChanged: (value) => setState(() => _event = _event.copyWith(reminders: value)),
          ),
          if (_event.allDay)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Tüm gün etkinliklerde süre, o günün 09:00’una göre hesaplanır.', style: TextStyle(color: t.muted, fontSize: 12)),
            ),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NeuSurface(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: t.muted),
        ]),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});
  final int? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final fill = eventColor(context, color);
    return Semantics(
      button: true,
      selected: selected,
      label: color == null ? 'Varsayılan renk' : 'Renk',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? t.onBase : Colors.transparent, width: 2)),
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: color == null ? Icon(Icons.auto_awesome_rounded, size: 16, color: t.onAccent) : null,
          ),
        ),
      ),
    );
  }
}

class _RuleChoice {
  const _RuleChoice(this.rule);
  final RecurrenceRule? rule;
}

/// Picks a repetition: none, the common ones, or a custom interval with
/// weekdays, plus an optional end date.
class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({required this.rule, required this.start});
  final RecurrenceRule? rule;
  final DateTime start;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  late RecurrenceFreq? _freq = widget.rule?.freq;
  late int _interval = widget.rule?.interval ?? 1;
  late Set<int> _weekdays = {...?widget.rule?.weekdays};
  late DateTime? _until = widget.rule?.until;

  RecurrenceRule? get _rule => _freq == null
      ? null
      : RecurrenceRule(
          freq: _freq!,
          interval: _interval,
          weekdays: _freq == RecurrenceFreq.weekly ? (_weekdays.toList()..sort()) : const [],
          until: _until,
          exdates: widget.rule?.exdates ?? const [],
        );

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    // (singular, "every N" form) per frequency: Her gün / 3 günde bir.
    final (one, many) = switch (_freq) {
      RecurrenceFreq.daily => ('Her gün', 'günde bir'),
      RecurrenceFreq.weekly => ('Her hafta', 'haftada bir'),
      RecurrenceFreq.monthly => ('Her ay', 'ayda bir'),
      RecurrenceFreq.yearly => ('Her yıl', 'yılda bir'),
      null => ('', ''),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Tekrar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (label, freq) in const [
              ('Tekrarlanmaz', null),
              ('Günlük', RecurrenceFreq.daily),
              ('Haftalık', RecurrenceFreq.weekly),
              ('Aylık', RecurrenceFreq.monthly),
              ('Yıllık', RecurrenceFreq.yearly),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _freq == freq,
                onSelected: (_) => setState(() {
                  _freq = freq;
                  _interval = 1;
                  if (freq == RecurrenceFreq.weekly && _weekdays.isEmpty) _weekdays = {widget.start.weekday};
                }),
              ),
          ]),
          if (_freq != null) ...[
            const SizedBox(height: 20),
            Row(children: [
              IconButton.filledTonal(
                tooltip: 'Azalt',
                onPressed: _interval > 1 ? () => setState(() => _interval--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  _interval == 1 ? one : '$_interval $many',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Artır',
                onPressed: _interval < 99 ? () => setState(() => _interval++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (_freq == RecurrenceFreq.weekly) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayShort[d - 1]),
                    selected: _weekdays.contains(d),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _weekdays.add(d);
                      } else if (_weekdays.length > 1) {
                        _weekdays.remove(d);
                      }
                    }),
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bitiş tarihi'),
              subtitle: Text(_until == null ? 'Süresiz' : DateFormat('d MMMM y', 'tr_TR').format(_until!)),
              value: _until != null,
              onChanged: (on) async {
                if (!on) return setState(() => _until = null);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.start.add(const Duration(days: 30)),
                  firstDate: widget.start,
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _until = picked);
              },
            ),
            const SizedBox(height: 8),
            Text(recurrenceLabel(_rule!, widget.start), style: TextStyle(color: t.muted)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, _RuleChoice(_rule)), child: const Text('Tamam')),
        ]),
      ),
    );
  }
}
