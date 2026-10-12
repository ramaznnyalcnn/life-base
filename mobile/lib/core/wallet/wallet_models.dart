import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../storage/app_database.dart';

/// Money is integer kuruş everywhere on the device.
typedef Cents = int;

/// "1234.5" / "1.234,50" / "-12" → kuruş. Null when it is not a number.
Cents? parseCents(String text) {
  var value = text.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (value.isEmpty) return null;
  // Turkish input: "." groups thousands, "," is the decimal point. Without a
  // comma, "15.000" is grouped thousands while "1234.5" is a decimal.
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(value)) {
    value = value.replaceAll('.', '');
  }
  final number = num.tryParse(value);
  return number == null ? null : (number * 100).round();
}

/// Server decimals ("123.45") → kuruş.
Cents centsOf(Object? value) => value == null ? 0 : parseCents('$value') ?? 0;

/// Kuruş → server decimal string.
String decimalOf(Cents cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

final _money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _moneyShort = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

/// "₺1.234,50"; whole amounts can drop the kuruş.
String formatMoney(Cents cents, {bool short = false}) =>
    (short && cents % 100 == 0 ? _moneyShort : _money).format(cents / 100);

/// Equal parts in kuruş, the remainder on the first part (same rule as the server).
List<Cents> splitCents(Cents amount, int parts) {
  final base = amount ~/ parts;
  final remainder = amount - base * parts;
  return [for (var i = 0; i < parts; i++) base + (i == 0 ? remainder : 0)];
}

/// Installment part ids: the first part keeps the purchase id.
String partId(String groupId, int index) => index == 1 ? groupId : '$groupId~$index';

DateTime addMonths(DateTime value, int months) {
  final index = value.year * 12 + value.month - 1 + months;
  final year = index ~/ 12, month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, value.day > lastDay ? lastDay : value.day, value.hour, value.minute, value.second);
}

/// The statement (first day of its month) a card purchase falls in: after
/// the statement day it moves to the next one.
DateTime statementMonthOf(DateTime localDay, int statementDay) {
  final next = localDay.day > statementDay;
  return DateTime(localDay.year, localDay.month + (next ? 1 : 0));
}

enum AccountType {
  cash('cash', 'Nakit'),
  bank('bank', 'Banka'),
  creditCard('credit_card', 'Kredi kartı');

  const AccountType(this.wire, this.label);
  final String wire;
  final String label;

  static AccountType of(String wire) => values.firstWhere((t) => t.wire == wire, orElse: () => bank);
}

/// Where a record stands relative to the server.
enum SyncMark { confirmed, pending, conflict, failed }

@immutable
class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.balance,
    this.serverId,
    this.bank,
    this.opening = 0,
    this.limit,
    this.statementDay,
    this.dueDay,
    this.shared = false,
    this.last4,
    this.network,
    this.color,
    this.iban,
    this.active = true,
    this.version = 1,
    this.sync = SyncMark.confirmed,
  });

  factory WalletAccount.fromRow(WalletAccountRow row) => WalletAccount(
        id: row.id,
        serverId: row.serverId,
        ownerId: row.ownerId,
        name: row.name,
        type: AccountType.of(row.type),
        bank: row.bank,
        balance: row.balanceCents,
        opening: row.openingCents,
        limit: row.limitCents,
        statementDay: row.statementDay,
        dueDay: row.dueDay,
        shared: row.visibility == 'shared',
        last4: row.last4,
        network: row.network,
        color: row.color,
        iban: row.iban,
        active: row.active,
        version: row.version,
      );

  final String id;
  final int? serverId;
  final int ownerId;
  final String name;
  final AccountType type;
  final String? bank;

  /// Cards: minus the debt.
  final Cents balance;
  final Cents opening;
  final Cents? limit;
  final int? statementDay;
  final int? dueDay;
  final bool shared;
  final String? last4;

  /// visa, mastercard, troy, amex
  final String? network;
  final String? color;
  final String? iban;
  final bool active;
  final int version;
  final SyncMark sync;

  bool get isCard => type == AccountType.creditCard;
  Cents get debt => isCard && balance < 0 ? -balance : 0;
  Cents? get available => isCard && limit != null ? limit! + balance : null;

  WalletAccount copyWith({
    String? name,
    String? bank,
    Cents? balance,
    Cents? opening,
    Cents? limit,
    int? statementDay,
    int? dueDay,
    bool? shared,
    String? last4,
    String? network,
    String? color,
    String? iban,
    bool? active,
    SyncMark? sync,
  }) =>
      WalletAccount(
        id: id,
        serverId: serverId,
        ownerId: ownerId,
        name: name ?? this.name,
        type: type,
        bank: bank ?? this.bank,
        balance: balance ?? this.balance,
        opening: opening ?? this.opening,
        limit: limit ?? this.limit,
        statementDay: statementDay ?? this.statementDay,
        dueDay: dueDay ?? this.dueDay,
        shared: shared ?? this.shared,
        last4: last4 ?? this.last4,
        network: network ?? this.network,
        color: color ?? this.color,
        iban: iban ?? this.iban,
        active: active ?? this.active,
        version: version,
        sync: sync ?? this.sync,
      );
}

