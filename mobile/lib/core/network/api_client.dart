import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../models/agenda.dart';
import '../models/catalog.dart';
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

  Future<(List<OperationDefinition>, OperationContextData)> operationSetup() async {
    final body = await _cachedMap('operation-setup', () async {
      final responses = await Future.wait([
        _dio.get<List<Object?>>('/api/v2/operations/catalog'),
        _dio.get<Map<String, Object?>>('/api/v2/operations/context'),
      ]);
      return {'catalog': responses[0].data!, 'context': responses[1].data!};
    });
    final definitions = (body['catalog'] as List)
        .cast<Map>()
        .map((item) => OperationDefinition.fromJson(Map<String, Object?>.from(item)))
        .toList();
    final context = OperationContextData.fromJson(
      Map<String, Object?>.from(body['context']! as Map),
    );
    return (definitions, context);
  }

  Future<Map<String, Object?>> execute(OperationEnvelope operation) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/v2/operations/execute',
      data: operation.toApiJson(),
    );
    return response.data!;
  }

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
