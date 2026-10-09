import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/models/agenda.dart';
import '../../../core/platform/device_calendar.dart';
import '../data/today_controller.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(todayAgendaProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final google = ref.watch(deviceEventsProvider((from: today, to: today))).value ?? const <AgendaItem>[];
    final t = LbTokens.of(context);
    return ModuleScaffold(
      module: LbModule.today,
      title: 'Bugün',
      subtitle: DateFormat('d MMMM, EEEE', 'tr_TR').format(DateTime.now()),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(deviceEventsProvider);
          return ref.refresh(todayAgendaProvider.future);
        },
        child: agenda.when(
          loading: () => ListView(children: const [SizedBox(height: 240), Center(child: CircularProgressIndicator())]),
          error: (error, _) => ListView(padding: moduleListPadding(context), children: [
            const SizedBox(height: 80),
            Icon(Icons.cloud_off_rounded, size: 48, color: t.muted),
            const SizedBox(height: 16),
            Center(child: Text('Gündem alınamadı. Yenilemek için aşağı çek.', style: TextStyle(color: t.muted))),
          ]),
          data: (data) {
            final timeline = mergeTimeline(data.timeline, google);
            return ListView(
            padding: moduleListPadding(context),
            children: [
              if (data.fromCache)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Chip(avatar: const Icon(Icons.cloud_off_rounded, size: 16), label: const Text('Çevrimdışı')),
                  ),
                ),
              _NextCard(item: nextItem(data.nextItem, google, DateTime.now())),
              if (data.overdue.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionTitle('Gecikenler', count: data.overdue.length, color: t.danger),
                ...data.overdue.map((item) => _AgendaTile(item: item)),
              ],
              if (data.tasks.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionTitle('Görevler', count: data.tasks.length),
                ...data.tasks.map((item) => _AgendaTile(item: item)),
              ],
              const SizedBox(height: 28),
              _SectionTitle('Saat saat', count: timeline.length),
              if (timeline.isEmpty) const _Empty(text: 'Bugün sakin.'),
              ...timeline.map((item) => _AgendaTile(item: item, showTime: true)),
            ],
          );
          },
        ),
      ),
    );
  }
}

/// Today's server timeline plus Google events: all-day first, then by time.
List<AgendaItem> mergeTimeline(List<AgendaItem> server, List<AgendaItem> google) {
  int key(AgendaItem item) => item.startsAt == null ? -1 : item.startsAt!.toLocal().hour * 60 + item.startsAt!.toLocal().minute;
  return [...server, ...google]..sort((a, b) => key(a).compareTo(key(b)));
}

/// The server's next item, unless a Google event starts sooner.
AgendaItem? nextItem(AgendaItem? server, List<AgendaItem> google, DateTime now) {
  final upcoming = google.where((item) => item.startsAt != null && item.startsAt!.isAfter(now)).toList()
    ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
  final candidate = upcoming.firstOrNull;
  if (candidate == null) return server;
  if (server?.startsAt == null) return server ?? candidate;
  return candidate.startsAt!.isBefore(server!.startsAt!) ? candidate : server;
}

class _NextCard extends StatelessWidget {
  const _NextCard({this.item});
  final AgendaItem? item;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final color = t.module(LbModule.today);
    return NeuSurface(
      padding: const EdgeInsets.all(22),
      child: item == null
          ? Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: color),
              const SizedBox(width: 12),
              Text('Sıradaki plan beklemiyor', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SIRADAKİ',
                  style: TextStyle(color: color, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 10),
              Text(item!.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
              if (item!.startsAt != null) ...[
                const SizedBox(height: 6),
                Text(DateFormat('HH:mm').format(item!.startsAt!.toLocal()),
                    style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
              ],
            ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.count, this.color});
  final String text;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color ?? t.onBase)),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile({required this.item, this.showTime = false});
  final AgendaItem item;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final completed = item.isCompleted || ref.watch(optimisticCompletedProvider).contains(item.id);
    final canComplete = !completed && (item.kind == 'task' || item.kind == 'medication');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: item.kind == 'medication' && !completed
            ? () => ref.read(quickActionProvider).snooze(item, 10)
            : null,
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            SizedBox(
              width: 48,
              child: showTime && item.startsAt != null
                  ? Text(DateFormat('HH:mm').format(item.startsAt!.toLocal()),
                      style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase))
                  : Icon(_icon(item.kind), color: t.muted),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: completed ? t.muted : t.onBase,
                    fontWeight: FontWeight.w700,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(_kind(item.kind), style: TextStyle(color: t.muted, fontSize: 12)),
              ]),
            ),
            if (canComplete)
              IconButton(
                tooltip: item.kind == 'medication' ? 'Alındı' : 'Tamamla',
                onPressed: () => ref.read(quickActionProvider).complete(item),
                icon: Icon(Icons.check_circle_outline_rounded, color: t.module(LbModule.today)),
              )
            else
              const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }

  IconData _icon(String kind) => switch (kind) {
        'medication' => Icons.medication_rounded,
        'scheduled_payment' => Icons.payments_rounded,
        'task' => Icons.task_alt_rounded,
        'routine' => Icons.repeat_rounded,
        googleKind => Icons.event_available_rounded,
        _ => Icons.event_rounded,
      };

  String _kind(String kind) => switch (kind) {
        'medication' => 'İlaç',
        'scheduled_payment' => 'Ödeme',
        'task' => 'Görev',
        'routine' => 'Rutin',
        googleKind => 'Google',
        _ => 'Etkinlik',
      };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(text, style: TextStyle(color: LbTokens.of(context).muted))),
      );
}