enum TxKind {
  expense('expense', 'Gider'),
  income('income', 'Gelir'),
  payment('payment', 'Ödeme');

  const TxKind(this.wire, this.label);
  final String wire;
  final String label;

  static TxKind of(String wire) => values.firstWhere((k) => k.wire == wire, orElse: () => expense);

  /// What it does to the account balance (same as the server ledger).
  Cents effect(Cents amount) => this == expense ? -amount : amount;
}

@immutable
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.amount,
    required this.occurredAt,
    required this.createdBy,
    this.categoryId,
    this.category,
    this.statementMonth,
    this.note,
    this.installmentGroup,
    this.installmentIndex,
    this.installmentCount,
    this.version = 1,
    this.sync = SyncMark.confirmed,
  });

  factory WalletTransaction.fromRow(WalletTransactionRow row) => WalletTransaction(
        id: row.id,
        accountId: row.accountId,
        kind: TxKind.of(row.kind),
        categoryId: row.categoryId,
        category: row.category,
        amount: row.amountCents,
        occurredAt: row.occurredAt.toLocal(),
        statementMonth: row.statementMonth == null ? null : _localMonth(row.statementMonth!),
        note: row.note,
        createdBy: row.createdBy,
        installmentGroup: row.installmentGroup,
        installmentIndex: row.installmentIndex,
        installmentCount: row.installmentCount,
        version: row.version,
      );

  final String id;
  final String accountId;
  final TxKind kind;
  final int? categoryId;
  final String? category;
  final Cents amount;
  final DateTime occurredAt;
  final DateTime? statementMonth;

  /// "Neden?"
  final String? note;
  final int createdBy;
  final String? installmentGroup;
  final int? installmentIndex;
  final int? installmentCount;
  final int version;
  final SyncMark sync;

  /// The id that names the whole purchase (first installment).
  String get groupId => installmentGroup ?? id;

  WalletTransaction withSync(SyncMark sync) => WalletTransaction(
        id: id,
        accountId: accountId,
        kind: kind,
        categoryId: categoryId,
        category: category,
        amount: amount,
        occurredAt: occurredAt,
        statementMonth: statementMonth,
        note: note,
        createdBy: createdBy,
        installmentGroup: installmentGroup,
        installmentIndex: installmentIndex,
        installmentCount: installmentCount,
        version: version,
        sync: sync,
      );
}

@immutable
class WalletTransfer {
  const WalletTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.occurredAt,
    required this.createdBy,
    this.note,
    this.version = 1,
    this.sync = SyncMark.confirmed,
  });

  factory WalletTransfer.fromRow(WalletTransferRow row) => WalletTransfer(
        id: row.id,
        fromAccountId: row.fromAccountId,
        toAccountId: row.toAccountId,
        amount: row.amountCents,
        occurredAt: row.occurredAt.toLocal(),
        note: row.note,
        createdBy: row.createdBy,
        version: row.version,
      );

  final String id;
  final String fromAccountId;
  final String toAccountId;
  final Cents amount;
  final DateTime occurredAt;
  final String? note;
  final int createdBy;
  final int version;
  final SyncMark sync;

  WalletTransfer withSync(SyncMark sync) => WalletTransfer(
        id: id,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        occurredAt: occurredAt,
        note: note,
        createdBy: createdBy,
        version: version,
        sync: sync,
      );
}

