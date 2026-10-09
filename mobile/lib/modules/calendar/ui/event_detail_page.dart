import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/calendar/calendar_store.dart';
import '../../../core/calendar/reminder_defaults.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/calendar/events_repository.dart';
import 'calendar_format.dart';
import 'event_edit_page.dart';
import 'series_scope_dialog.dart';

class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({super.key, required this.occurrence});

  final EventOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    // Follow edits made from this page; the occurrence may move or vanish.
    final latest = ref.watch(localEventsProvider).value?.where((e) => e.id == occurrence.event.id).firstOrNull;
    final event = latest ?? occurrence.event;
    final current = latest == null
        ? occurrence
        : (latest.occurrencesBetween(occurrence.start, occurrence.start).firstOrNull ?? EventOccurrence(latest, occurrence.start));
    final color = eventColor(context, event.color);
    final day = DateFormat('d MMMM y, EEEE', 'tr_TR');
    final sameDay = DateUtils.isSameDay(current.start, current.end) || event.allDay && event.duration.inDays <= 1;

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          tooltip: 'Kopyala',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => EventEditPage(
              initial: event.copyWith(
                id: ref.read(eventsRepositoryProvider).newId(),
                startsAt: current.start,
                endsAt: current.end,
              ),
            ),
          )),
        ),
        IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(context, ref, current)),
        const SizedBox(width: 4),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final saved = await navigator.push<bool>(MaterialPageRoute(
            builder: (_) => EventEditPage(
              initial: event.copyWith(startsAt: current.start, endsAt: event.endsAt == null ? null : current.end),
              occurrence: current,
            ),
          ));
          // A changed series may no longer have this occurrence; go back to the calendar.
          if (saved == true) navigator.pop();
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Düzenle'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 6,
            height: 40,
            margin: const EdgeInsets.only(top: 4, right: 14),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(
            child: Text(event.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
          ),
          if (event.important)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Icon(Icons.priority_high_rounded, color: t.danger, semanticLabel: 'Önemli'),
            ),
        ]),
        const SizedBox(height: 20),
        _InfoRow(
          icon: Icons.schedule_rounded,
          text: sameDay
              ? '${day.format(current.start)}\n${timeRange(current.start, current.end, allDay: event.allDay)}'
              : event.allDay
                  ? '${day.format(current.start)} –\n${day.format(current.end.subtract(const Duration(days: 1)))}'
                  : '${day.format(current.start)} ${DateFormat('HH:mm').format(current.start)} –\n'
                      '${day.format(current.end)} ${DateFormat('HH:mm').format(current.end)}',
        ),
        if (event.recurrence != null) _InfoRow(icon: Icons.repeat_rounded, text: recurrenceLabel(event.recurrence!, event.startsAt)),
        if (event.reminders.isNotEmpty)
          _InfoRow(
            icon: Icons.notifications_rounded,
            text: event.reminders
                .map((r) => '${reminderLabel(r)}${r.priority == ReminderPriority.high ? ' · yüksek öncelik' : ''}')
                .join('\n'),
          ),
        if (event.notes != null) ...[
          const SizedBox(height: 12),
          NeuSurface(child: SelectableText(event.notes!, style: TextStyle(color: t.onBase, height: 1.4))),
        ],
      ]),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, EventOccurrence current) async {
    final navigator = Navigator.of(context);
    final SeriesScope? scope;
    if (current.isRecurring) {
      scope = await askSeriesScope(context, verb: 'Sil');
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Etkinlik silinsin mi?'),
          content: Text(current.event.title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
          ],
        ),
      );
      scope = confirmed == true ? SeriesScope.all : null;
    }
    if (scope == null) return;
    await ref.read(eventsRepositoryProvider).deleteOccurrence(current, scope);
    navigator.pop();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: t.muted, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }
}
