import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/app_database.dart';
import '../sync/local_sync.dart';
import '../sync/sync_controller.dart';
import 'medication.dart';

/// Every live local medication.
final localMedicationsProvider = StreamProvider<List<Medication>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.localMedications)..where((t) => t.deletedAtMs.isNull()))
      .watch()
      .map((rows) => rows.map(Medication.fromRow).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
});

/// Dose logs of the last 60 days (and any future snoozes), by id.
final doseLogsProvider = StreamProvider<Map<String, LocalDoseLog>>((ref) {
  final db = ref.watch(databaseProvider);
  final since = DateTime.now().subtract(const Duration(days: 60));
  return (db.select(db.localDoseLogs)..where((t) => t.deletedAtMs.isNull() & t.scheduledFor.isBiggerOrEqualValue(since)))
      .watch()
      .map((rows) => {for (final row in rows) row.id: row});
});

/// A scheduled dose with its current state.
class DoseEntry {
  const DoseEntry(this.dose, this.status, this.log);
  final ScheduledDose dose;
  final DoseStatus status;
  final LocalDoseLog? log;
}

List<DoseEntry> doseEntries(List<Medication> meds, Map<String, LocalDoseLog> logs, DateTime from, DateTime to, DateTime now) => [
      for (final dose in [for (final med in meds) ...med.dosesBetween(from, to)]..sort((a, b) => a.at.compareTo(b.at)))
        DoseEntry(dose, doseStatus(dose, logs[dose.id], now), logs[dose.id]),
    ];

final doseActionsProvider = Provider<DoseActions>((ref) => DoseActions(
      ref.watch(databaseProvider),
      onChanged: () => ref.read(syncControllerProvider.notifier).requestSync(),
    ));

/// Marking doses. Taking a dose uses up stock; undoing gives it back.
class DoseActions {
  DoseActions(this._db, {void Function()? onChanged}) : _onChanged = onChanged ?? (() {});

  final AppDatabase _db;
  final void Function() _onChanged;

  Future<void> take(ScheduledDose dose, {DateTime? at}) => _log(dose.medication.id, dose.at, 'taken', actedAt: at ?? DateTime.now());

  Future<void> skip(ScheduledDose dose) => _log(dose.medication.id, dose.at, 'skipped', actedAt: DateTime.now());

  Future<void> snooze(ScheduledDose dose, int minutes) =>
      _log(dose.medication.id, dose.at, 'snoozed', snoozedUntil: DateTime.now().add(Duration(minutes: minutes)));

  /// An as-needed intake right now.
  Future<void> takeNow(Medication medication) {
    final now = DateTime.now();
    return _log(medication.id, DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second), 'taken', actedAt: now);
  }

  /// Back to "not answered" (corrects a wrong tap). Written as a `cleared`
  /// state rather than a deletion: deletions are final in sync, and the same
  /// dose must stay answerable.
  Future<void> undo(ScheduledDose dose) => _log(dose.medication.id, dose.at, 'cleared');

  Future<void> _log(String medicationId, DateTime scheduledFor, String status, {DateTime? actedAt, DateTime? snoozedUntil}) async {
    final id = doseLogId(medicationId, scheduledFor);
    await _db.transaction(() async {
      final previous = await (_db.select(_db.localDoseLogs)..where((t) => t.id.equals(id))).getSingleOrNull();
      final wasTaken = previous != null && previous.deletedAtMs == null && previous.status == 'taken';
      if (status == 'taken' && !wasTaken) await _adjustStock(medicationId, -1);
      if (status != 'taken' && wasTaken) await _adjustStock(medicationId, 1);
      await _db.into(_db.localDoseLogs).insertOnConflictUpdate(LocalDoseLogsCompanion.insert(
            id: id,
            medicationId: medicationId,
            scheduledFor: scheduledFor.toUtc(),
            status: status,
            actedAt: Value(actedAt?.toUtc()),
            snoozedUntil: Value(snoozedUntil?.toUtc()),
            updatedAtMs: nextStamp(previous?.updatedAtMs),
            deletedAtMs: const Value(null),
            dirty: const Value(true),
          ));
    });
    _onChanged();
  }

  /// [doses] > 0 returns stock, < 0 uses it. Stock never goes below zero.
  Future<void> _adjustStock(String medicationId, int doses) async {
    final row = await (_db.select(_db.localMedications)..where((t) => t.id.equals(medicationId))).getSingleOrNull();
    if (row == null || row.stock == null) return;
    final stock = (row.stock! + doses * row.doseAmount).clamp(0, double.infinity).toDouble();
    await (_db.update(_db.localMedications)..where((t) => t.id.equals(medicationId))).write(LocalMedicationsCompanion(
      stock: Value(stock),
      updatedAtMs: Value(nextStamp(row.updatedAtMs)),
      dirty: const Value(true),
    ));
  }
}

/// Rebuilds a scheduled dose from its id (`<medicationId>@<UTC ISO>`).
Future<ScheduledDose?> findDose(AppDatabase db, String doseId) async {
  final parsed = parseDoseLogId(doseId);
  if (parsed == null) return null;
  final row = await (db.select(db.localMedications)..where((t) => t.id.equals(parsed.medicationId))).getSingleOrNull();
  return row == null ? null : ScheduledDose(Medication.fromRow(row), parsed.at);
}
