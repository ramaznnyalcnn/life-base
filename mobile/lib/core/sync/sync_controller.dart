import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/sync_collections.dart';
import 'api_sync_transport.dart';
import 'local_sync.dart';

enum SyncPhase { idle, syncing, offline, unauthorized, failed }

@immutable
class SyncStatus {
  const SyncStatus({this.phase = SyncPhase.idle, this.lastSyncedAt, this.statusCode});
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final int? statusCode;
}

final localSyncEngineProvider = Provider<LocalSyncEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final db = ref.watch(databaseProvider);
  return LocalSyncEngine(database: db, transport: ApiSyncTransport(api), collections: localSyncCollections(db));
});

/// Rows (events, medications, dose logs) not yet backed up to the server.
final localPendingCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT (SELECT COUNT(*) FROM local_events WHERE dirty = 1)'
        ' + (SELECT COUNT(*) FROM local_medications WHERE dirty = 1)'
        ' + (SELECT COUNT(*) FROM local_dose_logs WHERE dirty = 1) AS c',
        readsFrom: {db.localEvents, db.localMedications, db.localDoseLogs},
      )
      .watchSingle()
      .map((row) => row.read<int>('c'));
});

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Decides when local-first data syncs: at start, when the network returns,
/// when the app comes back to the foreground, and shortly after local edits.
class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;

  @override
  SyncStatus build() {
    final connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) requestSync();
    });
    final lifecycle = AppLifecycleListener(onResume: requestSync);
    ref.onDispose(() {
      _debounce?.cancel();
      connectivity.cancel();
      lifecycle.dispose();
    });
    Future.microtask(syncNow);
    return const SyncStatus();
  }

  /// Coalesces bursts of edits into one sync.
  void requestSync({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  Future<SyncOutcome?> syncNow() async {
    final engine = ref.read(localSyncEngineProvider);
    if (engine == null || !ref.mounted) return null;
    state = SyncStatus(phase: SyncPhase.syncing, lastSyncedAt: state.lastSyncedAt);
    final outcome = await engine.run();
    if (!ref.mounted) return outcome;
    state = switch (outcome.kind) {
      SyncOutcomeKind.synced => SyncStatus(lastSyncedAt: DateTime.now()),
      SyncOutcomeKind.offline => SyncStatus(phase: SyncPhase.offline, lastSyncedAt: state.lastSyncedAt),
      SyncOutcomeKind.unauthorized => SyncStatus(phase: SyncPhase.unauthorized, lastSyncedAt: state.lastSyncedAt),
      SyncOutcomeKind.failed =>
        SyncStatus(phase: SyncPhase.failed, lastSyncedAt: state.lastSyncedAt, statusCode: outcome.statusCode),
    };
    return outcome;
  }
}
