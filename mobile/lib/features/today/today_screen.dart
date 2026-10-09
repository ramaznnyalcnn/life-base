import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/agenda.dart';
import 'today_controller.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(todayAgendaProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(todayAgendaProvider.future),
      child: agenda.when(
        loading: () => ListView(children: const [SizedBox(height: 280), Center(child: CircularProgressIndicator())]),
        error: (error, _) => ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 100),
          Icon(Icons.cloud_off_rounded, size: 52, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Center(child: Text('Gündem alınamadı. Yenilemek için aşağı çek.')),
        ]),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(children: [
              Text(DateFormat('d MMMM, EEEE', 'tr_TR').format(data.date), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (data.fromCache) const Chip(label: Text('Çevrimdışı')),
            ]),
            const SizedBox(height: 16),
            _NextCard(item: data.nextItem),
            if (data.overdue.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle('Gecikenler', count: data.overdue.length, color: Theme.of(context).colorScheme.error),
              ...data.overdue.map((item) => _AgendaTile(item: item)),
            ],
            const SizedBox(height: 24),
            _SectionTitle('Görevler', count: data.tasks.length),
            if (data.tasks.isEmpty) const _Empty(text: 'Bugün için görev yok.'),
            ...data.tasks.map((item) => _AgendaTile(item: item)),
            const SizedBox(height: 24),
            _SectionTitle('Saat saat', count: data.timeline.length),
            if (data.timeline.isEmpty) const _Empty(text: 'Takvim bugün sakin.'),
            ...data.timeline.map((item) => _AgendaTile(item: item, showTime: true)),
          ],
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({this.item});
  final AgendaItem? item;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: item == null
              ? const Row(children: [Icon(Icons.check_circle_outline), SizedBox(width: 12), Text('Sıradaki plan beklemiyor')])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SIRADAKİ', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Text(item!.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (item!.startsAt != null) ...[
                    const SizedBox(height: 8),
                    Text(DateFormat('HH:mm').format(item!.startsAt!.toLocal())),
                  ],
                ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.count, this.color});
  final String text;
  final int count;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 8),
          Badge(label: Text('$count')),
        ]),
      );
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile({required this.item, this.showTime = false});
  final AgendaItem item;
  final bool showTime;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = item.isCompleted || ref.watch(optimisticCompletedProvider).contains(item.id);
    return Card(
        child: ListTile(
          minTileHeight: 68,
          leading: showTime && item.startsAt != null
              ? SizedBox(width: 46, child: Text(DateFormat('HH:mm').format(item.startsAt!.toLocal()), style: const TextStyle(fontWeight: FontWeight.w700)))
              : Icon(_icon(item.kind)),
          title: Text(completed ? '✓ ${item.title}' : item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(_kind(item.kind)),
          trailing: !completed && (item.kind == 'task' || item.kind == 'medication')
              ? IconButton(
                  tooltip: item.kind == 'medication' ? 'Alındı' : 'Tamamla',
                  onPressed: () => ref.read(quickActionProvider).complete(item),
                  icon: const Icon(Icons.check_circle_outline),
                )
              : null,
          onLongPress: item.kind == 'medication' && !completed
              ? () => ref.read(quickActionProvider).snooze(item, 10)
              : null,
        ),
      );
  }

  IconData _icon(String kind) => switch (kind) {
        'medication' => Icons.medication_rounded,
        'scheduled_payment' => Icons.payments_rounded,
        'task' => Icons.task_alt_rounded,
        'routine' => Icons.repeat_rounded,
        _ => Icons.event_rounded,
      };
  String _kind(String kind) => switch (kind) {
        'medication' => 'İlaç', 'scheduled_payment' => 'Ödeme', 'task' => 'Görev', 'routine' => 'Rutin', _ => 'Etkinlik',
      };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
}
