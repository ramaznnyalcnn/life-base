import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/notifications/reminder_sync.dart';
import '../../../core/storage/app_database.dart';
import 'dose_sheet.dart';
import 'med_detail_page.dart';
import 'med_edit_page.dart';
import 'med_format.dart';

class MedsScreen extends ConsumerWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final meds = ref.watch(localMedicationsProvider).value ?? const <Medication>[];
    final logs = ref.watch(doseLogsProvider).value ?? const <String, LocalDoseLog>{};
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final todayDoses = doseEntries(meds, logs, today, today.add(const Duration(days: 1)), now);
    final taken = todayDoses.where((e) => e.status == DoseStatus.taken).length;
    final asNeeded = meds.where((m) => m.asNeeded && m.active && !m.endedBy(today)).toList();
    final current = meds.where((m) => !m.asNeeded && m.active && !m.endedBy(today)).toList();
    final finished = meds.where((m) => !m.active || m.endedBy(today)).toList();

    return ModuleScaffold(
      module: LbModule.meds,
      title: 'İlaç',
      subtitle: todayDoses.isEmpty ? null : 'Bugün $taken/${todayDoses.length} doz alındı',
      addLabel: 'İlaç',
      addPageBuilder: (context) => const MedEditPage(),
      body: ListView(padding: moduleListPadding(context, hasAddButton: true), children: [
        if (current.isNotEmpty) _PermissionBanner(fullScreen: current.any((m) => m.alarm.fullScreen)),
        if (meds.isEmpty)
          NeuSurface(
            child: Row(children: [
              Icon(Icons.medication_rounded, color: t.module(LbModule.meds), size: 32),
              const SizedBox(width: 14),
              Expanded(child: Text('Henüz ilaç yok. Eklediğin ilaçlar için zamanında alarm çalar.', style: TextStyle(color: t.muted))),
            ]),
          ),
        if (todayDoses.isNotEmpty) ...[
          _Title('Bugün'),
          for (final entry in todayDoses) _DoseCard(entry: entry),
        ],
        if (asNeeded.isNotEmpty) ...[
          _Title('Gerektiğinde'),
          for (final med in asNeeded) _AsNeededCard(med: med, logs: logs),
        ],
        if (meds.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Adherence(meds: meds, logs: logs, today: today, now: now),
        ],
        if (current.isNotEmpty) ...[
          _Title('İlaçlarım'),
          for (final med in current) _MedTile(med: med),
        ],
        if (finished.isNotEmpty) ...[
          _Title('Biten veya duran'),
          for (final med in finished) Opacity(opacity: .6, child: _MedTile(med: med)),
        ],
      ]),
    );
  }
}

/// Dose alarms need notification permission, and work best with exact
/// alarms and full-screen alerts; offers the first missing grant.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner({required this.fullScreen});

  /// Whether any medication wants a full-screen alarm.
  final bool fullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final perms = ref.watch(alarmPermissionsProvider).value;
    final port = ref.watch(notificationPortProvider).value;
    if (perms == null || port == null) return const SizedBox.shrink();
    final (String text, Future<void> Function() request)? missing = !perms.notifications
        ? ('Bildirim izni kapalı: ilaç alarmları çalamaz.', port.requestNotifications)
        : !perms.exact
            ? ('Tam zamanlı alarm izni kapalı: alarmlar birkaç dakika gecikebilir.', port.requestExactAlarms)
            : fullScreen && !perms.fullScreen
                ? ('Tam ekran izni kapalı: alarm kilit ekranında açılamaz.', port.requestFullScreen)
                : null;
    if (missing == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuSurface(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          Icon(Icons.notifications_off_rounded, color: t.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(missing.$1, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () async {
              await missing.$2();
              ref.invalidate(alarmPermissionsProvider);
            },
            child: const Text('İzin ver'),
          ),
        ]),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: LbTokens.of(context).onBase)),
      );
}

