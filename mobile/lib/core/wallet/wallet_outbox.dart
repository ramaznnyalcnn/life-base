import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/app_database.dart';
import 'wallet_models.dart';

enum OutboxState { pending, sent, conflict, failed }

/// One queued wallet write (operation envelope + bookkeeping).
@immutable
class WalletOp {
  const WalletOp({
    required this.requestId,
    required this.key,
    required this.values,
    required this.accountKeys,
    required this.createdAt,
    this.state = OutboxState.pending,
    this.attempts = 0,
    this.nextAttemptAt,
    this.detail,
  });

  factory WalletOp.fromRow(WalletOutboxRow row) {
    final envelope = Map<String, Object?>.from(jsonDecode(row.payload) as Map);
    return WalletOp(
      requestId: row.requestId,
      key: row.operationKey,
      values: Map<String, Object?>.from(envelope)
        ..remove('request_id')
        ..remove('operation_key'),
      accountKeys: row.accountKeys.split(',').where((k) => k.isNotEmpty).toList(),
      state: OutboxState.values.asNameMap()[row.state] ?? OutboxState.pending,
      attempts: row.attempts,
      nextAttemptAt: row.nextAttemptAt,
      detail: row.detail,
      createdAt: row.createdAt,
    );
  }

  final String requestId;
  final String key;
  final Map<String, Object?> values;
  final List<String> accountKeys;
  final OutboxState state;
  final int attempts;
  final DateTime? nextAttemptAt;

  /// conflict: the server's current record (JSON); failed: the error text;
  /// sent: the version the server returned.
  final String? detail;
  final DateTime createdAt;

  Map<String, Object?> get envelope => {'request_id': requestId, 'operation_key': key, ...values};

  /// The record this write is about (for chaining versions and conflicts).
  String? get entityId => switch (key) {
        'wallet.account.save' => (values['account'] as Map?)?['id'] as String?,
        'wallet.account.archive' => values['account_id'] as String?,
        'wallet.statement.mark' => values['account_id'] as String?,
        _ => values['id'] as String?,
      };

  /// The server's record at the time of a 409.
  Map<String, Object?>? get serverRecord {
    if (state != OutboxState.conflict || detail == null) return null;
    final decoded = jsonDecode(detail!);
    if (decoded is! Map) return null;
    final current = decoded['detail'] is Map ? (decoded['detail'] as Map)['current'] : decoded['current'];
    return current is Map ? Map<String, Object?>.from(current) : null;
  }

  SyncMark get mark => switch (state) {
        OutboxState.conflict => SyncMark.conflict,
        OutboxState.failed => SyncMark.failed,
        _ => SyncMark.pending,
      };
}

/// The confirmed wallet as last pulled.
@immutable
class WalletData {
  const WalletData({
    this.accounts = const {},
    this.transactions = const {},
    this.transfers = const {},
    this.marks = const {},
    this.payments = const {},
  });

  final Map<String, WalletAccount> accounts;
  final Map<String, WalletTransaction> transactions;
  final Map<String, WalletTransfer> transfers;
  final Map<String, StatementMark> marks;
  final Map<String, ScheduledPayment> payments;
}

