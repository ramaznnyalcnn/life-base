import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import 'calendar_event.dart';
import 'reminder_defaults.dart';

/// Editable list of reminders: preset chips, a custom "N min/hours/days
/// before", and (when [allowFixedTime]) a fixed date and time.
class ReminderListEditor extends StatelessWidget {
  const ReminderListEditor({
    super.key,
    required this.reminders,
    required this.onChanged,
    this.allowFixedTime = true,
    this.initialFixedTime,
  });

  final List<ReminderSpec> reminders;
  final ValueChanged<List<ReminderSpec>> onChanged;
  final bool allowFixedTime;
  final DateTime? initialFixedTime;

  void _add(ReminderSpec spec) {
    if (reminders.any((r) => r.offset == spec.offset && r.at == spec.at)) return;
    onChanged([...reminders, spec]);
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final unused = reminderPresets.where((p) => !reminders.any((r) => r.at == null && r.offset == p.offset));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (reminders.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Hatırlatma yok', style: TextStyle(color: t.muted)),
        ),
      for (var i = 0; i < reminders.length; i++)
        _ReminderRow(
          spec: reminders[i],
          onPriority: () {
            final next = [...reminders];
            next[i] = reminders[i].withPriority(
              reminders[i].priority == ReminderPriority.high ? ReminderPriority.normal : ReminderPriority.high,
            );
            onChanged(next);
          },
          onRemove: () => onChanged([...reminders]..removeAt(i)),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final preset in unused)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(reminderLabel(preset)),
            onPressed: () => _add(preset),
          ),
        ActionChip(
          avatar: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Özel süre'),
          onPressed: () async {
            final spec = await showModalBottomSheet<ReminderSpec>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const _CustomOffsetSheet(),
            );
            if (spec != null) _add(spec);
          },
        ),
        if (allowFixedTime)
          ActionChip(
            avatar: const Icon(Icons.event_rounded, size: 18),
            label: const Text('Belirli zaman'),
            onPressed: () async {
              final base = initialFixedTime ?? DateTime.now();
              final date = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
              if (time == null) return;
              _add(ReminderSpec.at(DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc()));
            },
          ),
      ]),
    ]);
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.spec, required this.onPriority, required this.onRemove});

  final ReminderSpec spec;
  final VoidCallback onPriority;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final high = spec.priority == ReminderPriority.high;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(spec.at == null ? Icons.notifications_rounded : Icons.alarm_rounded, size: 20, color: t.muted),
        const SizedBox(width: 12),
        Expanded(child: Text(reminderLabel(spec), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
        IconButton(
          tooltip: high ? 'Yüksek öncelik (kapat)' : 'Yüksek öncelik',
          isSelected: high,
          onPressed: onPriority,
          icon: const Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_active_rounded, color: t.danger),
        ),
        IconButton(tooltip: 'Kaldır', onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
      ]),
    );
  }
}

class _CustomOffsetSheet extends StatefulWidget {
  const _CustomOffsetSheet();

  @override
  State<_CustomOffsetSheet> createState() => _CustomOffsetSheetState();
}

class _CustomOffsetSheetState extends State<_CustomOffsetSheet> {
  var _amount = 15;
  var _unit = 'dk';

  Duration get _offset => switch (_unit) {
        'sa' => Duration(hours: _amount),
        'gün' => Duration(days: _amount),
        _ => Duration(minutes: _amount),
      };

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ne kadar önce?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(
                tooltip: 'Azalt',
                onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 72,
                child: Text('$_amount', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton.filledTonal(
                tooltip: 'Artır',
                onPressed: _amount < 999 ? () => setState(() => _amount++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dk', label: Text('dakika')),
                ButtonSegment(value: 'sa', label: Text('saat')),
                ButtonSegment(value: 'gün', label: Text('gün')),
              ],
              selected: {_unit},
              onSelectionChanged: (v) => setState(() => _unit = v.first),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, ReminderSpec.before(_offset)),
              child: Text('${reminderLabel(ReminderSpec.before(_offset))} ekle'),
            ),
          ]),
        ),
      );
}
