import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'entry_page.dart';
import 'outbox_issues_page.dart';
import 'wallet_format.dart';

/// One movement: what, where, who, why, and edit/delete.
class EntryDetailPage extends ConsumerWidget {
  const EntryDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final members = {for (final m in ref.watch(walletMembersProvider).value ?? const <HouseholdMember>[]) m.userId: m};
    final tx = wallet.transactions[entryId];
    final transfer = wallet.transfers[entryId];
    if (tx == null && transfer == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('Bu hareket artık yok.', style: TextStyle(color: t.muted))));
    }
    final groupId = tx?.groupId ?? transfer!.id;
    final issue = (ref.watch(walletOutboxProvider).value ?? const <WalletOp>[])
        .where((op) => op.entityId == groupId && (op.state == OutboxState.conflict || op.state == OutboxState.failed))
        .firstOrNull;
    final when = DateFormat('d MMMM y EEEE · HH:mm', 'tr_TR');

    final rows = <(IconData, String)>[];
    final String title;
    final Cents amount;
    final int createdBy;
    if (tx != null) {
      final account = wallet.accounts[tx.accountId];
      title = tx.kind == TxKind.payment ? 'Kart ödemesi' : categoryLabel(tx.category);
      amount = tx.kind.effect(tx.amount);
      createdBy = tx.createdBy;
      rows
        ..add((Icons.account_balance_wallet_rounded, account?.name ?? 'Hesap'))
        ..add((Icons.schedule_rounded, when.format(tx.occurredAt)));
      if (tx.installmentCount != null) {
        final parts = wallet.transactions.values.where((p) => p.groupId == tx.groupId).fold<Cents>(0, (s, p) => s + p.amount);
        rows.add((Icons.splitscreen_rounded, '${tx.installmentIndex}/${tx.installmentCount}. taksit · toplam ${formatMoney(parts)}'));
      }
      if (tx.statementMonth != null) rows.add((Icons.receipt_long_rounded, '${DateFormat('MMMM y', 'tr_TR').format(tx.statementMonth!)} ekstresi'));
    } else {
      final from = wallet.accounts[transfer!.fromAccountId];
      final to = wallet.accounts[transfer.toAccountId];
      title = (to?.isCard ?? false) ? 'Kart ödemesi' : 'Transfer';
      amount = transfer.amount;
      createdBy = transfer.createdBy;
      rows
        ..add((Icons.swap_horiz_rounded, '${from?.name ?? 'Diğer hesap'} → ${to?.name ?? 'Diğer hesap'}'))
        ..add((Icons.schedule_rounded, when.format(transfer.occurredAt)));
    }
    final author = members.length > 1 ? members[createdBy] : null;
    if (author != null) rows.add((Icons.person_rounded, '${author.isMe ? 'Sen' : author.name} girdi'));
    final note = tx?.note ?? transfer?.note;
    final sync = tx?.sync ?? transfer!.sync;

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(context, ref, tx, transfer)),
        const SizedBox(width: 4),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
          builder: (_) => EntryPage(initialTx: tx, initialTransfer: transfer),
        )),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Düzenle'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
        const SizedBox(height: 4),
        Text(
          tx == null ? formatMoney(amount) : '${amount > 0 ? '+' : '−'}${formatMoney(amount.abs())}',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: amount > 0 && tx != null ? t.income : t.onBase),
        ),
        if (sync == SyncMark.pending)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: t.muted),
              const SizedBox(width: 6),
              Text('Gönderilmeyi bekliyor; bakiye tahmini.', style: TextStyle(color: t.muted)),
            ]),
          ),
        const SizedBox(height: 20),
        if (issue != null) ...[IssueCard(op: issue, wallet: wallet), const SizedBox(height: 16)],
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: t.muted, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600, height: 1.35))),
            ]),
          ),
        if (note != null) ...[
          Text('Neden', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          NeuSurface(child: SelectableText(note, style: TextStyle(color: t.onBase, height: 1.4))),
        ],
      ]),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WalletTransaction? tx, WalletTransfer? transfer) async {
    final navigator = Navigator.of(context);
    final installments = tx?.installmentCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hareket silinsin mi?'),
        content: Text(installments == null ? 'Bakiye buna göre düzeltilir.' : '$installments taksidin hepsi silinir; bakiye düzeltilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(walletRepositoryProvider);
    if (tx != null) {
      await repo.deleteTransaction(tx);
    } else {
      await repo.deleteTransfer(transfer!);
    }
    navigator.pop();
  }
}
