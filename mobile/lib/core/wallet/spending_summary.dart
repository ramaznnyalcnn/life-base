import 'package:flutter/foundation.dart';

import 'wallet_models.dart';
import 'wallet_outbox.dart';

/// The time span a spending summary covers.
enum SummaryPeriod {
  month('Bu ay', 'geçen aya göre'),
  quarter('Son 90 gün', 'önceki 90 güne göre'),
  year('Bu yıl', 'geçen yıla göre'),
  all('Tümü', null);

  const SummaryPeriod(this.label, this.comparedLabel);
  final String label;

  /// How the previous span is named next to a change ("geçen aya göre").
  final String? comparedLabel;

  /// First moment counted, or null for all time.
  DateTime? startOf(DateTime now) => switch (this) {
        month => DateTime(now.year, now.month),
        quarter => DateTime(now.year, now.month, now.day - 89),
        year => DateTime(now.year),
        all => null,
      };

  /// The same span just before this one ("geçen ay" up to the same day).
  (DateTime, DateTime)? previousOf(DateTime now) => switch (this) {
        month => (DateTime(now.year, now.month - 1), DateTime(now.year, now.month - 1, now.day + 1)),
        quarter => (DateTime(now.year, now.month, now.day - 179), DateTime(now.year, now.month, now.day - 89)),
        year => (DateTime(now.year - 1), DateTime(now.year - 1, now.month, now.day + 1)),
        all => null,
      };
}

/// Categories that get their own colour; the rest fold into "Diğer".
const summaryCategorySlots = 5;

/// One category's share of the spending. [slot] is its colour slot (0-based),
/// null for "Diğer".
@immutable
class CategorySlice {
  const CategorySlice({required this.name, required this.amount, this.slot});
  final String name;
  final Cents amount;
  final int? slot;
}

@immutable
class MonthSpend {
  const MonthSpend(this.month, this.amount);

  /// First day of the month.
  final DateTime month;
  final Cents amount;
}

@immutable
class SpendingSummary {
  const SpendingSummary({
    required this.spent,
    required this.paid,
    required this.income,
    required this.previousSpent,
    required this.slices,
    required this.months,
    required this.byPerson,
    required this.top,
  });

  /// Expenses minus refunds to cards in the period.
  final Cents spent;

  /// Card payments in the period (into the cards counted).
  final Cents paid;

  /// Income on bank and cash accounts in the period.
  final Cents income;

  /// Spending over the same span just before, null for all time.
  final Cents? previousSpent;

  /// Coloured categories, biggest first, then "Diğer"; only those with spending.
  final List<CategorySlice> slices;

  /// Spending of the last six calendar months, oldest first (whatever the period).
  final List<MonthSpend> months;

  /// User id → spending in the period.
  final Map<int, Cents> byPerson;

  /// The biggest expenses of the period, biggest first.
  final List<WalletTransaction> top;

  /// Change against the previous span as a fraction (0.12 = 12% more), or
  /// null when there is nothing to compare with.
  double? get change => previousSpent == null || previousSpent! <= 0 ? null : (spent - previousSpent!) / previousSpent!;
}

const otherCategory = 'Diğer';

String _categoryOf(WalletTransaction tx) {
  final name = tx.category?.trim() ?? '';
  return name.isEmpty ? otherCategory : name;
}

/// What spending [tx] counts as: an expense adds, a refund to a card takes
/// back, anything else (income to a bank, card payments) is not spending.
Cents? _spend(WalletTransaction tx, bool onCard) => switch (tx.kind) {
      TxKind.expense => tx.amount,
      TxKind.income => onCard ? -tx.amount : null,
      TxKind.payment => null,
    };

