import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'calendar_event.dart';
import '../providers.dart';
import '../storage/app_database.dart';
import '../sync/local_sync.dart';
import '../sync/sync_controller.dart';
import '../wallet/wallet_store.dart';

/// Which part of a repeating series an edit or delete applies to.
enum SeriesScope { thisOne, thisAndFollowing, all }

final eventsRepositoryProvider = Provider<EventsRepository>((ref) => EventsRepository(
      ref.watch(databaseProvider),
      onChanged: () => ref.read(syncControllerProvider.notifier).requestSync(),
      me: () => ref.read(walletMeProvider),
    ));

/// All calendar writes. Every write stamps the row and marks it for sync.
class EventsRepository {
  EventsRepository(this._db, {void Function()? onChanged, String Function()? newId, int Function()? me})
      : _onChanged = onChanged ?? (() {}),
        _newId = newId ?? (() => const Uuid().v4()),
        _me = me ?? (() => 0);

  final AppDatabase _db;
  final void Function() _onChanged;
  final String Function() _newId;

  /// This user's id (0 while unknown); stamped on events they add.
  final int Function() _me;

  String newId() => _newId();

  Future<CalendarEvent?> find(String id) async {
    final row = await (_db.select(_db.localEvents)..where((t) => t.id.equals(id) & t.deletedAtMs.isNull())).getSingleOrNull();
    return row == null ? null : CalendarEvent.fromRow(row);
  }

  Future<void> save(CalendarEvent event) async {
    final me = _me();
    await _db.transaction(() => _write(event, me));
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.localEvents)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      final stamp = nextStamp(row.updatedAtMs);
      await (_db.update(_db.localEvents)..where((t) => t.id.equals(id))).write(
        LocalEventsCompanion(deletedAtMs: Value(stamp), updatedAtMs: Value(stamp), dirty: const Value(true)),
      );
    });
    _onChanged();
  }

  /// Applies [edited] (the occurrence as the user changed it) to [occurrence].
  Future<void> updateOccurrence(EventOccurrence occurrence, CalendarEvent edited, SeriesScope scope) async {
    final series = occurrence.event;
    if (series.recurrence == null || scope == SeriesScope.all || _isFirst(occurrence)) {
      // Move the whole series by however much this occurrence moved.
      final shift = edited.startsAt.difference(occurrence.start);
      final start = series.recurrence == null ? edited.startsAt : series.startsAt.add(shift);
      await save(edited.copyWith(
        id: series.id,
        startsAt: start,
        endsAt: edited.endsAt == null ? null : start.add(edited.endsAt!.difference(edited.startsAt)),
        clearEndsAt: edited.endsAt == null,
      ));
      return;
    }
    final me = _me();
    await _db.transaction(() async {
      final day = _day(occurrence.start);
      if (scope == SeriesScope.thisOne) {
        await _write(series.copyWith(recurrence: series.recurrence!.copyWith(exdates: [...series.recurrence!.exdates, day])), me);
        await _write(edited.copyWith(id: newId(), clearRecurrence: true), me);
      } else {
        await _write(series.copyWith(recurrence: series.recurrence!.copyWith(until: day.subtract(const Duration(days: 1)))), me);
        await _write(edited.copyWith(id: newId(), recurrence: edited.recurrence ?? series.recurrence), me);
      }
    });
    _onChanged();
  }

  Future<void> deleteOccurrence(EventOccurrence occurrence, SeriesScope scope) async {
    final series = occurrence.event;
    if (series.recurrence == null || scope == SeriesScope.all || (scope == SeriesScope.thisAndFollowing && _isFirst(occurrence))) {
      await delete(series.id);
      return;
    }
    final day = _day(occurrence.start);
    final rule = scope == SeriesScope.thisOne
        ? series.recurrence!.copyWith(exdates: [...series.recurrence!.exdates, day])
        : series.recurrence!.copyWith(until: day.subtract(const Duration(days: 1)));
    await save(series.copyWith(recurrence: rule));
  }

  /// [me] is read before the transaction: the provider behind it queries
  /// the database, which would wait for the transaction to end.
  Future<void> _write(CalendarEvent event, int me) async {
    final previous = await (_db.select(_db.localEvents)..where((t) => t.id.equals(event.id))).getSingleOrNull();
    final owner = previous?.createdBy ?? event.createdBy ?? (me == 0 ? null : me);
    await _db.into(_db.localEvents).insertOnConflictUpdate(event.copyWith(createdBy: owner).toRow(nextStamp(previous?.updatedAtMs)));
  }

  static bool _isFirst(EventOccurrence occurrence) => _day(occurrence.start) == _day(occurrence.event.startsAt);
  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
