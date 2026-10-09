import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import 'med_format.dart';

/// Answer or correct one dose: take, snooze, skip, or undo a wrong tap.
Future<void> showDoseSheet(BuildContext context, WidgetRef ref, DoseEntry entry) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final dose = entry.dose;
        final med = dose.medication;
        final actions = ref.read(doseActionsProvider);
        final answered = entry.status == DoseStatus.taken || entry.status == DoseStatus.skipped;
        Future<void> run(Future<void> Function() action) async {
          Navigator.pop(sheetContext);
          await action();
        }

        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(med.name, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${med.doseLabel} · ${DateFormat('d MMM HH:mm', 'tr_TR').format(dose.at)} · ${statusLabel(entry.status)}'),
            const SizedBox(height: 12),
            if (entry.status != DoseStatus.taken)
              ListTile(
                leading: const Icon(Icons.check_circle_rounded),
                title: const Text('Aldım'),
                onTap: () => run(() => actions.take(dose)),
              ),
            if (!answered)
              ListTile(
                leading: const Icon(Icons.snooze_rounded),
                title: Text('${med.alarm.snoozeMinutes} dk ertele'),
                onTap: () => run(() => actions.snooze(dose, med.alarm.snoozeMinutes)),
              ),
            if (entry.status != DoseStatus.skipped)
              ListTile(
                leading: const Icon(Icons.not_interested_rounded),
                title: const Text('Atla'),
                onTap: () => run(() => actions.skip(dose)),
              ),
            if (entry.log != null && entry.log!.status != 'cleared')
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Geri al (cevaplanmamış yap)'),
                onTap: () => run(() => actions.undo(dose)),
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
