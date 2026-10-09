import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) => WalletRepository(
      ref.watch(databaseProvider),
      onChanged: () => ref.read(syncControllerProvider.notifier).requestSync(delay: const Duration(milliseconds: 300)),
    ));

/// Account fields as edited in the app.
class AccountDraft {
  const AccountDraft({
    required this.id,
    required this.name,
    required this.type,
    this.bank,
    this.shared = false,
    this.opening = 0,
    this.limit,
    this.statementDay,
    this.dueDay,
    this.last4,
    this.network,
    this.color,
    this.iban,
  });

  final String id;
  final String name;
  final AccountType type;
  final String? bank;
  final bool shared;
  final Cents opening;
  final Cents? limit;
  final int? statementDay;
  final int? dueDay;
  final String? last4;
  final String? network;
  final String? color;
  final String? iban;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name.trim(),
        'type': type.wire,
        'bank': ?bank,
        'visibility': shared ? 'shared' : 'personal',
        'opening_balance': decimalOf(opening),
        if (limit != null) 'credit_limit': decimalOf(limit!),
        'statement_day': ?statementDay,
        'due_day': ?dueDay,
        'last4': ?last4,
        'network': ?network,
        'color': ?color,
        'iban': ?iban,
      };
}

/// Wallet writes. Each goes to the outbox first (shown at once, marked
/// pending) and is sent by the sync engine; nothing here needs the network.
class WalletRepository {
  WalletRepository(this._db, {void Function()? onChanged}) : _onChanged = onChanged ?? (() {});

  final AppDatabase _db;
  final void Function() _onChanged;

  String newId() => const Uuid().v4();

  static String _time(DateTime at) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(at) + _offset(at);

  static String _offset(DateTime at) {
    final offset = at.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return '$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _enqueue(String key, Map<String, Object?> values, Iterable<String?> accounts) async {
    final requestId = newId();
    await _db.transaction(() async {
      final last = await (_db.selectOnly(_db.walletOutbox)..addColumns([_db.walletOutbox.seq.max()]))
          .map((row) => row.read(_db.walletOutbox.seq.max()))
          .getSingle();
      await _db.into(_db.walletOutbox).insert(WalletOutboxCompanion.insert(
            requestId: requestId,
            seq: (last ?? 0) + 1,
            operationKey: key,
            payload: jsonEncode({'request_id': requestId, 'operation_key': key, ...values}),
            accountKeys: {...accounts.whereType<String>()}.join(','),
            createdAt: DateTime.now(),
          ));
    });
    _onChanged();
  }

  Future<void> saveAccount(AccountDraft draft, {int? expectedVersion}) => _enqueue(
        'wallet.account.save',
        {'account': draft.toJson(), 'expected_version': expectedVersion},
        [draft.id],
      );

  Future<void> archiveAccount(WalletAccount account, {required bool archived}) => _enqueue(
        'wallet.account.archive',
        {'account_id': account.id, 'archived': archived, 'expected_version': account.version},
        [account.id],
      );

  /// Create ([previous] null) or edit an expense/income. Installments split
  /// it over the coming card statements.
  Future<void> saveTransaction({
    required String id,
    required String accountId,
    required TxKind kind,
    required Cents amount,
    required DateTime occurredAt,
    int? categoryId,
    String? note,
    int installments = 1,
    WalletTransaction? previous,
  }) =>
      _enqueue(
        'wallet.transaction.save',
        {
          'id': previous?.groupId ?? id,
          'account_id': accountId,
          'kind': kind.wire,
          'category_id': categoryId,
          'amount': decimalOf(amount),
          'occurred_at': _time(occurredAt),
          'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
          'installments': installments,
          'expected_version': previous?.version,
        },
        [accountId, previous?.accountId],
      );

  Future<void> deleteTransaction(WalletTransaction tx) => _enqueue(
        'wallet.transaction.delete',
        {'id': tx.groupId, 'expected_version': tx.version},
        [tx.accountId],
      );

  Future<void> saveTransfer({
    required String id,
    required String fromAccountId,
    required String toAccountId,
    required Cents amount,
    required DateTime occurredAt,
    String? note,
    WalletTransfer? previous,
  }) =>
      _enqueue(
        'wallet.transfer.save',
        {
          'id': id,
          'from_account_id': fromAccountId,
          'to_account_id': toAccountId,
          'amount': decimalOf(amount),
          'occurred_at': _time(occurredAt),
          'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
          'expected_version': previous?.version,
        },
        [fromAccountId, toAccountId, previous?.fromAccountId, previous?.toAccountId],
      );

  Future<void> deleteTransfer(WalletTransfer transfer) => _enqueue(
        'wallet.transfer.delete',
        {'id': transfer.id, 'expected_version': transfer.version},
        [transfer.fromAccountId, transfer.toAccountId],
      );

  /// [paid] null returns the statement to the automatic rule.
  Future<void> markStatement(String accountId, DateTime month, bool? paid) => _enqueue(
        'wallet.statement.mark',
        {'account_id': accountId, 'month': DateFormat('yyyy-MM-01').format(month), 'paid': paid},
        [accountId],
      );

  // Conflicts ---------------------------------------------------------------

  /// "Sunucudaki": drop this device's write.
  Future<void> discard(WalletOp op) async {
    await (_db.delete(_db.walletOutbox)..where((t) => t.requestId.equals(op.requestId))).go();
    _onChanged();
  }

  /// "Seninki": send this device's write again over the server's version.
  Future<void> keepMine(WalletOp op) async {
    final version = op.serverRecord?['version'];
    final envelope = op.envelope;
    if (version is int) envelope['expected_version'] = version;
    await (_db.update(_db.walletOutbox)..where((t) => t.requestId.equals(op.requestId))).write(WalletOutboxCompanion(
      payload: Value(jsonEncode(envelope)),
      state: const Value('pending'),
      detail: const Value(null),
      nextAttemptAt: const Value(null),
    ));
    _onChanged();
  }
}
