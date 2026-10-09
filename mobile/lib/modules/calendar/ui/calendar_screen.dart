import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/models/agenda.dart';
import '../../../core/providers.dart';
import 'calendar_add_page.dart';

enum CalendarSpan { day, week, month }

final calendarDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final calendarSpanProvider = StateProvider<CalendarSpan>((ref) => CalendarSpan.week);
final calendarKindProvider = StateProvider<String>((ref) => 'all');

final calendarItemsProvider = FutureProvider<List<AgendaItem>>((ref) async {
  final date = ref.watch(calendarDateProvider);
  final span = ref.watch(calendarSpanProvider);
  final kind = ref.watch(calendarKindProvider);
  final from = switch (span) {
    CalendarSpan.day => date,
    CalendarSpan.week => date.subtract(Duration(days: date.weekday - 1)),
    CalendarSpan.month => DateTime(date.year, date.month),
  };
  final to = switch (span) {
    CalendarSpan.day => date,
    CalendarSpan.week => from.add(const Duration(days: 6)),
    CalendarSpan.month => DateTime(date.year, date.month + 1, 0),
  };
  final values = await ref.watch(apiClientProvider)!.agendaRange(from, to);
  return kind == 'all' ? values : values.where((item) => item.kind == kind).toList();
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(calendarDateProvider);
    final span = ref.watch(calendarSpanProvider);
    final items = ref.watch(calendarItemsProvider);
    final t = LbTokens.of(context);
    return ModuleScaffold(
      module: LbModule.calendar,
      title: 'Takvim',
      addLabel: 'Etkinlik',
      addPageBuilder: (context) => const CalendarAddPage(),
      body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => _move(ref, date, span, -1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: TextButton(
                onPressed: () => _pickDate(context, ref, date),
                child: Text(DateFormat('MMMM yyyy', 'tr_TR').format(date), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
              ),
            ),
            IconButton(onPressed: () => _move(ref, date, span, 1), icon: const Icon(Icons.chevron_right)),
          ]),
          SegmentedButton<CalendarSpan>(
            segments: const [
              ButtonSegment(value: CalendarSpan.day, label: Text('Gün')),
              ButtonSegment(value: CalendarSpan.week, label: Text('Hafta')),
              ButtonSegment(value: CalendarSpan.month, label: Text('Ay')),
            ],
            selected: {span},
            onSelectionChanged: (value) => ref.read(calendarSpanProvider.notifier).state = value.first,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['all', 'task', 'event', 'routine', 'medication', 'scheduled_payment']
                  .map((kind) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(kind)),
                          selected: ref.watch(calendarKindProvider) == kind,
                          onSelected: (_) => ref.read(calendarKindProvider.notifier).state = kind,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
      Expanded(
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Takvim alınamadı.', style: TextStyle(color: t.muted))),
          data: (values) => values.isEmpty
              ? Center(child: Text('Bu aralıkta kayıt yok.', style: TextStyle(color: t.muted)))
              : ListView.builder(
                  padding: moduleListPadding(context, hasAddButton: true).copyWith(top: 4),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final item = values[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NeuSurface(
                        depth: 4,
                        radius: LbTokens.radiusSmall + 4,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          SizedBox(
                            width: 44,
                            child: Column(children: [
                              Text('${item.day.day}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: t.onBase)),
                              Text(DateFormat('EEE', 'tr_TR').format(item.day), style: TextStyle(color: t.muted, fontSize: 12)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.displayTitle, style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
                              Text(
                                item.startsAt == null ? _label(item.kind) : '${DateFormat('HH:mm').format(item.startsAt!.toLocal())} · ${_label(item.kind)}',
                                style: TextStyle(color: t.muted, fontSize: 12),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]),
    );
  }

  static void _move(WidgetRef ref, DateTime date, CalendarSpan span, int direction) {
    final days = span == CalendarSpan.day ? 1 : span == CalendarSpan.week ? 7 : 30;
    ref.read(calendarDateProvider.notifier).state = date.add(Duration(days: days * direction));
  }

  static Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime date) async {
    final value = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2040));
    if (value != null) ref.read(calendarDateProvider.notifier).state = value;
  }

  static String _label(String value) => switch (value) {
        'all' => 'Tümü', 'task' => 'Görev', 'event' => 'Etkinlik', 'routine' => 'Rutin', 'medication' => 'İlaç', 'scheduled_payment' => 'Ödeme', _ => value,
      };
}
