import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/operation.dart';
import '../network/api_client.dart';
import '../storage/app_database.dart';
import 'queue_policy.dart';

class SyncReport {
  const SyncReport({this.completed = 0, this.paused = false, this.conflicts = 0});

  final int completed;
  final bool paused;
  final int conflicts;
}

class SyncService {
  const SyncService(this._database, this._api);

  final AppDatabase _database;
  final ApiClient _api;

  Future<void> enqueue(OperationEnvelope operation) => _database.enqueue(
        requestId: operation.requestId,
        operationKey: operation.operationKey,
        payload: operation.encode(),
      );

  Future<SyncReport> flush() async {
    var completed = 0;
    var conflicts = 0;
    for (final row in await _database.pending()) {
      try {
        await _api.execute(OperationEnvelope.decode(row.payload));
        await _database.markDone(row.requestId);
        completed += 1;
      } on DioException catch (error) {
        final decision = QueuePolicy.forStatus(error.response?.statusCode);
        switch (decision) {
          case QueueDecision.retry:
            return SyncReport(completed: completed, conflicts: conflicts);
          case QueueDecision.pause:
            await _database.markState(row.requestId, 'paused');
            return SyncReport(completed: completed, paused: true, conflicts: conflicts);
          case QueueDecision.resolveConflict:
            await _database.markState(
              row.requestId,
              'conflict',
              conflict: jsonEncode(error.response?.data),
            );
            conflicts += 1;
            return SyncReport(completed: completed, conflicts: conflicts);
          case QueueDecision.drop:
            await _database.markState(row.requestId, 'failed');
            return SyncReport(completed: completed, conflicts: conflicts);
        }
      }
    }
    return SyncReport(completed: completed, conflicts: conflicts);
  }
}
