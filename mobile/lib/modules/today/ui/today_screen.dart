import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/platform/device_calendar.dart';
import '../../../core/routes.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/wallet/wallet_models.dart';
import '../data/today_controller.dart';
import '../data/today_view.dart';

/// Bugün: a read-only summary of the day. Everything is added in its own module.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final view = ref.watch(todayViewProvider(today));
    final wallet = ref.watch(todayWalletProvider);

    return ModuleScaffold(
      module: LbModule.today,
      title: 'Bugün',
      subtitle: '${greeting(now)} · ${DateFormat('d MMMM, EEEE', 'tr_TR').format(now)}',
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(deviceEventsProvider);
          return ref.read(syncControllerProvider.notifier).syncNow();
        },
        child: ListView(padding: moduleListPadding(context), children: [
          const _SyncLine(),
          const SizedBox(height: 12),
          _NextCard(item: view.next, now: now),
          if (view.missed.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Kaçırılan dozlar', count: view.missed.length, danger: true),
            _MissedStrip(missed: view.missed),
          ],
          if (wallet != null) ...[
            const SizedBox(height: 24),
            _WalletCard(glance: wallet, now: now),
          ],
          const SizedBox(height: 24),
          _SectionTitle('Saat saat', count: view.timeline.length),
          if (view.timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Bugün sakin.', style: TextStyle(color: LbTokens.of(context).muted))),
            ),
          for (final item in view.timeline) _TimelineTile(item: item, now: now),
        ]),
      ),
    );
  }
}

void _open(BuildContext context, WidgetRef ref, TodayItem item) {
  switch (item.kind) {
    case TodayKind.event:
      // Opens over Bugün, in its own stack; back returns here.
      context.push(AppRoutes.todayEvent, extra: item.occurrence);
    case TodayKind.google:
      context.go(AppRoutes.calendarOn(item.start));
    case TodayKind.dose:
      showDoseActions(context, ref, item.dose!);
  }
}

/// Aldım / Ertele / Atla for one dose (or Geri al once answered).
Future<void> showDoseActions(BuildContext context, WidgetRef ref, DoseEntry entry) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final t = LbTokens.of(sheetContext);
        final dose = entry.dose;
        final med = dose.medication;
        final actions = ref.read(doseActionsProvider);
        final answered = entry.status == DoseStatus.taken || entry.status == DoseStatus.skipped;
        Future<void> act(Future<void> Function() action) async {
          Navigator.pop(sheetContext);
          await action();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(med.name, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
              const SizedBox(height: 4),
              Text(
                [DateFormat('HH:mm').format(dose.at), med.doseLabel, if (med.mealRelation != null) mealRelations[med.mealRelation] ?? ''].join(' · '),
                style: TextStyle(color: t.muted),
              ),
              const SizedBox(height: 20),
              if (answered)
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(entry.status == DoseStatus.taken ? 'Alındı — geri al' : 'Atlandı — geri al'),
                  onPressed: () => act(() => actions.undo(dose)),
                )
              else ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aldım'),
                  onPressed: () => act(() => actions.take(dose)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => act(() => actions.snooze(dose, med.alarm.snoozeMinutes)),
                      child: Text('${med.alarm.snoozeMinutes} dk ertele'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => act(() => actions.skip(dose)), child: const Text('Atla'))),
                ]),
              ],
            ]),
          ),
        );
      },
    );

