import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'account_edit_page.dart';
import 'card_face.dart';
import 'entry_page.dart';
import 'wallet_format.dart';
import 'wallet_screen.dart';

/// An account's page: balance and movements; for a card, its statements.
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final account = wallet.accounts[accountId];
    if (account == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('Bu hesap artık yok.', style: TextStyle(color: t.muted))));
    }
    final now = DateTime.now();
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(tooltip: 'Düzenle', icon: const Icon(Icons.edit_rounded), onPressed: () => open(AccountEditPage(initial: account))),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        if (account.isCard) ...[
          CardFace(card: account, wallet: wallet, now: now),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => open(EntryPage(initialType: EntryType.expense, initialAccountId: account.id)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Harcama'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => open(EntryPage(initialType: EntryType.cardPayment, initialAccountId: account.id)),
                icon: const Icon(Icons.credit_score_rounded),
                label: const Text('Kart ödemesi'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (account.statementDay == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Ekstreleri görmek için karta kesim günü ekle.', style: TextStyle(color: t.muted)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text('Ekstreler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
            ),
            for (final period in statementsOf(account, wallet, now)) _StatementTile(card: account, period: period, wallet: wallet),
          ],
        ] else ...[
          NeuSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account.bank ?? account.type.label, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(formatMoney(account.balance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: t.onBase)),
              if (account.sync != SyncMark.confirmed) Text('tahmini', style: TextStyle(color: t.muted, fontStyle: FontStyle.italic)),
              if (account.iban != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: SelectableText(formatIban(account.iban!), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
                  IconButton(
                    tooltip: 'IBAN kopyala',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: account.iban!));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IBAN kopyalandı')));
                    },
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          for (final entry in entriesOf(wallet, {account.id}, now).take(100)) EntryTile(entry: entry, wallet: wallet),
        ],
      ]),
    );
  }
}

class _StatementTile extends ConsumerWidget {
  const _StatementTile({required this.card, required this.period, required this.wallet});
  final WalletAccount card;
  final StatementPeriod period;
  final WalletData wallet;

  Color _statusColor(LbTokens t) => switch (period.status) {
        StatementStatus.paid => t.income,
        StatementStatus.overdue => t.danger,
        StatementStatus.open => t.muted,
        _ => const Color(0xFFE09B2D),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final days = DateFormat('d MMM', 'tr_TR');
    final items = wallet.transactions.values
        .where((tx) => tx.accountId == card.id && (tx.statementMonth ?? statementMonthOf(tx.occurredAt, card.statementDay!)) == period.month && tx.kind != TxKind.payment)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        padding: EdgeInsets.zero,
        depth: 4,
        radius: LbTokens.radiusSmall + 4,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text('${DateFormat('MMMM y', 'tr_TR').format(period.month)} ekstresi',
                style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase)),
            subtitle: Text(
              [
                '${days.format(period.opens)} – ${days.format(period.closes)}',
                if (period.due != null) 'son ödeme ${days.format(period.due!)}',
              ].join(' · '),
              style: TextStyle(color: t.muted, fontSize: 12),
            ),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatMoney(period.spent), style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase)),
              Text(
                '${period.status.label}${period.manual != null ? ' (elle)' : ''}',
                style: TextStyle(color: _statusColor(t), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ]),
            children: [
              if (period.status != StatementStatus.open)
                Row(children: [
                  Expanded(
                    child: Text(
                      period.paidAmount > 0 ? 'Ödenen ${formatMoney(period.paidAmount)} · kalan ${formatMoney(period.remaining)}' : 'Bu dönem için ödeme yok',
                      style: TextStyle(color: t.muted, fontSize: 12),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Ödendi işareti',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) => ref.read(walletRepositoryProvider).markStatement(
                          card.id,
                          period.month,
                          switch (value) { 'paid' => true, 'unpaid' => false, _ => null },
                        ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'paid', child: Text('Ödendi olarak işaretle')),
                      const PopupMenuItem(value: 'unpaid', child: Text('Ödenmedi olarak işaretle')),
                      if (period.manual != null) const PopupMenuItem(value: 'auto', child: Text('Otomatiğe dön')),
                    ],
                  ),
                ]),
              for (final tx in items)
                EntryTile(entry: WalletEntry.tx(tx), wallet: wallet),
              if (items.isEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Harcama yok.', style: TextStyle(color: t.muted))),
            ],
          ),
        ),
      ),
    );
  }
}