class _DoseCard extends ConsumerWidget {
  const _DoseCard({required this.entry});
  final DoseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final med = entry.dose.medication;
    final color = statusColor(context, entry.status);
    final open = entry.status != DoseStatus.taken && entry.status != DoseStatus.skipped;
    final detail = [
      med.doseLabel,
      if (med.mealRelation != null) mealRelations[med.mealRelation]!,
      if (entry.status == DoseStatus.snoozed) '${DateFormat('HH:mm').format(entry.log!.snoozedUntil!.toLocal())}’e ertelendi',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => showDoseSheet(context, ref, entry),
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Text(DateFormat('HH:mm').format(entry.dose.at), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  med.name,
                  style: TextStyle(
                    color: open ? t.onBase : t.muted,
                    fontWeight: FontWeight.w700,
                    decoration: entry.status == DoseStatus.taken ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(detail, style: TextStyle(color: t.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(statusLabel(entry.status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (open)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.module(LbModule.meds),
                  foregroundColor: t.onAccent,
                  minimumSize: const Size(48, 44),
                ),
                onPressed: () => ref.read(doseActionsProvider).take(entry.dose),
                child: const Text('Aldım'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(entry.status == DoseStatus.taken ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, color: color),
              ),
          ]),
        ),
      ),
    );
  }
}

class _AsNeededCard extends ConsumerWidget {
  const _AsNeededCard({required this.med, required this.logs});
  final Medication med;
  final Map<String, LocalDoseLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final last = logs.values
        .where((log) => log.medicationId == med.id && log.status == 'taken')
        .map((log) => log.actedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, at) => latest == null || at.isAfter(latest) ? at : latest);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        depth: 4,
        radius: LbTokens.radiusSmall + 4,
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(children: [
          Icon(formIcon(med.form), color: t.module(LbModule.meds)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med.name, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
              Text(
                last == null ? med.doseLabel : '${med.doseLabel} · son: ${DateFormat('d MMM HH:mm', 'tr_TR').format(last.toLocal())}',
                style: TextStyle(color: t.muted, fontSize: 12),
              ),
            ]),
          ),
          OutlinedButton(
            onPressed: () async {
              await ref.read(doseActionsProvider).takeNow(med);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${med.name} kaydedildi')));
              }
            },
            child: const Text('Şimdi aldım'),
          ),
        ]),
      ),
    );
  }
}

/// Last seven days: share of scheduled doses taken per day.
class _Adherence extends StatelessWidget {
  const _Adherence({required this.meds, required this.logs, required this.today, required this.now});
  final List<Medication> meds;
  final Map<String, LocalDoseLog> logs;
  final DateTime today;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final color = t.module(LbModule.meds);
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final ratios = [
      for (final day in days)
        () {
          final entries = doseEntries(meds, logs, day, day.add(const Duration(days: 1)), now);
          if (entries.isEmpty) return null;
          return entries.where((e) => e.status == DoseStatus.taken).length / entries.length;
        }(),
    ];
    final known = ratios.whereType<double>();
    if (known.isEmpty) return const SizedBox.shrink();
    final average = known.reduce((a, b) => a + b) / known.length;
    return NeuSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Son 7 gün', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('%${(average * 100).round()} alındı', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 62,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    width: 14,
                    height: 4 + 34 * (ratios[i] ?? 0),
                    decoration: BoxDecoration(
                      color: ratios[i] == null ? t.shade : color.withValues(alpha: .35 + .65 * (ratios[i] ?? 0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('E', 'tr_TR').format(days[i]).substring(0, 2), style: TextStyle(color: t.muted, fontSize: 11)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _MedTile extends StatelessWidget {
  const _MedTile({required this.med});
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MedDetailPage(medicationId: med.id))),
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Icon(formIcon(med.form), color: t.module(LbModule.meds)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(med.name, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
                Text('${med.doseLabel} · ${scheduleLabel(med.schedule)}', style: TextStyle(color: t.muted, fontSize: 12)),
                if (med.stock != null)
                  Text(
                    '${formatAmount(med.stock!)} ${med.doseUnit} kaldı${med.lowStock ? ' · az kaldı' : ''}',
                    style: TextStyle(color: med.lowStock ? t.danger : t.muted, fontSize: 12, fontWeight: med.lowStock ? FontWeight.w800 : null),
                  ),
              ]),
            ),
            if (med.lowStock) Icon(Icons.warning_amber_rounded, color: t.danger),
          ]),
        ),
      ),
    );
  }
}
