import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../storage/app_database.dart';
import 'wallet_models.dart';
import 'wallet_outbox.dart';

/// A failed request: [statusCode] is null when the server was not reached.
class WalletTransportException implements Exception {
  const WalletTransportException(this.statusCode, [this.body]);
  final int? statusCode;
  final Object? body;

  @override
  String toString() => 'WalletTransportException($statusCode, $body)';
}

abstract interface class WalletTransport {
  Future<Map<String, Object?>> execute(Map<String, Object?> envelope);
  Future<Map<String, Object?>> pull(int since, String? scope);
}

enum WalletSyncResult { synced, offline, unauthorized, failed }

const _cursorKey = 'wallet.cursor';
const _scopeKey = 'wallet.scope';
const membersKey = 'wallet.members';
const categoriesKey = 'wallet.categories';

/// Retry delay after [attempts] failures: 5 s, 10 s, 20 s … capped at 30 min.
Duration backoff(int attempts) => Duration(seconds: min(5 * pow(2, max(0, attempts - 1)).toInt(), 30 * 60));

/// Sends queued wallet writes, then pulls what changed.
///
/// Writes go oldest first, but only writes on the same account wait for each
/// other: a conflict, a failure or a retry delay on one account holds that
/// account's later writes and lets the others through. A write the server
/// accepted stays in the outbox as `sent` until the pull that includes it is
/// stored, and both happen in one database transaction, so its effect is
/// never counted twice or not at all.
class WalletSyncEngine {
  WalletSyncEngine({required this.database, required this.transport, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final WalletTransport transport;
  final DateTime Function() _clock;

  Future<WalletSyncResult> run() async {
    final pushed = await flush();
    if (pushed != WalletSyncResult.synced) return pushed;
    return pull();
  }

  Future<List<WalletOp>> _outbox() async => [
        for (final row in await (database.select(database.walletOutbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get())
          WalletOp.fromRow(row),
      ];

  Future<WalletSyncResult> flush() async {
    final now = _clock();
    final ops = await _outbox();
    final held = <String>{};
    // Versions the server returned for records this device just wrote.
    final versions = <String, int>{
      for (final op in ops)
        if (op.state == OutboxState.sent && op.entityId != null && int.tryParse(op.detail ?? '') != null)
          op.entityId!: int.parse(op.detail!),
    };
    for (final op in ops) {
      if (op.state == OutboxState.sent) continue;
      final waiting = op.accountKeys.any(held.contains) ||
          op.state == OutboxState.conflict ||
          op.state == OutboxState.failed ||
          (op.nextAttemptAt != null && op.nextAttemptAt!.isAfter(now));
      if (waiting) {
        held.addAll(op.accountKeys);
        continue;
      }
      final envelope = op.envelope;
      final chained = op.entityId == null ? null : versions[op.entityId];
      if (chained != null && envelope.containsKey('expected_version')) envelope['expected_version'] = chained;
      try {
        final result = await transport.execute(envelope);
        final returned = _returnedVersion(result, op.entityId);
        if (returned != null) versions[op.entityId!] = returned;
        await _update(op, state: OutboxState.sent, detail: returned?.toString());
      } on WalletTransportException catch (error) {
        final status = error.statusCode;
        if (status == null) {
          await _retryLater(op, now);
          return WalletSyncResult.offline;
        }
        if (status == 401) return WalletSyncResult.unauthorized;
        held.addAll(op.accountKeys);
        if (status >= 500) {
          await _retryLater(op, now);
        } else if (status == 409 && _hasCurrent(error.body)) {
          await _update(op, state: OutboxState.conflict, detail: jsonEncode(error.body));
        } else {
          await _update(op, state: OutboxState.failed, detail: _message(error.body));
        }
      }
    }
    return WalletSyncResult.synced;
  }

  Future<WalletSyncResult> pull() async {
    final outbox = await _outbox();
    final sentBefore = [for (final op in outbox) if (op.state == OutboxState.sent) op.requestId];
    var since = int.tryParse(await database.syncState(_cursorKey) ?? '') ?? 0;
    var scope = await database.syncState(_scopeKey);
    try {
      while (true) {
        final page = await transport.pull(since, scope);
        final hasMore = page['has_more'] == true;
        await database.transaction(() async {
          await _store(page);
          if (!hasMore) await _settleSent(outbox, sentBefore);
        });
        since = page['cursor']! as int;
        scope = page['scope'] as String?;
        if (!hasMore) return WalletSyncResult.synced;
      }
    } on WalletTransportException catch (error) {
      return switch (error.statusCode) {
        null => WalletSyncResult.offline,
        401 => WalletSyncResult.unauthorized,
        _ => WalletSyncResult.failed,
      };
    }
  }

  Future<void> _store(Map<String, Object?> page) async {
    final db = database;
    if (page['reset'] == true) {
      await db.delete(db.walletAccounts).go();
      await db.delete(db.walletTransactions).go();
      await db.delete(db.walletTransfers).go();
      await db.delete(db.walletStatementMarks).go();
      await db.delete(db.walletScheduledPayments).go();
    }
    for (final a in _list(page['accounts'])) {
      await db.into(db.walletAccounts).insertOnConflictUpdate(WalletAccountsCompanion.insert(
            id: a['id']! as String,
            serverId: Value(a['server_id'] as int?),
            ownerId: a['owner_id']! as int,
            name: a['name']! as String,
            type: a['type']! as String,
            bank: Value(a['bank'] as String?),
            currency: Value(a['currency'] as String? ?? 'TRY'),
            balanceCents: centsOf(a['balance']),
            openingCents: Value(centsOf(a['opening_balance'])),
            limitCents: Value(a['credit_limit'] == null ? null : centsOf(a['credit_limit'])),
            statementDay: Value(a['statement_day'] as int?),
            dueDay: Value(a['due_day'] as int?),
            visibility: Value(a['visibility'] as String? ?? 'personal'),
            last4: Value(a['last4'] as String?),
            network: Value(a['network'] as String?),
            color: Value(a['color'] as String?),
            iban: Value(a['iban'] as String?),
            active: Value(a['is_active'] != false),
            version: Value(a['version'] as int? ?? 1),
          ));
    }
    for (final t in _list(page['transactions'])) {
      await db.into(db.walletTransactions).insertOnConflictUpdate(WalletTransactionsCompanion.insert(
            id: t['id']! as String,
            accountId: t['account_id']! as String,
            kind: t['kind']! as String,
            categoryId: Value(t['category_id'] as int?),
            category: Value(t['category'] as String?),
            amountCents: centsOf(t['amount']),
            occurredAt: DateTime.parse(t['occurred_at']! as String).toUtc(),
            statementMonth: Value(t['statement_month'] == null ? null : storedMonth(DateTime.parse(t['statement_month']! as String))),
            note: Value(t['note'] as String?),
            createdBy: t['created_by']! as int,
            installmentGroup: Value(t['installment_group'] as String?),
            installmentIndex: Value(t['installment_index'] as int?),
            installmentCount: Value(t['installment_count'] as int?),
            version: Value(t['version'] as int? ?? 1),
          ));
    }
    for (final t in _list(page['transfers'])) {
      await db.into(db.walletTransfers).insertOnConflictUpdate(WalletTransfersCompanion.insert(
            id: t['id']! as String,
            fromAccountId: t['from_account_id']! as String,
            toAccountId: t['to_account_id']! as String,
            amountCents: centsOf(t['amount']),
            occurredAt: DateTime.parse(t['occurred_at']! as String).toUtc(),
            note: Value(t['note'] as String?),
            createdBy: t['created_by']! as int,
            version: Value(t['version'] as int? ?? 1),
          ));
    }
    for (final m in _list(page['statement_marks'])) {
      await db.into(db.walletStatementMarks).insertOnConflictUpdate(WalletStatementMarksCompanion.insert(
            id: m['id']! as String,
            accountId: m['account_id']! as String,
            month: storedMonth(DateTime.parse(m['month']! as String)),
            paid: m['paid'] == true,
            version: Value(m['version'] as int? ?? 1),
          ));
    }
    for (final p in _list(page['scheduled_payments'])) {
      await db.into(db.walletScheduledPayments).insertOnConflictUpdate(WalletScheduledPaymentsCompanion.insert(
            id: p['id']! as String,
            title: p['title'] as String? ?? 'Ödeme',
            kind: p['kind']! as String,
            accountId: p['account_id']! as String,
            toAccountId: Value(p['to_account_id'] as String?),
            categoryId: Value(p['category_id'] as int?),
            amountCents: centsOf(p['amount']),
            dueAt: DateTime.parse(p['due_at']! as String).toUtc(),
            repeatMonthly: Value(p['repeat_monthly'] == true),
            completed: Value(p['completed'] == true),
            lastPaidAt: Value(p['last_paid_at'] == null ? null : DateTime.parse(p['last_paid_at']! as String).toUtc()),
            createdBy: p['created_by']! as int,
            version: Value(p['version'] as int? ?? 1),
          ));
    }
    for (final d in _list(page['deleted'])) {
      final id = d['id']! as String;
      switch (d['kind']) {
        case 'account':
          // Hidden or gone: drop it with everything only it explains.
          await (db.delete(db.walletAccounts)..where((t) => t.id.equals(id))).go();
          await (db.delete(db.walletTransactions)..where((t) => t.accountId.equals(id))).go();
          await (db.delete(db.walletStatementMarks)..where((t) => t.accountId.equals(id))).go();
          await (db.delete(db.walletScheduledPayments)..where((t) => t.accountId.equals(id))).go();
          await (db.delete(db.walletTransfers)
                ..where((t) =>
                    (t.fromAccountId.equals(id) & t.toAccountId.isNotInQuery(db.selectOnly(db.walletAccounts)..addColumns([db.walletAccounts.id]))) |
                    (t.toAccountId.equals(id) & t.fromAccountId.isNotInQuery(db.selectOnly(db.walletAccounts)..addColumns([db.walletAccounts.id])))))
              .go();
        case 'transaction':
          await (db.delete(db.walletTransactions)..where((t) => t.id.equals(id))).go();
        case 'transfer':
          await (db.delete(db.walletTransfers)..where((t) => t.id.equals(id))).go();
        case 'statement_mark':
          await (db.delete(db.walletStatementMarks)..where((t) => t.id.equals(id))).go();
        case 'scheduled_payment':
          await (db.delete(db.walletScheduledPayments)..where((t) => t.id.equals(id))).go();
      }
    }
    await db.setSyncState(membersKey, jsonEncode(page['members'] ?? const []));
    await db.setSyncState(categoriesKey, jsonEncode(page['categories'] ?? const []));
    await db.setSyncState(_cursorKey, '${page['cursor']}');
    if (page['scope'] != null) await db.setSyncState(_scopeKey, page['scope']! as String);
  }

  /// The pull includes the sent writes: drop them, handing the versions they
  /// produced to later writes on the same records still waiting.
  Future<void> _settleSent(List<WalletOp> outbox, List<String> sent) async {
    final versions = <String, int>{};
    for (final op in outbox) {
      if (sent.contains(op.requestId)) {
        final version = int.tryParse(op.detail ?? '');
        if (op.entityId != null && version != null) versions[op.entityId!] = version;
      } else if (op.state == OutboxState.pending && versions.containsKey(op.entityId) && op.values.containsKey('expected_version')) {
        final envelope = op.envelope..['expected_version'] = versions[op.entityId];
        await (database.update(database.walletOutbox)..where((t) => t.requestId.equals(op.requestId)))
            .write(WalletOutboxCompanion(payload: Value(jsonEncode(envelope))));
      }
    }
    await (database.delete(database.walletOutbox)..where((t) => t.requestId.isIn(sent))).go();
  }

  Future<void> _update(WalletOp op, {required OutboxState state, String? detail}) =>
      (database.update(database.walletOutbox)..where((t) => t.requestId.equals(op.requestId))).write(WalletOutboxCompanion(
        state: Value(state.name),
        detail: Value(detail),
        attempts: Value(op.attempts + 1),
        nextAttemptAt: const Value(null),
      ));

  Future<void> _retryLater(WalletOp op, DateTime now) =>
      (database.update(database.walletOutbox)..where((t) => t.requestId.equals(op.requestId))).write(WalletOutboxCompanion(
        attempts: Value(op.attempts + 1),
        nextAttemptAt: Value(now.add(backoff(op.attempts + 1))),
      ));

  static int? _returnedVersion(Map<String, Object?> result, String? entityId) {
    for (final entity in _list(result['entities'])) {
      if (entity['id'] == entityId && entity['version'] is int) return entity['version']! as int;
    }
    return null;
  }

  static bool _hasCurrent(Object? body) =>
      body is Map && body['detail'] is Map && (body['detail'] as Map)['current'] is Map && ((body['detail'] as Map)['current'] as Map).isNotEmpty;

  static String _message(Object? body) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      return detail is String ? detail : jsonEncode(detail);
    }
    return body?.toString() ?? 'Bilinmeyen hata';
  }

  static List<Map<String, Object?>> _list(Object? value) =>
      [for (final item in (value as List?) ?? const []) Map<String, Object?>.from(item as Map)];
}
