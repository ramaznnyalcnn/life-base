import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/meds/medication.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/local_sync.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/wallet/wallet_store.dart';

final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) => MedicationsRepository(
      ref.watch(databaseProvider),
      onChanged: () => ref.read(syncControllerProvider.notifier).requestSync(),
      me: () => ref.read(walletMeProvider),
    ));

/// Medication writes; every write is stamped and queued for sync.
class MedicationsRepository {
  MedicationsRepository(this._db, {void Function()? onChanged, int Function()? me})
      : _onChanged = onChanged ?? (() {}),
        _me = me ?? (() => 0);

  final AppDatabase _db;
  final void Function() _onChanged;

  /// This user's id (0 while unknown); stamped on medications they add.
  final int Function() _me;

  String newId() => const Uuid().v4();

  Future<LocalMedication?> _row(String id) => (_db.select(_db.localMedications)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> save(Medication medication) async {
    final me = _me();
    await _db.transaction(() async {
      final previous = await _row(medication.id);
      final owner = previous?.createdBy ?? medication.createdBy ?? (me == 0 ? null : me);
      await _db.into(_db.localMedications).insertOnConflictUpdate(medication.copyWith(createdBy: owner).toRow(nextStamp(previous?.updatedAtMs)));
    });
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final row = await _row(id);
      if (row == null) return;
      final stamp = nextStamp(row.updatedAtMs);
      await (_db.update(_db.localMedications)..where((t) => t.id.equals(id))).write(
        LocalMedicationsCompanion(deletedAtMs: Value(stamp), updatedAtMs: Value(stamp), dirty: const Value(true)),
      );
    });
    _onChanged();
  }

  /// A refill: adds [amount] (in dose units) to the stock.
  Future<void> addStock(String id, double amount) async {
    await _db.transaction(() async {
      final row = await _row(id);
      if (row == null) return;
      await (_db.update(_db.localMedications)..where((t) => t.id.equals(id))).write(LocalMedicationsCompanion(
        stock: Value(((row.stock ?? 0) + amount).clamp(0, double.infinity).toDouble()),
        updatedAtMs: Value(nextStamp(row.updatedAtMs)),
        dirty: const Value(true),
      ));
    });
    _onChanged();
  }
}
