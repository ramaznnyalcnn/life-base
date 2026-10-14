import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/wallet/card_summary.dart';
import 'package:lifebase_mobile/core/wallet/wallet_models.dart';
import 'package:lifebase_mobile/core/wallet/wallet_outbox.dart';

const card = WalletAccount(id: 'card', ownerId: 1, name: 'Kart', type: AccountType.creditCard, balance: 0);
final now = DateTime(2026, 10, 14, 12);

WalletTransaction tx(String id, TxKind kind, Cents amount, DateTime at, {String? category, int by = 1, String account = 'card'}) =>
    WalletTransaction(id: id, accountId: account, kind: kind, amount: amount, occurredAt: at, createdBy: by, category: category);

void main() {
  final wallet = WalletData(
    transactions: {
      for (final t in [
        tx('a', TxKind.expense, 30000, DateTime(2026, 10, 2), category: 'Market', by: 1),
        tx('b', TxKind.expense, 10000, DateTime(2026, 10, 5), category: 'Yemek', by: 2),
        tx('c', TxKind.income, 5000, DateTime(2026, 10, 6), category: 'Market', by: 1), // refund
        tx('d', TxKind.expense, 90000, DateTime(2026, 6, 1), category: 'Yemek', by: 2),
        tx('e', TxKind.payment, 20000, DateTime(2026, 10, 7)),
        tx('f', TxKind.expense, 99999, DateTime(2026, 10, 3), account: 'bank'),
        tx('g', TxKind.expense, 777, DateTime(2026, 10, 9)),
      ])
        t.id: t,
    },
    transfers: {
      't': WalletTransfer(id: 't', fromAccountId: 'bank', toAccountId: 'card', amount: 15000, occurredAt: DateTime(2026, 10, 8), createdBy: 1),
    },
  );

  test('this month: spending net of refunds, payments from the card and transfers', () {
    final s = summarizeCard(card, wallet, SummaryPeriod.month, now);
    expect(s.spent, 30000 + 10000 - 5000 + 777);
    expect(s.paid, 20000 + 15000);
    expect(s.byPerson, {1: 25777, 2: 10000});
  });

  test('colours follow the category, not its rank in the period', () {
    final month = summarizeCard(card, wallet, SummaryPeriod.month, now);
    final all = summarizeCard(card, wallet, SummaryPeriod.all, now);
    // Yemek is the biggest of all time, so it keeps slot 0 even when Market leads this month.
    expect([for (final s in month.slices) (s.name, s.slot)], [('Yemek', 0), ('Market', 1), (otherCategory, null)]);
    expect(all.slices.first.amount, 100000);
  });

  test('six months of bars, oldest first, other accounts ignored', () {
    final s = summarizeCard(card, wallet, SummaryPeriod.month, now);
    expect(s.months.map((m) => m.month.month), [5, 6, 7, 8, 9, 10]);
    expect(s.months[1].amount, 90000);
    expect(s.months.last.amount, 35777);
  });
}
