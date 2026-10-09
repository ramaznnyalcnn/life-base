import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import 'wallet_format.dart';

/// The front of a credit card at real card proportions (85.6 × 54 mm).
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, required this.wallet, required this.now});

  final WalletAccount card;
  final WalletData wallet;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (gradient, ink) = schemeOf(card.color);
    final muted = ink.withValues(alpha: .72);
    final period = statementsOf(card, wallet, now).where((s) => s.status == StatementStatus.open).firstOrNull;
    final close = nextClose(card, now);
    final dates = DateFormat('d MMM', 'tr_TR');
    final due = close == null || card.dueDay == null ? null : dueDateOf(close.close, card.dueDay!);

    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: Semantics(
        label: '${card.name}, ${card.last4 == null ? '' : 'son dört hane ${card.last4}, '}'
            'borç ${formatMoney(card.debt)}${card.available == null ? '' : ', kullanılabilir ${formatMoney(card.available!)}'}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
            boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: DefaultTextStyle(
              style: TextStyle(color: ink),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(card.bank ?? card.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  if (card.shared) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.group_rounded, size: 18, color: muted)),
                  if (card.sync != SyncMark.confirmed)
                    Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.schedule_rounded, size: 16, color: muted)),
                  NetworkMark(network: card.network, color: ink),
                ]),
                if (card.bank != null)
                  Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13)),
                const Spacer(),
                Text(card.last4 == null ? '•••• ••••' : '•••• ${card.last4}',
                    style: const TextStyle(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bu dönem', style: TextStyle(color: muted, fontSize: 11)),
                      Text(formatMoney(period?.spent ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                  ),
                  if (card.available != null)
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Kullanılabilir', style: TextStyle(color: muted, fontSize: 11)),
                        Text(formatMoney(card.available!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ),
                  if (close != null) _CloseRing(daysLeft: close.daysLeft, progress: close.progress, ink: ink),
                ]),
                if (close != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Kesim ${dates.format(close.close)}${due == null ? '' : ' · Son ödeme ${dates.format(due)}'}',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Days to the statement date, as a small ring that fills through the period.
class _CloseRing extends StatelessWidget {
  const _CloseRing({required this.daysLeft, required this.progress, required this.ink});
  final int daysLeft;
  final double progress;
  final Color ink;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: daysLeft == 0 ? 'Kesim bugün' : 'Kesime $daysLeft gün',
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 3.5,
              color: ink,
              backgroundColor: ink.withValues(alpha: .22),
            ),
            Text('${daysLeft}g', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 11)),
          ]),
        ),
      );
}
