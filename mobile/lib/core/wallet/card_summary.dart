import 'package:flutter/foundation.dart';

import 'wallet_models.dart';
import 'wallet_outbox.dart';

/// The time span a card summary covers.
enum SummaryPeriod {
  month('Bu ay'),
  quarter('Son 90 gün'),
  year('Bu yıl'),
  all('Tümü');

  const SummaryPeriod(this.label);
  final String label;

  /// First moment counted, or null for all time.
  DateTime? startOf(DateTime now) => switch (this) {
        month => DateTime(now.year, now.month),
        quarter => DateTime(now.year, now.month, now.day - 89),
        year => DateTime(now.year),
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
class CardSummary {
  const CardSummary({
    required this.spent,
    required this.paid,
    required this.slices,
    required this.months,
    required this.byPerson,
  });

  /// Expenses minus refunds in the period.
  final Cents spent;

  /// Card payments in the period.
  final Cents paid;

  /// Coloured categories in slot order, then "Diğer"; only those with spending.
  final List<CategorySlice> slices;

  /// Spending of the last six calendar months, oldest first (whatever the period).
  final List<MonthSpend> months;

  /// User id → spending in the period.
  final Map<int, Cents> byPerson;
}

const otherCategory = 'Diğer';

String _categoryOf(WalletTransaction tx) {
  final name = tx.category?.trim() ?? '';
  return name.isEmpty ? otherCategory : name;
}

/// Spending on [card] (an expense counts, a refund to the card takes back).
Cents? _spend(WalletTransaction tx) => switch (tx.kind) {
      TxKind.expense => tx.amount,
      TxKind.income => -tx.amount,
      TxKind.payment => null,
    };

/// What was spent on and paid into [card] over [period].
CardSummary summarizeCard(WalletAccount card, WalletData wallet, SummaryPeriod period, DateTime now) {
  final start = period.startOf(now);
  final end = DateTime(now.year, now.month, now.day + 1);
  bool inPeriod(DateTime at) => (start == null || !at.isBefore(start)) && at.isBefore(end);

  final txs = [for (final tx in wallet.transactions.values) if (tx.accountId == card.id && tx.occurredAt.isBefore(end)) tx];

  // Colour slots follow the category, not its rank in the period: the
  // card's biggest categories of all time keep the same colour under any filter.
  final allTime = <String, Cents>{};
  for (final tx in txs) {
    final amount = _spend(tx);
    if (amount != null) allTime.update(_categoryOf(tx), (v) => v + amount, ifAbsent: () => amount);
  }
  final ranked = (allTime.entries.where((e) => e.key != otherCategory && e.value > 0).toList()
        ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key)))
      .take(summaryCategorySlots)
      .map((e) => e.key)
      .toList();
  final slotOf = {for (var i = 0; i < ranked.length; i++) ranked[i]: i};

  var spent = 0, paid = 0;
  final byCategory = <String, Cents>{};
  final byPerson = <int, Cents>{};
  for (final tx in txs.where((tx) => inPeriod(tx.occurredAt))) {
    final amount = _spend(tx);
    if (amount == null) {
      paid += tx.amount;
      continue;
    }
    spent += amount;
    final name = slotOf.containsKey(_categoryOf(tx)) ? _categoryOf(tx) : otherCategory;
    byCategory.update(name, (v) => v + amount, ifAbsent: () => amount);
    byPerson.update(tx.createdBy, (v) => v + amount, ifAbsent: () => amount);
  }
  for (final transfer in wallet.transfers.values.where((t) => inPeriod(t.occurredAt))) {
    if (transfer.toAccountId == card.id) paid += transfer.amount;
    if (transfer.fromAccountId == card.id) paid -= transfer.amount;
  }

  final slices = [
    for (final name in ranked)
      if ((byCategory[name] ?? 0) > 0) CategorySlice(name: name, amount: byCategory[name]!, slot: slotOf[name]),
    if ((byCategory[otherCategory] ?? 0) > 0) CategorySlice(name: otherCategory, amount: byCategory[otherCategory]!),
  ];

  final months = [
    for (var back = 5; back >= 0; back--)
      () {
        final month = DateTime(now.year, now.month - back);
        final next = DateTime(month.year, month.month + 1);
        var amount = 0;
        for (final tx in txs) {
          if (tx.occurredAt.isBefore(month) || !tx.occurredAt.isBefore(next)) continue;
          amount += _spend(tx) ?? 0;
        }
        return MonthSpend(month, amount < 0 ? 0 : amount);
      }(),
  ];

  return CardSummary(
    spent: spent,
    paid: paid,
    slices: slices,
    months: months,
    byPerson: {for (final e in byPerson.entries) if (e.value > 0) e.key: e.value},
  );
}
