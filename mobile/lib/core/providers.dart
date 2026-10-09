import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'network/api_client.dart';
import 'platform/platform_bridge.dart';
import 'storage/app_database.dart';
import 'storage/credential_store.dart';
import 'sync/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final credentialStoreProvider = Provider((ref) => const CredentialStore());
final platformBridgeProvider = Provider((ref) => const PlatformBridge());

class ConnectionConfig {
  const ConnectionConfig({required this.serverUrl, required this.token});
  final String serverUrl;
  final String token;
}

final connectionProvider = StateProvider<ConnectionConfig?>((ref) => null);

final apiClientProvider = Provider<ApiClient?>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection == null) return null;
  return ApiClient(
    serverUrl: connection.serverUrl,
    token: connection.token,
    database: ref.watch(databaseProvider),
  );
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return SyncService(ref.watch(databaseProvider), api);
});

final outstandingOperationsProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchOutstandingCount(),
);
