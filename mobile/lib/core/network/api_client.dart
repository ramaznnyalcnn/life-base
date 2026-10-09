import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../models/agenda.dart';
import '../models/operation.dart';
import '../storage/app_database.dart';

class ApiClient {
  ApiClient({
    required String serverUrl,
    required String token,
    required AppDatabase database,
    Dio? dio,
  })  : _database = database,
        _cachePrefix = '${serverUrl.hashCode}:${token.hashCode}',
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: serverUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'Authorization': 'Bearer $token'},
            ));

  final Dio _dio;
  final AppDatabase _database;
  final String _cachePrefix;

  String _key(String value) => '$_cachePrefix:$value';

  Future<Map<String, Object?>> _cachedMap(
    String key,
    Future<Map<String, Object?>> Function() fetch,
  ) async {
    try {
      final value = await fetch();
      await _database.cache(_key(key), jsonEncode(value));
      return value;
    } on DioException {
      final value = await _database.cached(_key(key));
      if (value == null) rethrow;
      return Map<String, Object?>.from(jsonDecode(value) as Map);
    }
  }

  Future<List<Object?>> _cachedList(
    String key,
    Future<List<Object?>> Function() fetch,
  ) async {
    try {
      final value = await fetch();
      await _database.cache(_key(key), jsonEncode(value));
      return value;
    } on DioException {
      final value = await _database.cached(_key(key));
      if (value == null) rethrow;
      return List<Object?>.from(jsonDecode(value) as List);
    }
  }

  Future<TodayAgenda> today(DateTime date) async {
    final key = _key('agenda:${DateFormat('yyyy-MM-dd').format(date)}');
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/v2/agenda/today',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(date),
          'timezone': 'Europe/Istanbul',
        },
      );
      final body = response.data!;
      await _database.cache(key, jsonEncode(body));
      return TodayAgenda.fromJson(body);
    } on DioException {
      final cached = await _database.cached(key);
      if (cached == null) rethrow;
      return TodayAgenda.fromJson(
        Map<String, Object?>.from(jsonDecode(cached) as Map),
        fromCache: true,
      );
    }
  }

  Future<List<AgendaItem>> agendaRange(DateTime from, DateTime to) async {
    final fromValue = DateFormat('yyyy-MM-dd').format(from);
    final toValue = DateFormat('yyyy-MM-dd').format(to);
    final body = await _cachedMap('agenda-range:$fromValue:$toValue', () async =>
        (await _dio.get<Map<String, Object?>>(
          '/api/v2/agenda/range',
          queryParameters: {'from': fromValue, 'to': toValue, 'timezone': 'Europe/Istanbul'},
        )).data!);
    return (body['items'] as List)
        .cast<Map>()
        .map((item) => AgendaItem.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  Future<Map<String, Object?>> execute(OperationEnvelope operation) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/v2/operations/execute',
      data: operation.toApiJson(),
    );
    return response.data!;
  }

  /// A raw operation envelope (wallet outbox).
  Future<Map<String, Object?>> executeEnvelope(Map<String, Object?> envelope) async =>
      (await _dio.post<Map<String, Object?>>('/api/v2/operations/execute', data: envelope)).data!;

  Future<Map<String, Object?>> walletPull(int since, String? scope) async => (await _dio.get<Map<String, Object?>>(
        '/api/v3/wallet/pull',
        queryParameters: {'since': since, 'scope': ?scope},
      ))
          .data!;

  Future<Map<String, Object?>> household() async => (await _dio.get<Map<String, Object?>>('/api/v3/household')).data!;

  Future<Map<String, Object?>> createHouseholdInvite() async =>
      (await _dio.post<Map<String, Object?>>('/api/v3/household/invites')).data!;

  Future<Map<String, Object?>> joinHousehold(String code) async =>
      (await _dio.post<Map<String, Object?>>('/api/v3/household/join', data: {'code': code})).data!;

  Future<Map<String, Object?>> leaveHousehold() async => (await _dio.post<Map<String, Object?>>('/api/v3/household/leave')).data!;

  Future<Map<String, Object?>> syncPush(List<Map<String, Object?>> changes) async =>
      (await _dio.post<Map<String, Object?>>('/api/v3/sync/push', data: {'changes': changes})).data!;

  Future<Map<String, Object?>> syncPull(int since) async =>
      (await _dio.get<Map<String, Object?>>('/api/v3/sync/pull', queryParameters: {'since': since})).data!;

  /// Server-side events and routines from before the calendar moved on-device.
  Future<List<Map<String, Object?>>> legacyEvents() async =>
      ((await _dio.get<List<Object?>>('/api/v1/events')).data ?? const []).cast<Map>().map(Map<String, Object?>.from).toList();

  Future<List<Map<String, Object?>>> legacyRoutines() async =>
      ((await _dio.get<List<Object?>>('/api/v1/recurring-events')).data ?? const []).cast<Map>().map(Map<String, Object?>.from).toList();

  Future<Map<String, Object?>> walletSummary() => _cachedMap(
        'finance-overview',
        () async => (await _dio.get<Map<String, Object?>>('/api/v2/finance/overview')).data!,
      );

  Future<List<Map<String, Object?>>> accounts() async =>
      (await _cachedList('finance-accounts', () async =>
              (await _dio.get<List<Object?>>('/api/v2/finance/accounts')).data ?? const []))
          .cast<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();

  Future<Map<String, Object?>> medicationDashboard() => _cachedMap(
        'health-dashboard',
        () async => (await _dio.get<Map<String, Object?>>('/api/v2/health/dashboard')).data!,
      );
}
