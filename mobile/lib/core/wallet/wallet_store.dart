import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../providers.dart';
import '../storage/app_database.dart';
import 'wallet_models.dart';
import 'wallet_outbox.dart';
import 'wallet_sync.dart';

class ApiWalletTransport implements WalletTransport {
  const ApiWalletTransport(this._api);
  final ApiClient _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw WalletTransportException(error.response?.statusCode, error.response?.data);
    }
  }

  @override
  Future<Map<String, Object?>> execute(Map<String, Object?> envelope) => _call(() => _api.executeEnvelope(envelope));

  @override
  Future<Map<String, Object?>> pull(int since, String? scope) => _call(() => _api.walletPull(since, scope));
}

final walletSyncEngineProvider = Provider<WalletSyncEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return WalletSyncEngine(database: ref.watch(databaseProvider), transport: ApiWalletTransport(api));
});

Stream<String?> _syncState(AppDatabase db, String key) =>
    (db.select(db.syncStates)..where((t) => t.key.equals(key))).watchSingleOrNull().map((row) => row?.value);

final walletMembersProvider = StreamProvider<List<HouseholdMember>>((ref) {
  final db = ref.watch(databaseProvider);
  return _syncState(db, membersKey).map((raw) => [
        for (final m in (jsonDecode(raw ?? '[]') as List).cast<Map>())
          HouseholdMember(userId: m['user_id'] as int, name: m['name'] as String? ?? '', isMe: m['is_me'] == true),
      ]);
});

final walletCategoriesProvider = StreamProvider<List<WalletCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  return _syncState(db, categoriesKey).map((raw) => [
        for (final c in (jsonDecode(raw ?? '[]') as List).cast<Map>())
          WalletCategory(id: c['id'] as int, name: c['name'] as String, kind: TxKind.of(c['kind'] as String)),
      ]);
});

/// This user's id (0 until the first pull names the household members).
final walletMeProvider = Provider<int>((ref) =>
    ref.watch(walletMembersProvider).value?.where((m) => m.isMe).firstOrNull?.userId ?? 0);

final walletOutboxProvider = StreamProvider<List<WalletOp>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.walletOutbox)..orderBy([(t) => OrderingTerm.asc(t.seq)]))
      .watch()
      .map((rows) => rows.map(WalletOp.fromRow).toList());
});

final confirmedWalletProvider = StreamProvider<WalletData>((ref) {
  final db = ref.watch(databaseProvider);
  final controller = StreamController<WalletData>();
  var accounts = <String, WalletAccount>{};
  var transactions = <String, WalletTransaction>{};
  var transfers = <String, WalletTransfer>{};
  var marks = <String, StatementMark>{};
  var ready = 0;
  void emit() {
    if (ready == 0xF) {
      controller.add(WalletData(accounts: accounts, transactions: transactions, transfers: transfers, marks: marks));
    }
  }

  final subscriptions = [
    db.select(db.walletAccounts).watch().listen((rows) {
      accounts = {for (final r in rows) r.id: WalletAccount.fromRow(r)};
      ready |= 1;
      emit();
    }),
    db.select(db.walletTransactions).watch().listen((rows) {
      transactions = {for (final r in rows) r.id: WalletTransaction.fromRow(r)};
      ready |= 2;
      emit();
    }),
    db.select(db.walletTransfers).watch().listen((rows) {
      transfers = {for (final r in rows) r.id: WalletTransfer.fromRow(r)};
      ready |= 4;
      emit();
    }),
    db.select(db.walletStatementMarks).watch().listen((rows) {
      marks = {for (final r in rows) r.id: StatementMark.fromRow(r)};
      ready |= 8;
      emit();
    }),
  ];
  ref.onDispose(() async {
    for (final s in subscriptions) {
      await s.cancel();
    }
    await controller.close();
  });
  return controller.stream;
});

/// The wallet as shown: confirmed data with queued writes applied on top.
final walletProvider = Provider<AsyncValue<WalletData>>((ref) {
  final confirmed = ref.watch(confirmedWalletProvider);
  final outbox = ref.watch(walletOutboxProvider);
  final categories = ref.watch(walletCategoriesProvider).value ?? const [];
  if (confirmed.hasError) return AsyncValue.error(confirmed.error!, confirmed.stackTrace!);
  if (!confirmed.hasValue || !outbox.hasValue) return const AsyncValue.loading();
  return AsyncValue.data(applyOutbox(
    confirmed.value!,
    outbox.value!,
    me: ref.watch(walletMeProvider),
    categoryNames: {for (final c in categories) c.id: c.name},
  ));
});
