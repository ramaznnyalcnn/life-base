import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'local_sync.dart';

class ApiSyncTransport implements SyncTransport {
  const ApiSyncTransport(this._api);

  final ApiClient _api;

  @override
  Future<PushResult> push(List<SyncDocument> changes) => _guard(() async {
        final body = await _api.syncPush([for (final change in changes) change.toJson()]);
        return PushResult(
          applied: (body['applied'] as List? ?? const []).cast<String>().toSet(),
          stale: _documents(body['stale']),
          cursor: (body['cursor'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<PullResult> pull(int since) => _guard(() async {
        final body = await _api.syncPull(since);
        return PullResult(
          changes: _documents(body['changes']),
          cursor: (body['cursor'] as num?)?.toInt() ?? since,
          hasMore: body['has_more'] == true,
        );
      });

  static List<SyncDocument> _documents(Object? raw) => (raw as List? ?? const [])
      .cast<Map>()
      .map((item) => SyncDocument.fromJson(Map<String, Object?>.from(item)))
      .toList();

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) throw const SyncUnauthorizedException();
      // Network trouble and server errors are retried on the next trigger.
      if (status == null || status >= 500) throw const SyncOfflineException();
      throw SyncRejectedException(status);
    }
  }
}