/// Backup state, so the user knows whether today's changes have left the phone.
class _SyncLine extends ConsumerWidget {
  const _SyncLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final status = ref.watch(syncControllerProvider);
    final pending = ref.watch(localPendingCountProvider).value ?? 0;
    final last = status.lastSyncedAt;
    final (IconData icon, String text) = switch (status.phase) {
      SyncPhase.syncing => (Icons.sync_rounded, 'Eşitleniyor…'),
      SyncPhase.offline => (Icons.cloud_off_rounded, pending > 0 ? 'Çevrimdışı · $pending kayıt bekliyor' : 'Çevrimdışı'),
      SyncPhase.unauthorized => (Icons.lock_clock_rounded, 'Oturum yenilenmeli'),
      SyncPhase.failed => (Icons.error_outline_rounded, 'Eşitlenemedi'),
      SyncPhase.idle when pending > 0 => (Icons.cloud_upload_rounded, '$pending kayıt bekliyor'),
      SyncPhase.idle when last != null => (Icons.cloud_done_rounded, 'Eşitlendi · ${DateFormat('HH:mm').format(last)}'),
      SyncPhase.idle => (Icons.cloud_queue_rounded, 'Henüz eşitlenmedi'),
    };
    return Semantics(
      liveRegion: true,
      child: Row(children: [
        Icon(icon, size: 16, color: t.muted),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(color: t.muted, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _NextCard extends ConsumerWidget {
  const _NextCard({required this.item, required this.now});
  final TodayItem? item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final color = t.module(LbModule.today);
    final next = item;
    if (next == null) {
      return NeuSurface(
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text('Sıradaki plan beklemiyor', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final dose = next.dose;
    return GestureDetector(
      onTap: () => _open(context, ref, next),
      child: NeuSurface(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('SIRADAKİ', style: TextStyle(color: color, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(countdown(next.start, now),
                    textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(_icon(next.kind), color: t.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(next.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            [DateFormat('HH:mm').format(next.start), if (dose != null) dose.dose.medication.doseLabel else if (shortDuration(next).isNotEmpty) shortDuration(next)]
                .join(' · '),
            style: TextStyle(color: t.muted, fontWeight: FontWeight.w700),
          ),
          if (dose != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: t.module(LbModule.meds), foregroundColor: t.onAccent),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aldım'),
              onPressed: () => ref.read(doseActionsProvider).take(dose.dose),
            ),
          ],
        ]),
      ),
    );
  }
}

class _MissedStrip extends ConsumerWidget {
  const _MissedStrip({required this.missed});
  final List<DoseEntry> missed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: missed.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = missed[index];
          return ActionChip(
            avatar: Icon(Icons.medication_rounded, size: 18, color: t.danger),
            label: Text('${DateFormat('HH:mm').format(entry.dose.at)} ${entry.dose.medication.name}'),
            onPressed: () => showDoseActions(context, ref, entry),
          );
        },
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.glance, required this.now});
  final WalletGlance glance;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final color = t.module(LbModule.wallet);
    return GestureDetector(
      onTap: () => context.go(AppRoutes.wallet),
      child: NeuSurface(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('CÜZDAN', style: TextStyle(color: color, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Bugün ${formatMoney(glance.spentToday)} harcandı',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
          if (glance.dues.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Bu hafta ödeme yok.', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600)),
            ),
          for (final due in glance.dues.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(due.payment == null ? Icons.credit_card_rounded : Icons.event_repeat_rounded, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    due.payment == null ? '${due.title} son ödeme' : due.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(dueIn(due.due, now),
                    style: TextStyle(color: due.due.isBefore(DateTime(now.year, now.month, now.day)) ? t.danger : t.muted, fontSize: 13)),
                const SizedBox(width: 10),
                Text(formatMoney(due.amount, short: true), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800)),
              ]),
            ),
          if (glance.dues.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('+${glance.dues.length - 3} ödeme daha', style: TextStyle(color: t.muted, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.count, this.danger = false});
  final String text;
  final int count;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: danger ? t.danger : t.onBase)),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({required this.item, required this.now});
  final TodayItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final dose = item.dose;
    final past = !item.allDay && (item.end ?? item.start).isBefore(now) && dose == null;
    final subtitle = switch (item.kind) {
      TodayKind.dose => [
          'İlaç · ${dose!.dose.medication.doseLabel}',
          if (dose.status == DoseStatus.taken) 'alındı',
          if (dose.status == DoseStatus.skipped) 'atlandı',
          if (dose.status == DoseStatus.snoozed) 'ertelendi',
        ].join(' · '),
      TodayKind.google => ['Google', if (shortDuration(item).isNotEmpty && !item.allDay) shortDuration(item)].join(' · '),
      TodayKind.event => ['Etkinlik', if (shortDuration(item).isNotEmpty && !item.allDay) shortDuration(item)].join(' · '),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _open(context, ref, item),
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            SizedBox(
              width: 56,
              child: Text(item.allDay ? 'Tüm gün' : DateFormat('HH:mm').format(item.start),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: item.allDay ? 12 : 14, color: past || item.done ? t.muted : t.onBase)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: past || item.done ? t.muted : t.onBase,
                    fontWeight: FontWeight.w700,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: t.muted, fontSize: 12)),
              ]),
            ),
            if (dose != null && !item.done)
              IconButton(
                tooltip: 'Aldım',
                onPressed: () => ref.read(doseActionsProvider).take(dose.dose),
                icon: Icon(Icons.check_circle_outline_rounded, color: t.module(LbModule.meds)),
              )
            else
              Padding(padding: const EdgeInsets.all(12), child: Icon(_icon(item.kind), size: 20, color: t.muted)),
          ]),
        ),
      ),
    );
  }
}

IconData _icon(TodayKind kind) => switch (kind) {
      TodayKind.event => Icons.event_rounded,
      TodayKind.google => Icons.event_available_rounded,
      TodayKind.dose => Icons.medication_rounded,
    };
