import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/wallet/wallet_models.dart';
import 'package:lifebase_mobile/core/wallet/wallet_outbox.dart';
import 'package:lifebase_mobile/core/wallet/wallet_sync.dart';
import 'package:lifebase_mobile/modules/wallet/data/wallet_repository.dart';

/// A scripted server: answers each execute with [responses] (by operation
/// key and entity id) and serves [pages] on pull.
class FakeServer implements WalletTransport {
  final executed = <Map<String, Object?>>[];
  final Map<String, Object> failures = {};
  final pages = <Map<String, Object?>>[];
  final pulls = <(int, String?)>[];
  int version = 1;
  bool offline = false;

  @override
  Future<Map<String, Object?>> execute(Map<String, Object?> envelope) async {
    if (offline) throw const WalletTransportException(null);
    final id = envelope['id'] ?? envelope['account_id'] ?? (envelope['account'] as Map?)?['id'];
    final failure = failures[id];
    if (failure is WalletTransportException) throw failure;
    executed.add(envelope);
    return {
      'entities': [
        {'kind': 'x', 'id': id, 'version': ++version},
      ],
    };
  }

  @override
  Future<Map<String, Object?>> pull(int since, String? scope) async {
    if (offline) throw const WalletTransportException(null);
    pulls.add((since, scope));
    return pages.isEmpty ? {'scope': 'u:1', 'cursor': since, 'reset': false, 'has_more': false} : pages.removeAt(0);
  }
}

