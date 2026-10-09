import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'wallet_format.dart';

/// Writes the server refused: conflicts to decide and failures to drop or retry.
class OutboxIssuesPage extends ConsumerWidget {
  const OutboxIssuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final issues = (ref.watch(walletOutboxProvider).value ?? const <WalletOp>[])
        .where((op) => op.state == OutboxState.conflict || op.state == OutboxState.failed)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Kararını bekleyenler')),
      body: issues.isEmpty
          ? Center(child: Text('Bekleyen bir şey yok.', style: TextStyle(color: t.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: issues.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => IssueCard(op: issues[index], wallet: wallet),
            ),
    );
  }
}

const _verbs = {
  'wallet.account.save': 'Hesap ayarı',
  'wallet.account.archive': 'Hesap arşivi',
  'wallet.transaction.save': 'Hareket',
  'wallet.transaction.delete': 'Hareketi silme',
  'wallet.transfer.save': 'Transfer',
  'wallet.transfer.delete': 'Transferi silme',
  'wallet.statement.mark': 'Ekstre işareti',
};

/// What a write (or the server's record) says, in a few short lines.
List<String> describeRecord(Map<String, Object?> values, WalletData wallet) {
  final source = values['account'] is Map ? Map<String, Object?>.from(values['account']! as Map) : values;
  String? accountName(Object? id) => id == null ? null : wallet.accounts[id]?.name ?? 'Diğer hesap';
  final at = source['occurred_at'] == null ? null : DateTime.tryParse(source['occurred_at']! as String)?.toLocal();
  return [
    if (source['name'] != null) '${source['name']}',
    if (source['amount'] != null) formatMoney(centsOf(source['amount'])),
    if (source['account_id'] != null && source['name'] == null) accountName(source['account_id'])!,
    if (source['from_account_id'] != null) '${accountName(source['from_account_id'])} → ${accountName(source['to_account_id'])}',
    if (source['category'] != null) categoryLabel(source['category'] as String?),
    if (at != null) DateFormat('d MMM y HH:mm', 'tr_TR').format(at),
    if (source['note'] != null) '“${source['note']}”',
    if (source['opening_balance'] != null) 'Açılış ${formatMoney(centsOf(source['opening_balance']))}',
    if (source['visibility'] != null) source['visibility'] == 'shared' ? 'Ortak' : 'Kişisel',
    if (source['paid'] != null) source['paid'] == true ? 'Ödendi' : 'Ödenmedi',
  ];
}

class IssueCard extends ConsumerWidget {
  const IssueCard({super.key, required this.op, required this.wallet});
  final WalletOp op;
  final WalletData wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final repo = ref.read(walletRepositoryProvider);
    final conflict = op.state == OutboxState.conflict;
    final server = op.serverRecord;
    return NeuSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(conflict ? Icons.warning_amber_rounded : Icons.error_outline_rounded, color: conflict ? const Color(0xFFE09B2D) : t.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conflict ? '${_verbs[op.key] ?? 'Kayıt'}: başka bir yerde değişti' : '${_verbs[op.key] ?? 'Kayıt'} gönderilemedi',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (conflict && server != null)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Side(title: 'Seninki', lines: describeRecord(op.values, wallet))),
            const SizedBox(width: 12),
            Expanded(child: _Side(title: 'Sunucudaki', lines: describeRecord(server, wallet))),
          ])
        else ...[
          Text(describeRecord(op.values, wallet).join(' · '), style: TextStyle(color: t.onBase)),
          if (op.detail != null) ...[
            const SizedBox(height: 6),
            Text(op.detail!, style: TextStyle(color: t.muted, fontSize: 12)),
          ],
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
            onPressed: () => repo.keepMine(op),
            child: Text(conflict ? 'Seninkini kullan' : 'Tekrar dene'),
          ),
          OutlinedButton(
            onPressed: () => repo.discard(op),
            child: Text(conflict ? 'Sunucudakini kullan' : 'Vazgeç'),
          ),
        ]),
      ]),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 4),
      for (final line in lines) Text(line, style: TextStyle(color: t.onBase)),
    ]);
  }
}
