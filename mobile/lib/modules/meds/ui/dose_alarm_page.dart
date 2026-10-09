import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/platform/platform_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/routes.dart';
import 'med_format.dart';

/// The full-screen dose alarm: opens over the lock screen when the alarm
/// fires (or from the notification) with Aldım / Ertele / Atla.
class DoseAlarmPage extends ConsumerStatefulWidget {
  const DoseAlarmPage({super.key, required this.doseId});

  final String doseId;

  @override
  ConsumerState<DoseAlarmPage> createState() => _DoseAlarmPageState();
}

class _DoseAlarmPageState extends ConsumerState<DoseAlarmPage> {
  // Kept for dispose, where `ref` can no longer be used.
  late final PlatformBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = ref.read(platformBridgeProvider);
    _showOverLockScreen(true);
  }

  @override
  void dispose() {
    // Only this page may show above the lock screen; the wallet must not.
    _showOverLockScreen(false);
    super.dispose();
  }

  void _showOverLockScreen(bool enabled) =>
      unawaited(_bridge.setShowOverLockScreen(enabled).catchError((Object _) {}));

  void _close() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.meds);
    }
  }

  Future<void> _answer(Future<void> Function() action) async {
    await action();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final parsed = parseDoseLogId(widget.doseId);
    final meds = ref.watch(localMedicationsProvider).value;
    final logs = ref.watch(doseLogsProvider).value;
    if (meds == null || logs == null) return Scaffold(backgroundColor: t.base);
    final med = parsed == null ? null : meds.where((m) => m.id == parsed.medicationId).firstOrNull;
    if (parsed == null || med == null) {
      return Scaffold(
        backgroundColor: t.base,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bu doz artık yok.', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextButton(onPressed: _close, child: const Text('Kapat')),
        ])),
      );
    }

    final dose = ScheduledDose(med, parsed.at);
    final status = doseStatus(dose, logs[dose.id], DateTime.now());
    final answered = status == DoseStatus.taken || status == DoseStatus.skipped;
    final color = t.module(LbModule.meds);
    final actions = ref.read(doseActionsProvider);
    final details = [
      med.doseLabel,
      if (med.mealRelation != null) mealRelations[med.mealRelation] ?? med.mealRelation!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: t.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(tooltip: 'Kapat', onPressed: _close, icon: Icon(Icons.close_rounded, color: t.muted)),
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
                child: Icon(formIcon(med.form), size: 56, color: color),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              DateFormat('HH:mm').format(dose.at),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: t.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              med.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: t.onBase, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(details, textAlign: TextAlign.center, style: TextStyle(color: t.onBase, fontSize: 20, fontWeight: FontWeight.w600)),
            if (med.notes != null) ...[
              const SizedBox(height: 12),
              Text(med.notes!, textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 16)),
            ],
            if (answered) ...[
              const SizedBox(height: 20),
              Text(
                statusLabel(status),
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor(context, status), fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
            const Spacer(),
            if (answered)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                onPressed: _close,
                child: const Text('Kapat'),
              )
            else ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: t.onAccent,
                  minimumSize: const Size.fromHeight(72),
                  textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _answer(() => actions.take(dose)),
                icon: const Icon(Icons.check_rounded, size: 30),
                label: const Text('Aldım'),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => _answer(() => actions.snooze(dose, med.alarm.snoozeMinutes)),
                    icon: const Icon(Icons.snooze_rounded),
                    label: Text('${med.alarm.snoozeMinutes} dk ertele'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => _answer(() => actions.skip(dose)),
                    icon: const Icon(Icons.not_interested_rounded),
                    label: const Text('Atla'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
