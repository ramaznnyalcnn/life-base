import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/server_address.dart';
import '../../../core/providers.dart';
import '../../../core/wallet/card_secrets.dart';

/// What the user typed to sign in: an email, or a username the server maps
/// to one.
String loginIdentifier(String input) => input.trim().toLowerCase();

class SessionState {
  const SessionState._({this.ready = false, this.displayName, this.error});

  const SessionState.signedOut() : this._();
  const SessionState.signedIn(String displayName)
      : this._(ready: true, displayName: displayName);
  const SessionState.failure(String error) : this._(error: error);

  final bool ready;
  final String? displayName;
  final String? error;
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final store = ref.read(credentialStoreProvider);
    final serverUrl = await store.readServerUrl();
    final token = await store.readToken();
    final displayName = await store.readDisplayName() ?? 'LifeBase';
    if (serverUrl == null || token == null) return const SessionState.signedOut();
    late final String normalized;
    try {
      normalized = normalizeServerAddress(serverUrl);
    } on FormatException {
      await store.clearToken();
      await ref.read(platformBridgeProvider).clearSession();
      return const SessionState.signedOut();
    }
    try {
      final dio = Dio(BaseOptions(
        baseUrl: normalized,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 6),
      ));
      final response = await dio.get<Map<String, Object?>>('/api/v1/auth/me');
      ref.read(connectionProvider.notifier).state =
          ConnectionConfig(serverUrl: normalized, token: token);
      return SessionState.signedIn(
        response.data?['display_name'] as String? ?? 'LifeBase',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode case 401 || 403) {
        await store.clearToken();
        await ref.read(platformBridgeProvider).clearSession();
        return const SessionState.signedOut();
      }
      ref.read(connectionProvider.notifier).state =
          ConnectionConfig(serverUrl: normalized, token: token);
      return SessionState.signedIn(displayName);
    }
  }

  Future<void> login({
    required String serverUrl,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalized = normalizeServerAddress(serverUrl);
      final dio = Dio(BaseOptions(baseUrl: normalized));
      final response = await dio.post<Map<String, Object?>>(
        '/api/v1/auth/login',
        data: {'email': loginIdentifier(email), 'password': password},
      );
      final body = response.data!;
      final token = body['access_token']! as String;
      final user = Map<String, Object?>.from(body['user']! as Map);
      final displayName = user['display_name'] as String? ?? 'LifeBase';
      await ref.read(credentialStoreProvider).saveSession(
            serverUrl: normalized,
            token: token,
            displayName: displayName,
          );
      await ref.read(platformBridgeProvider).saveSyncConfig(
            serverUrl: normalized,
            token: token,
          );
      await ref.read(platformBridgeProvider).requestOnboardingPermissions();
      ref.read(connectionProvider.notifier).state =
          ConnectionConfig(serverUrl: normalized, token: token);
      await ref.read(databaseProvider).resumePaused();
      await ref.read(platformBridgeProvider).scheduleSync();
      await ref.read(syncServiceProvider)?.flush();
      return SessionState.signedIn(displayName);
    });
  }

  Future<void> logout() async {
    await ref.read(credentialStoreProvider).clearToken();
    await ref.read(platformBridgeProvider).clearSession();
    await ref.read(databaseProvider).clearCache();
    // Local-first data belongs to this account; the server keeps the backup.
    await ref.read(databaseProvider).clearLocalData();
    // Card details have no backup anywhere: they go with the account.
    await ref.read(cardSecretsStoreProvider).clear().catchError((Object _) {});
    ref.read(connectionProvider.notifier).state = null;
    state = const AsyncData(SessionState.signedOut());
  }
}
