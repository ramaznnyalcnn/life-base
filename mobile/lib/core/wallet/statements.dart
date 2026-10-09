import 'dart:math';

import 'package:flutter/foundation.dart';

import 'wallet_models.dart';
import 'wallet_outbox.dart';

DateTime _clampDay(int year, int month, int day) => DateTime(year, month, min(day, DateTime(year, month + 1, 0).day));

/// The statement date of a statement month (bucket = first of the month).
DateTime closeDateOf(DateTime bucket, int statementDay) => _clampDay(bucket.year, bucket.month, statementDay);

/// The payment due date after a statement date: later the same month when the
/// due day comes after the statement day, otherwise the next month.
DateTime dueDateOf(DateTime close, int dueDay) =>
    dueDay > close.day ? _clampDay(close.year, close.month, dueDay) : _clampDay(close.year, close.month + 1, dueDay);

enum StatementStatus {
  /// Still collecting purchases.
  open('Açık dönem'),

  /// Closed, payment not covered yet, due date ahead.
  unpaid('Ödenmedi'),

  /// Closed and partly paid.
  partial('Kısmen ödendi'),
  paid('Ödendi'),

  /// Due date passed without full payment.
  overdue('Gecikti');

  const StatementStatus(this.label);
  final String label;
}

@immutable
class StatementPeriod {
  const StatementPeriod({
    required this.month,
    required this.opens,
    required this.closes,
    required this.due,
    required this.spent,
    required this.paidAmount,
    required this.manual,
    required this.status,
  });

  /// Bucket: first day of the statement's month.
  final DateTime month;
  final DateTime opens;
  final DateTime closes;
  final DateTime? due;

  /// Purchases minus refunds in this statement.
  final Cents spent;

  /// Card payments made after it closed (until the next one closes).
  final Cents paidAmount;

  /// The user's manual mark, when there is one.
  final bool? manual;
  final StatementStatus status;

  Cents get remaining => max(0, spent - paidAmount);
}

/// Statements of [card], newest first: every month with purchases, plus the
/// open one. Needs a statement day.
List<StatementPeriod> statementsOf(WalletAccount card, WalletData wallet, DateTime now) {
  final statementDay = card.statementDay;
  if (!card.isCard || statementDay == null) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final current = statementMonthOf(today, statementDay);

  final spent = <DateTime, Cents>{};
  final payments = <(DateTime, Cents)>[];
  for (final tx in wallet.transactions.values) {
    if (tx.accountId != card.id) continue;
    if (tx.kind == TxKind.payment) {
      payments.add((tx.occurredAt, tx.amount));
      continue;
    }
    final bucket = tx.statementMonth ?? statementMonthOf(tx.occurredAt, statementDay);
    spent[bucket] = (spent[bucket] ?? 0) + (tx.kind == TxKind.expense ? tx.amount : -tx.amount);
  }
  for (final transfer in wallet.transfers.values) {
    if (transfer.toAccountId == card.id) payments.add((transfer.occurredAt, transfer.amount));
    if (transfer.fromAccountId == card.id) payments.add((transfer.occurredAt, -transfer.amount));
  }

  final months = {...spent.keys, current}.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final month in months)
      () {
        final closes = closeDateOf(month, statementDay);
        final previousClose = closeDateOf(DateTime(month.year, month.month - 1), statementDay);
        final nextClose = closeDateOf(DateTime(month.year, month.month + 1), statementDay);
        final due = card.dueDay == null ? null : dueDateOf(closes, card.dueDay!);
        final paidAmount = payments
            .where((p) {
              final day = DateTime(p.$1.year, p.$1.month, p.$1.day);
              return day.isAfter(closes) && !day.isAfter(nextClose);
            })
            .fold<Cents>(0, (sum, p) => sum + p.$2);
        final total = spent[month] ?? 0;
        final manual = wallet.marks[markId(card.id, month)]?.paid;
        // A manual mark wins over the automatic rule.
        final status = !today.isAfter(closes)
            ? StatementStatus.open
            : (manual ?? paidAmount >= total)
                ? StatementStatus.paid
                : _unpaid(today, due, paidAmount);
        return StatementPeriod(
          month: month,
          opens: previousClose.add(const Duration(days: 1)),
          closes: closes,
          due: due,
          spent: total,
          paidAmount: paidAmount,
          manual: manual,
          status: status,
        );
      }(),
  ];
}

StatementStatus _unpaid(DateTime today, DateTime? due, Cents paid) {
  if (due != null && today.isAfter(due)) return StatementStatus.overdue;
  return paid > 0 ? StatementStatus.partial : StatementStatus.unpaid;
}

/// The next statement date of a card, and how far through the period today is.
({DateTime close, int daysLeft, double progress})? nextClose(WalletAccount card, DateTime now) {
  final statementDay = card.statementDay;
  if (!card.isCard || statementDay == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final month = statementMonthOf(today, statementDay);
  final close = closeDateOf(month, statementDay);
  final previous = closeDateOf(DateTime(month.year, month.month - 1), statementDay);
  final length = close.difference(previous).inDays;
  final left = close.difference(today).inDays;
  return (close: close, daysLeft: left, progress: length <= 0 ? 0 : 1 - left / length);
}

/// The closest unpaid statement with a due date, for reminders and Bugün.
StatementPeriod? upcomingDue(WalletAccount card, WalletData wallet, DateTime now) {
  final open = statementsOf(card, wallet, now)
      .where((s) => s.due != null && s.remaining > 0 && (s.status == StatementStatus.unpaid || s.status == StatementStatus.partial || s.status == StatementStatus.overdue))
      .toList()
    ..sort((a, b) => a.due!.compareTo(b.due!));
  return open.firstOrNull;
}