/// The wallet as the user should see it: the confirmed state with every
/// queued write applied on top (marked pending, conflict or failed), so
/// balances are estimates until the server confirms.
WalletData applyOutbox(WalletData confirmed, Iterable<WalletOp> ops, {required int me, Map<int, String> categoryNames = const {}}) {
  final accounts = Map.of(confirmed.accounts);
  final transactions = Map.of(confirmed.transactions);
  final transfers = Map.of(confirmed.transfers);
  final marks = Map.of(confirmed.marks);
  final payments = Map.of(confirmed.payments);

  void move(String accountId, Cents delta, SyncMark mark) {
    final account = accounts[accountId];
    if (account == null || delta == 0) return;
    accounts[accountId] = account.copyWith(balance: account.balance + delta, sync: _worse(account.sync, mark));
  }

  List<WalletTransaction> group(WalletTransaction tx) =>
      transactions.values.where((t) => t.groupId == tx.groupId).toList();

  for (final op in ops) {
    final mark = op.mark;
    final v = op.values;
    switch (op.key) {
      case 'wallet.account.save':
        final a = Map<String, Object?>.from(v['account']! as Map);
        final id = a['id']! as String;
        final existing = accounts[id];
        final opening = centsOf(a['opening_balance']);
        final type = AccountType.of(a['type']! as String);
        final isCard = type == AccountType.creditCard;
        accounts[id] = WalletAccount(
          id: id,
          serverId: existing?.serverId,
          ownerId: existing?.ownerId ?? me,
          name: a['name']! as String,
          type: existing?.type ?? type,
          bank: a['bank'] as String?,
          balance: existing == null ? opening : existing.balance + opening - existing.opening,
          opening: opening,
          limit: isCard && a['credit_limit'] != null ? centsOf(a['credit_limit']) : null,
          statementDay: isCard ? a['statement_day'] as int? : null,
          dueDay: isCard ? a['due_day'] as int? : null,
          shared: a['visibility'] == 'shared',
          last4: isCard ? a['last4'] as String? : null,
          network: isCard ? a['network'] as String? : null,
          color: a['color'] as String?,
          iban: type == AccountType.bank ? a['iban'] as String? : null,
          active: existing?.active ?? true,
          version: existing?.version ?? 1,
          sync: mark,
        );
      case 'wallet.account.archive':
        final id = v['account_id']! as String;
        final existing = accounts[id];
        if (existing != null) accounts[id] = existing.copyWith(active: v['archived'] != true, sync: mark);
      case 'wallet.transaction.save':
        final id = v['id']! as String;
        final existing = transactions[id];
        final old = existing == null ? const <WalletTransaction>[] : group(existing);
        final root = existing?.groupId ?? id;
        for (final part in old) {
          move(part.accountId, -part.kind.effect(part.amount), mark);
          transactions.remove(part.id);
        }
        final account = accounts[v['account_id']! as String];
        if (account == null) break;
        final kind = TxKind.of(v['kind']! as String);
        final count = (v['installments'] as int?) ?? 1;
        final occurredAt = DateTime.parse(v['occurred_at']! as String).toLocal();
        final categoryId = v['category_id'] as int?;
        final parts = splitCents(centsOf(v['amount']), count);
        for (var i = 1; i <= count; i++) {
          final at = addMonths(occurredAt, i - 1);
          final partKey = partId(root, i);
          transactions[partKey] = WalletTransaction(
            id: partKey,
            accountId: account.id,
            kind: kind,
            categoryId: categoryId,
            category: categoryNames[categoryId] ?? (categoryId == null ? kind.label : existing?.category),
            amount: parts[i - 1],
            occurredAt: at,
            statementMonth: account.isCard && account.statementDay != null ? statementMonthOf(at, account.statementDay!) : null,
            note: (v['note'] as String?)?.trim().isEmpty ?? true ? null : (v['note'] as String).trim(),
            createdBy: existing?.createdBy ?? me,
            installmentGroup: count > 1 ? root : null,
            installmentIndex: count > 1 ? i : null,
            installmentCount: count > 1 ? count : null,
            version: existing?.version ?? 1,
            sync: mark,
          );
          move(account.id, kind.effect(parts[i - 1]), mark);
        }
      case 'wallet.transaction.delete':
        final existing = transactions[v['id']! as String];
        if (existing == null) break;
        for (final part in group(existing)) {
          move(part.accountId, -part.kind.effect(part.amount), mark);
          transactions.remove(part.id);
        }
      case 'wallet.transfer.save':
        final id = v['id']! as String;
        final existing = transfers[id];
        if (existing != null) {
          move(existing.fromAccountId, existing.amount, mark);
          move(existing.toAccountId, -existing.amount, mark);
        }
        final amount = centsOf(v['amount']);
        final transfer = WalletTransfer(
          id: id,
          fromAccountId: v['from_account_id']! as String,
          toAccountId: v['to_account_id']! as String,
          amount: amount,
          occurredAt: DateTime.parse(v['occurred_at']! as String).toLocal(),
          note: v['note'] as String?,
          createdBy: existing?.createdBy ?? me,
          version: existing?.version ?? 1,
          sync: mark,
        );
        transfers[id] = transfer;
        move(transfer.fromAccountId, -amount, mark);
        move(transfer.toAccountId, amount, mark);
      case 'wallet.transfer.delete':
        final existing = transfers.remove(v['id']! as String);
        if (existing != null) {
          move(existing.fromAccountId, existing.amount, mark);
          move(existing.toAccountId, -existing.amount, mark);
        }
      case 'wallet.statement.mark':
        final month = DateTime.parse(v['month']! as String);
        final key = markId(v['account_id']! as String, DateTime(month.year, month.month));
        if (v['paid'] == null) {
          marks.remove(key);
        } else {
          marks[key] = StatementMark(accountId: v['account_id']! as String, month: DateTime(month.year, month.month), paid: v['paid'] == true, sync: mark);
        }
      case 'wallet.payment.save':
        final id = v['id']! as String;
        final existing = payments[id];
        payments[id] = ScheduledPayment(
          id: id,
          title: v['title']! as String,
          accountId: v['account_id']! as String,
          toAccountId: v['kind'] == 'transfer' ? v['to_account_id'] as String? : null,
          categoryId: v['kind'] == 'expense' ? v['category_id'] as int? : null,
          amount: centsOf(v['amount']),
          dueAt: DateTime.parse(v['due_at']! as String).toLocal(),
          repeatMonthly: v['repeat_monthly'] == true,
          completed: existing?.completed ?? false,
          lastPaidAt: existing?.lastPaidAt,
          createdBy: existing?.createdBy ?? me,
          version: existing?.version ?? 1,
          sync: mark,
        );
      case 'wallet.payment.delete':
        payments.remove(v['id']! as String);
      case 'wallet.payment.complete':
        final payment = payments[v['id']! as String];
        if (payment == null || payment.completed) break;
        final at = DateTime.parse(v['paid_at']! as String).toLocal();
        final entryId = v['entry_id']! as String;
        if (payment.isTransfer) {
          transfers[entryId] = WalletTransfer(
            id: entryId,
            fromAccountId: payment.accountId,
            toAccountId: payment.toAccountId!,
            amount: payment.amount,
            occurredAt: at,
            note: payment.title,
            createdBy: me,
            sync: mark,
          );
          move(payment.accountId, -payment.amount, mark);
          move(payment.toAccountId!, payment.amount, mark);
        } else {
          final account = accounts[payment.accountId];
          transactions[entryId] = WalletTransaction(
            id: entryId,
            accountId: payment.accountId,
            kind: TxKind.expense,
            categoryId: payment.categoryId,
            category: categoryNames[payment.categoryId] ?? TxKind.expense.label,
            amount: payment.amount,
            occurredAt: at,
            statementMonth: account != null && account.isCard && account.statementDay != null
                ? statementMonthOf(at, account.statementDay!)
                : null,
            note: payment.title,
            createdBy: me,
            sync: mark,
          );
          move(payment.accountId, -payment.amount, mark);
        }
        payments[payment.id] = payment.paid(at).copyWith(sync: mark);
    }
  }
  return WalletData(accounts: accounts, transactions: transactions, transfers: transfers, marks: marks, payments: payments);
}

SyncMark _worse(SyncMark a, SyncMark b) => a.index >= b.index ? a : b;
