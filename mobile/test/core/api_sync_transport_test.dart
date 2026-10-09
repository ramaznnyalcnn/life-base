import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/network/api_client.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/sync/api_sync_transport.dart';
import 'package:lifebase_mobile/core/sync/local_sync.dart';

/// Answers every request with a fixed status (or a connection error).
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body = const {}]);
  final int? status;
  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (status == null) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    return ResponseBody.fromString(jsonEncode(body), status!, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => db.close());

  ApiSyncTransport transport(int? status, [Map<String, Object?> body = const {}]) => ApiSyncTransport(ApiClient(
        serverUrl: 'http://test',
        token: 't',
        database: db,
        dio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _Adapter(status, body),
      ));

  test('pull parses documents, cursor and paging', () async {
    final result = await transport(200, {
      'changes': [
        {'collection': 'events', 'id': 'e1', 'updated_at': '2026-10-09T12:00:00Z', 'deleted': false, 'body': {'title': 'x'}, 'seq': 4},
      ],
      'cursor': 4,
      'has_more': true,
    }).pull(0);

    expect(result.changes.single.key, 'events/e1');
    expect(result.changes.single.body, {'title': 'x'});
    expect(result.cursor, 4);
    expect(result.hasMore, isTrue);
  });

  test('errors map to retry, sign-in and rejection outcomes', () async {
    expect(() => transport(null).pull(0), throwsA(isA<SyncOfflineException>()));
    expect(() => transport(503).pull(0), throwsA(isA<SyncOfflineException>()));
    expect(() => transport(401).pull(0), throwsA(isA<SyncUnauthorizedException>()));
    expect(
      () => transport(404).pull(0),
      throwsA(isA<SyncRejectedException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });
}
