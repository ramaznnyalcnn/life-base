import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/storage/app_database.dart';
import '../data/medications_repository.dart';
import 'dose_sheet.dart';
import 'med_edit_page.dart';
import 'med_format.dart';

const _historyDays = 14;

/// One medication: what, when, stock, and the last two weeks of doses
/// (tap a dose to correct it).
class MedDetailPage extends ConsumerWidget {
  const MedDetailPage({super.key, required this.medicationId});

  final String medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final med = ref.watch(localMedicationsProvider).value?.where((m) => m.id == medicationId).firstOrNull;
    if (med == null) return Scaffold(appBar: AppBar());
    final logs = ref.watch(doseLogsProvider).value ?? const <String, LocalDoseLog>{};
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final dateFmt = DateFormat('d MMMM y', 'tr_TR');
    final ended = !med.active || med.endedBy(today);
    final history = _history(med, logs, today, now);

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(context, ref, med)),
        const SizedBox(width: 4),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => MedEditPage(initial: med))),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Düzenle'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        Row(children: [
          Icon(formIcon(med.form), color: t.module(LbModule.meds), size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Text(med.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
          ),
        ]),
        const SizedBox(height: 20),
        _InfoRow(icon: Icons.medication_liquid_rounded, text: '${med.doseLabel} · ${medForms[med.form] ?? med.form}'),
        _InfoRow(icon: Icons.schedule_rounded, text: scheduleLabel(med.schedule)),
        if (med.mealRelation != null) _InfoRow(icon: Icons.restaurant_rounded, text: mealRelations[med.mealRelation] ?? med.mealRelation!),
        _InfoRow(
          icon: Icons.date_range_rounded,
          text: med.endsOn == null
              ? '${dateFmt.format(med.startsOn)} – süresiz'
              : '${dateFmt.format(med.startsOn)} – ${dateFmt.format(med.endsOn!)}',
        ),
        if (!med.asNeeded)
          _InfoRow(
            icon: Icons.alarm_rounded,
            text: [
              med.alarm.fullScreen ? 'Tam ekran alarm' : 'Bildirim',
              '${med.alarm.snoozeMinutes} dk ertele',
              if (med.alarm.maxRepeats > 0) '${med.alarm.repeatEveryMinutes} dk arayla ${med.alarm.maxRepeats} kez tekrar',
            ].join(' · '),
          ),
        if (med.notes != null) ...[
          const SizedBox(height: 4),
          NeuSurface(child: SelectableText(med.notes!, style: TextStyle(color: t.onBase, height: 1.4))),
        ],
        const SizedBox(height: 16),
        if (med.stock != null) ...[
          NeuSurface(
            child: Row(children: [
              Icon(med.lowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded, color: med.lowStock ? t.danger : t.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${formatAmount(med.stock!)} ${med.doseUnit} kaldı',
                      style: TextStyle(color: med.lowStock ? t.danger : t.onBase, fontWeight: FontWeight.w800)),
                  if (med.stockAlert != null)
                    Text('${formatAmount(med.stockAlert!)} ${med.doseUnit} ve altında uyarır', style: TextStyle(color: t.muted, fontSize: 12)),
                ]),
              ),
              OutlinedButton(onPressed: () => _refill(context, ref, med), child: const Text('Stok ekle')),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => ref.read(medicationsRepositoryProvider).save(ended ? _restarted(med, today) : _stopped(med, today)),
          icon: Icon(ended ? Icons.play_arrow_rounded : Icons.stop_rounded),
          label: Text(ended ? 'Yeniden başlat' : 'Bitir (alarmlar susar)'),
        ),
        const SizedBox(height: 20),
        Text(
          'Son $_historyDays gün',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase),
        ),
        const SizedBox(height: 4),
        Text('Yanlış işaretlediysen doza dokunup düzelt.', style: TextStyle(color: t.muted, fontSize: 12)),
        const SizedBox(height: 12),
        if (history.isEmpty) Text('Henüz kayıt yok.', style: TextStyle(color: t.muted)),
        for (final (day, entries) in history) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              DateUtils.isSameDay(day, today) ? 'Bugün' : DateFormat('d MMMM EEEE', 'tr_TR').format(day),
              style: TextStyle(color: t.muted, fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in entries) _HistoryRow(entry: entry),
        ],
      ]),
    );
  }

  /// Ends the course yesterday, so today's remaining doses stop ringing and
  /// nothing after shows up as missed. A course that has not started yet is
  /// switched off instead.
  static Medication _stopped(Medication med, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    if (!med.startsOn.isBefore(today)) return med.copyWith(active: false);
    return med.copyWith(endsOn: med.endsOn != null && med.endsOn!.isBefore(yesterday) ? med.endsOn : yesterday);
  }

  /// A new open-ended course from today; the stopped days stay out of it.
  static Medication _restarted(Medication med, DateTime today) =>
      med.copyWith(active: true, startsOn: med.startsOn.isAfter(today) ? med.startsOn : today, clearEndsOn: true);

  /// Newest day first: scheduled doses up to now, plus any recorded answer
  /// outside the schedule (as-needed intakes, doses of a changed schedule).
  static List<(DateTime, List<DoseEntry>)> _history(Medication med, Map<String, LocalDoseLog> logs, DateTime today, DateTime now) {
    final from = today.subtract(const Duration(days: _historyDays - 1));
    final scheduled = doseEntries([med], logs, from, now, now);
    final seen = {for (final e in scheduled) e.dose.id};
    final entries = [
      ...scheduled,
      for (final log in logs.values)
        if (log.medicationId == med.id && (log.status == 'taken' || log.status == 'skipped') && !seen.contains(log.id))
          if (log.scheduledFor.toLocal() case final at when !at.isBefore(from) && !at.isAfter(now))
            DoseEntry(ScheduledDose(med, at), log.status == 'taken' ? DoseStatus.taken : DoseStatus.skipped, log),
    ]..sort((a, b) => a.dose.at.compareTo(b.dose.at));
    final byDay = <DateTime, List<DoseEntry>>{};
    for (final entry in entries.reversed) {
      byDay.putIfAbsent(DateUtils.dateOnly(entry.dose.at), () => []).add(entry);
    }
    return [for (final e in byDay.entries) (e.key, e.value)];
  }

  Future<void> _refill(BuildContext context, WidgetRef ref, Medication med) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        double? parse() => double.tryParse(controller.text.trim().replaceAll(',', '.'));
        return AlertDialog(
          title: const Text('Stok ekle'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Miktar', suffixText: med.doseUnit),
            onSubmitted: (_) => Navigator.pop(dialogContext, parse()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, parse()), child: const Text('Ekle')),
          ],
        );
      },
    );
    controller.dispose();
    if (amount != null && amount > 0) await ref.read(medicationsRepositoryProvider).addStock(med.id, amount);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Medication med) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İlaç silinsin mi?'),
        content: Text('${med.name} ve alarmları silinir. Bitirdiysen "Bitir" geçmişi korur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(medicationsRepositoryProvider).delete(med.id);
    navigator.pop();
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});
  final DoseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final color = statusColor(context, entry.status);
    final takenAt = entry.status == DoseStatus.taken ? entry.log?.actedAt?.toLocal() : null;
    final late = takenAt != null && takenAt.difference(entry.dose.at).inMinutes >= 15;
    return InkWell(
      borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
      onTap: () => showDoseSheet(context, ref, entry),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Text(DateFormat('HH:mm').format(entry.dose.at), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800)),
          ),
          Icon(
            switch (entry.status) {
              DoseStatus.taken => Icons.check_circle_rounded,
              DoseStatus.skipped => Icons.remove_circle_outline_rounded,
              DoseStatus.missed => Icons.cancel_rounded,
              _ => Icons.radio_button_unchecked_rounded,
            },
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              late ? '${statusLabel(entry.status)} · ${DateFormat('HH:mm').format(takenAt)}’de' : statusLabel(entry.status),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Icon(Icons.edit_rounded, size: 16, color: t.muted),
        ]),
      ),
    );
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
