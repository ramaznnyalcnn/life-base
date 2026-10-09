import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../core/models/agenda.dart';
import '../../core/providers.dart';

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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => _move(ref, date, span, -1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: TextButton(
                onPressed: () => _pickDate(context, ref, date),
                child: Text(DateFormat('MMMM yyyy', 'tr_TR').format(date), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
          error: (error, stackTrace) => const Center(child: Text('Takvim alınamadı.')),
          data: (values) => values.isEmpty
              ? const Center(child: Text('Bu aralıkta kayıt yok.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final item = values[index];
                    return Card(child: ListTile(
                      minTileHeight: 68,
                      leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${item.day.day}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        Text(DateFormat('EEE', 'tr_TR').format(item.day)),
                      ]),
                      title: Text(item.displayTitle),
                      subtitle: Text(item.startsAt == null ? _label(item.kind) : '${DateFormat('HH:mm').format(item.startsAt!.toLocal())} · ${_label(item.kind)}'),
                    ));
                  },
                ),
        ),
      ),
    ]);
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