Map<String, Object?> account(String id, {String balance = '0.00', String type = 'bank', int version = 1, int? statementDay}) => {
      'id': id,
      'server_id': 1,
      'owner_id': 1,
      'name': id,
      'type': type,
      'balance': balance,
      'opening_balance': '0.00',
      'visibility': 'personal',
      'is_active': true,
      'version': version,
      'statement_day': ?statementDay,
    };

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('money', () {
    test('parses Turkish and plain input into kuruş', () {
      expect(parseCents('1.234,50'), 123450);
      expect(parseCents('1234.5'), 123450);
      expect(parseCents('₺ 12'), 1200);
      expect(parseCents('-0,05'), -5);
      expect(parseCents('abc'), isNull);
      expect(decimalOf(-123405), '-1234.05');
      expect(formatMoney(123450), '₺1.234,50');
    });

    test('splits like the server and finds the statement', () {
      expect(splitCents(100000, 3), [33334, 33333, 33333]);
      expect(splitCents(9999, 7).reduce((a, b) => a + b), 9999);
      expect(statementMonthOf(DateTime(2026, 10, 20), 15), DateTime(2026, 11));
      expect(statementMonthOf(DateTime(2026, 12, 15), 15), DateTime(2026, 12));
      expect(statementMonthOf(DateTime(2026, 12, 16), 15), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1, 31, 9), 1), DateTime(2026, 2, 28, 9));
    });
  });

  group('outbox overlay', () {
    WalletOp op(String key, Map<String, Object?> values, {OutboxState state = OutboxState.pending}) =>
        WalletOp(requestId: '$key$values', key: key, values: values, accountKeys: const [], createdAt: DateTime(2026), state: state);

    final confirmed = WalletData(accounts: {
      'bank': const WalletAccount(id: 'bank', ownerId: 1, name: 'Banka', type: AccountType.bank, balance: 100000, opening: 100000),
      'card': const WalletAccount(id: 'card', ownerId: 1, name: 'Kart', type: AccountType.creditCard, balance: 0, statementDay: 15, limit: 1000000),
    });

    test('new records show at once and balances become estimates', () {
      final view = applyOutbox(confirmed, [
        op('wallet.account.save', {'account': {'id': 'cash', 'name': 'Cüzdan', 'type': 'cash', 'opening_balance': '50.00'}}),
        op('wallet.transaction.save', {'id': 't1', 'account_id': 'cash', 'kind': 'expense', 'amount': '20.00', 'occurred_at': '2026-10-09T12:00:00+03:00', 'note': ' Simit '}),
      ], me: 7, categoryNames: {});

      expect(view.accounts['cash']!.balance, 3000);
      expect(view.accounts['cash']!.ownerId, 7);
      expect(view.accounts['cash']!.sync, SyncMark.pending);
      expect(view.transactions['t1']!.note, 'Simit');
      expect(view.transactions['t1']!.sync, SyncMark.pending);
      expect(view.accounts['bank']!.sync, SyncMark.confirmed);
    });

    test('installments, edits and deletes move the effect', () {
      final bought = applyOutbox(confirmed, [
        op('wallet.transaction.save', {'id': 'buy', 'account_id': 'card', 'kind': 'expense', 'amount': '1000.00', 'occurred_at': '2026-10-20T10:00:00+03:00', 'installments': 3}),
      ], me: 1);
      expect(bought.transactions.keys, unorderedEquals(['buy', 'buy~2', 'buy~3']));
      expect(bought.transactions['buy~3']!.statementMonth, DateTime(2027, 1));
      expect(bought.accounts['card']!.balance, -100000);

      final moved = applyOutbox(bought, [
        op('wallet.transaction.save', {'id': 'buy~2', 'account_id': 'bank', 'kind': 'expense', 'amount': '10.00', 'occurred_at': '2026-10-20T10:00:00+03:00'}),
      ], me: 1);
      expect(moved.transactions.keys, ['buy']);
      expect(moved.accounts['card']!.balance, 0);
      expect(moved.accounts['bank']!.balance, 99000);

      final gone = applyOutbox(moved, [op('wallet.transaction.delete', {'id': 'buy'})], me: 1);
      expect(gone.transactions, isEmpty);
      expect(gone.accounts['bank']!.balance, 100000);
    });

    test('transfers and conflict marks', () {
      final view = applyOutbox(confirmed, [
        op('wallet.transfer.save', {'id': 'p', 'from_account_id': 'bank', 'to_account_id': 'card', 'amount': '250.00', 'occurred_at': '2026-10-09T12:00:00+03:00'},
            state: OutboxState.conflict),
      ], me: 1);
      expect(view.accounts['bank']!.balance, 75000);
      expect(view.accounts['card']!.balance, 25000);
      expect(view.transfers['p']!.sync, SyncMark.conflict);
      expect(view.accounts['card']!.sync, SyncMark.conflict);
    });
  });

  group('sync engine', () {
    late AppDatabase db;
    late FakeServer server;
    late WalletRepository repo;
    late WalletSyncEngine engine;
    var now = DateTime(2026, 10, 9, 12);

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      server = FakeServer();
      repo = WalletRepository(db);
      now = DateTime(2026, 10, 9, 12);
      engine = WalletSyncEngine(database: db, transport: server, clock: () => now);
    });
    tearDown(() => db.close());

    Future<List<WalletOp>> outbox() async => [for (final r in await db.select(db.walletOutbox).get()) WalletOp.fromRow(r)];

    test('writes go in order; a conflict holds only its own account', () async {
      server.failures['a1'] = const WalletTransportException(409, {
        'detail': {'message': 'x', 'current': {'id': 'a1', 'version': 5}},
      });
      await repo.saveTransaction(id: 'a1', accountId: 'A', kind: TxKind.expense, amount: 100, occurredAt: now);
      await repo.saveTransaction(id: 'a2', accountId: 'A', kind: TxKind.expense, amount: 200, occurredAt: now);
      await repo.saveTransaction(id: 'b1', accountId: 'B', kind: TxKind.expense, amount: 300, occurredAt: now);

      expect(await engine.flush(), WalletSyncResult.synced);

      expect(server.executed.map((e) => e['id']), ['b1']);
      final states = {for (final op in await outbox()) op.entityId: op.state};
      expect(states, {'a1': OutboxState.conflict, 'a2': OutboxState.pending, 'b1': OutboxState.sent});
      final conflict = (await outbox()).firstWhere((op) => op.entityId == 'a1');
      expect(conflict.serverRecord, {'id': 'a1', 'version': 5});

      // "Seninki": resend over the server's version.
      server.failures.clear();
      await repo.keepMine(conflict);
      await engine.flush();
      expect(server.executed.map((e) => e['id']), ['b1', 'a1', 'a2']);
      expect(server.executed[1]['expected_version'], 5);
    });

    test('offline stops the run and backs off; 5xx holds the account', () async {
      await repo.saveTransaction(id: 't', accountId: 'A', kind: TxKind.expense, amount: 100, occurredAt: now);
      server.offline = true;
      expect(await engine.run(), WalletSyncResult.offline);
      final waiting = (await outbox()).single;
      expect(waiting.attempts, 1);
      expect(waiting.nextAttemptAt, now.add(const Duration(seconds: 5)));

      server.offline = false;
      await engine.flush();
      expect(server.executed, isEmpty, reason: 'still waiting out the delay');
      now = now.add(const Duration(seconds: 6));
      await engine.flush();
      expect(server.executed, hasLength(1));
      expect(backoff(4), const Duration(seconds: 40));
      expect(backoff(30), const Duration(minutes: 30));
    });

    test('a second edit of the same record uses the version the first produced', () async {
      final tx = WalletTransaction(id: 't', accountId: 'A', kind: TxKind.expense, amount: 100, occurredAt: now, createdBy: 1, version: 3);
      await repo.saveTransaction(id: 't', accountId: 'A', kind: TxKind.expense, amount: 150, occurredAt: now, previous: tx);
      await repo.saveTransaction(id: 't', accountId: 'A', kind: TxKind.expense, amount: 175, occurredAt: now, previous: tx);
      await engine.flush();
      expect(server.executed.map((e) => e['expected_version']), [3, server.version - 1]);
    });

    test('sent writes leave only with the pull that includes them', () async {
      await repo.saveTransaction(id: 't', accountId: 'bank', kind: TxKind.expense, amount: 2500, occurredAt: now);
      await engine.flush();
      expect((await outbox()).single.state, OutboxState.sent);

      server.pages.add({
        'scope': 'u:1',
        'cursor': 4,
        'reset': true,
        'has_more': false,
        'members': [{'user_id': 1, 'name': 'Ali', 'is_me': true}],
        'categories': [{'id': 3, 'name': 'Market', 'kind': 'expense'}],
        'accounts': [account('bank', balance: '975.00')],
        'transactions': [
          {'id': 't', 'account_id': 'bank', 'kind': 'expense', 'amount': '25.00', 'occurred_at': '2026-10-09T09:00:00+00:00', 'created_by': 1, 'version': 1},
        ],
      });
      expect(await engine.pull(), WalletSyncResult.synced);

      expect(await outbox(), isEmpty);
      expect((await db.select(db.walletAccounts).getSingle()).balanceCents, 97500);
      expect(await db.syncState('wallet.cursor'), '4');
      expect(jsonDecode((await db.syncState('wallet.members'))!), hasLength(1));

      // Next pull asks since the cursor, in the same scope.
      await engine.pull();
      expect(server.pulls.last, (4, 'u:1'));
    });

    test('a hidden account takes its records with it; a reset replaces everything', () async {
      server.pages
        ..add({
          'scope': 'h:1', 'cursor': 2, 'reset': true, 'has_more': false,
          'accounts': [account('joint', type: 'credit_card'), account('own')],
          'transactions': [
            {'id': 'x', 'account_id': 'joint', 'kind': 'expense', 'amount': '5.00', 'occurred_at': '2026-10-09T09:00:00Z', 'created_by': 2},
          ],
          'transfers': [
            {'id': 'p', 'from_account_id': 'own', 'to_account_id': 'joint', 'amount': '5.00', 'occurred_at': '2026-10-09T09:00:00Z', 'created_by': 1},
          ],
        })
        ..add({
          'scope': 'h:1', 'cursor': 3, 'reset': false, 'has_more': false,
          'deleted': [{'kind': 'account', 'id': 'joint'}],
        })
        ..add({'scope': 'u:1', 'cursor': 1, 'reset': true, 'has_more': false, 'accounts': [account('own')]});

      await engine.pull();
      await engine.pull();
      expect((await db.select(db.walletAccounts).get()).map((a) => a.id), ['own']);
      expect(await db.select(db.walletTransactions).get(), isEmpty);
      expect(await db.select(db.walletTransfers).get(), hasLength(1), reason: 'its other side is still here');

      await engine.pull();
      expect(await db.select(db.walletTransfers).get(), isEmpty);
      expect(await db.syncState('wallet.scope'), 'u:1');
    });
  });
}