@immutable
class StatementMark {
  const StatementMark({required this.accountId, required this.month, required this.paid, this.version = 1, this.sync = SyncMark.confirmed});

  factory StatementMark.fromRow(WalletMarkRow row) =>
      StatementMark(accountId: row.accountId, month: _localMonth(row.month), paid: row.paid, version: row.version);

  final String accountId;
  final DateTime month;
  final bool paid;
  final int version;
  final SyncMark sync;

  String get id => markId(accountId, month);
}

/// A planned payment. Nothing moves until it is paid ("Ödendi"): then an
/// expense (or, with [toAccountId], a transfer such as a card payment) is
/// recorded and a monthly payment moves a month on.
@immutable
class ScheduledPayment {
  const ScheduledPayment({
    required this.id,
    required this.title,
    required this.accountId,
    required this.amount,
    required this.dueAt,
    required this.createdBy,
    this.toAccountId,
    this.categoryId,
    this.repeatMonthly = false,
    this.completed = false,
    this.lastPaidAt,
    this.version = 1,
    this.sync = SyncMark.confirmed,
  });

  factory ScheduledPayment.fromRow(WalletPaymentRow row) => ScheduledPayment(
        id: row.id,
        title: row.title,
        accountId: row.accountId,
        toAccountId: row.toAccountId,
        categoryId: row.categoryId,
        amount: row.amountCents,
        dueAt: row.dueAt.toLocal(),
        repeatMonthly: row.repeatMonthly,
        completed: row.completed,
        lastPaidAt: row.lastPaidAt?.toLocal(),
        createdBy: row.createdBy,
        version: row.version,
      );

  final String id;
  final String title;
  final String accountId;

  /// Set for a transfer / card payment; null for an expense.
  final String? toAccountId;
  final int? categoryId;
  final Cents amount;
  final DateTime dueAt;
  final bool repeatMonthly;
  final bool completed;
  final DateTime? lastPaidAt;
  final int createdBy;
  final int version;
  final SyncMark sync;

  bool get isTransfer => toAccountId != null;
  String get kind => isTransfer ? 'transfer' : 'expense';

  /// Paid: a monthly payment moves a month on, a one-off is done.
  ScheduledPayment paid(DateTime at) => copyWith(
        dueAt: repeatMonthly ? addMonths(dueAt, 1) : dueAt,
        completed: !repeatMonthly,
        lastPaidAt: at,
      );

  ScheduledPayment copyWith({DateTime? dueAt, bool? completed, DateTime? lastPaidAt, SyncMark? sync}) => ScheduledPayment(
        id: id,
        title: title,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        amount: amount,
        dueAt: dueAt ?? this.dueAt,
        repeatMonthly: repeatMonthly,
        completed: completed ?? this.completed,
        lastPaidAt: lastPaidAt ?? this.lastPaidAt,
        createdBy: createdBy,
        version: version,
        sync: sync ?? this.sync,
      );
}

String markId(String accountId, DateTime month) => '$accountId:${DateFormat('yyyy-MM').format(month)}';

@immutable
class HouseholdMember {
  const HouseholdMember({required this.userId, required this.name, this.isMe = false});
  final int userId;
  final String name;
  final bool isMe;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => String.fromCharCode(p.runes.first).toUpperCase()).join();
  }
}

@immutable
class WalletCategory {
  const WalletCategory({required this.id, required this.name, required this.kind});
  final int id;
  final String name;
  final TxKind kind;
}

/// Months are stored as UTC midnights of the first day.
DateTime _localMonth(DateTime stored) {
  final utc = stored.toUtc();
  return DateTime(utc.year, utc.month);
}

DateTime storedMonth(DateTime month) => DateTime.utc(month.year, month.month);