/// What was spent from, earned into and paid into [accountIds] over [period].
SpendingSummary summarizeSpending(Set<String> accountIds, WalletData wallet, SummaryPeriod period, DateTime now) {
  final start = period.startOf(now);
  final end = DateTime(now.year, now.month, now.day + 1);
  bool inPeriod(DateTime at) => (start == null || !at.isBefore(start)) && at.isBefore(end);
  bool onCard(String accountId) => wallet.accounts[accountId]?.isCard ?? false;

  final txs = [for (final tx in wallet.transactions.values) if (accountIds.contains(tx.accountId) && tx.occurredAt.isBefore(end)) tx];
  Cents? spend(WalletTransaction tx) => _spend(tx, onCard(tx.accountId));

  // Colour slots follow the category, not its rank in the period: the
  // biggest categories of all time keep the same colour under any filter.
  final allTime = <String, Cents>{};
  for (final tx in txs) {
    final amount = spend(tx);
    if (amount != null) allTime.update(_categoryOf(tx), (v) => v + amount, ifAbsent: () => amount);
  }
  final ranked = (allTime.entries.where((e) => e.key != otherCategory && e.value > 0).toList()
        ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key)))
      .take(summaryCategorySlots)
      .map((e) => e.key)
      .toList();
  final slotOf = {for (var i = 0; i < ranked.length; i++) ranked[i]: i};

  var spent = 0, paid = 0, income = 0;
  final byCategory = <String, Cents>{};
  final byPerson = <int, Cents>{};
  final expenses = <WalletTransaction>[];
  for (final tx in txs.where((tx) => inPeriod(tx.occurredAt))) {
    if (tx.kind == TxKind.payment) {
      if (onCard(tx.accountId)) paid += tx.amount;
      continue;
    }
    final amount = spend(tx);
    if (amount == null) {
      income += tx.amount;
      continue;
    }
    if (tx.kind == TxKind.expense) expenses.add(tx);
    spent += amount;
    final name = slotOf.containsKey(_categoryOf(tx)) ? _categoryOf(tx) : otherCategory;
    byCategory.update(name, (v) => v + amount, ifAbsent: () => amount);
    byPerson.update(tx.createdBy, (v) => v + amount, ifAbsent: () => amount);
  }
  for (final transfer in wallet.transfers.values.where((t) => inPeriod(t.occurredAt))) {
    if (accountIds.contains(transfer.toAccountId) && onCard(transfer.toAccountId)) paid += transfer.amount;
    if (accountIds.contains(transfer.fromAccountId) && onCard(transfer.fromAccountId)) paid -= transfer.amount;
  }

  Cents spentBetween(DateTime from, DateTime to) {
    var amount = 0;
    for (final tx in txs) {
      if (tx.occurredAt.isBefore(from) || !tx.occurredAt.isBefore(to)) continue;
      amount += spend(tx) ?? 0;
    }
    return amount < 0 ? 0 : amount;
  }

  final previous = period.previousOf(now);
  // Biggest first in this period; each keeps its colour, "Diğer" goes last.
  final slices = [
    ...[
      for (final name in ranked)
        if ((byCategory[name] ?? 0) > 0) CategorySlice(name: name, amount: byCategory[name]!, slot: slotOf[name]),
    ]..sort((a, b) => b.amount.compareTo(a.amount)),
    if ((byCategory[otherCategory] ?? 0) > 0) CategorySlice(name: otherCategory, amount: byCategory[otherCategory]!),
  ];

  return SpendingSummary(
    spent: spent,
    paid: paid,
    income: income,
    previousSpent: previous == null ? null : spentBetween(previous.$1, previous.$2),
    slices: slices,
    months: [
      for (var back = 5; back >= 0; back--)
        MonthSpend(DateTime(now.year, now.month - back), spentBetween(DateTime(now.year, now.month - back), DateTime(now.year, now.month - back + 1))),
    ],
    byPerson: {for (final e in byPerson.entries) if (e.value > 0) e.key: e.value},
    top: (expenses..sort((a, b) => b.amount.compareTo(a.amount))).take(5).toList(),
  );
}

/// One card's summary.
SpendingSummary summarizeCard(WalletAccount card, WalletData wallet, SummaryPeriod period, DateTime now) =>
    summarizeSpending({card.id}, WalletData(accounts: {...wallet.accounts, card.id: card}, transactions: wallet.transactions, transfers: wallet.transfers), period, now);
