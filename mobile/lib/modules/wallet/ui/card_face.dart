import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import 'wallet_format.dart';

/// The card's surface at real card proportions (85.6 × 54 mm), in its
/// scheme's single colour.
class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.color, required this.child, this.dim = false});

  final String? color;
  final Widget child;

  /// The back: a veil so the details read clearly.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = schemeOf(color);
    final veil = (ink.computeLuminance() > .5 ? Colors.black : Colors.white).withValues(alpha: .18);
    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dim ? Color.alphaBlend(veil, fill) : fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
          boxShadow: [BoxShadow(color: fill.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: DefaultTextStyle(style: TextStyle(color: ink), child: child),
      ),
    );
  }
}

/// The front of a credit card: bank, last four digits, how much of the limit
/// is used, the statement dates and the network.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, required this.wallet, required this.now, this.onEdit, this.onReveal});

  final WalletAccount card;
  final WalletData wallet;
  final DateTime now;

  /// Shows an edit button on the card.
  final VoidCallback? onEdit;

  /// Shows an eye button that turns the card over to its details.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final (_, ink) = schemeOf(card.color);
    final muted = ink.withValues(alpha: .7);
    final close = nextClose(card, now);
    final dates = DateFormat('d MMM', 'tr_TR');
    final due = close == null || card.dueDay == null ? null : dueDateOf(close.close, card.dueDay!);
    final limit = card.limit;
    final used = card.debt;
    final share = limit == null || limit <= 0 ? null : (used / limit).clamp(0.0, 1.0);
    final label = TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6);

    return Semantics(
      label: '${card.name}, ${card.last4 == null ? '' : 'son dört hane ${card.last4}, '}'
          'kullanılan ${formatMoney(used)}${limit == null ? '' : ', limit ${formatMoney(limit)}'}',
      child: CardSurface(
        color: card.color,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text((card.bank ?? 'KART').toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: label.copyWith(color: ink, fontSize: 12, letterSpacing: 2.2)),
              ),
              if (card.shared) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.group_rounded, size: 18, color: muted)),
              if (card.sync != SyncMark.confirmed)
                Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.schedule_rounded, size: 16, color: muted)),
              if (onReveal != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: IconButton(
                    tooltip: 'Kart bilgilerini göster',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .22)),
                    color: ink,
                    iconSize: 18,
                    onPressed: onReveal,
                    icon: const Icon(Icons.visibility_rounded),
                  ),
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Kartı düzenle',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .22)),
                  color: ink,
                  iconSize: 18,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                )
              else
                const SizedBox(height: 40),
            ]),
            const Spacer(),
            Text('**** **** **** ${card.last4 ?? '****'}',
                style: TextStyle(color: ink, fontSize: 19, letterSpacing: 1.5, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            const Spacer(),
            if (share != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Text('${formatMoney(used, short: true)} kullanıldı', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 13))),
                  Text('Limit ${formatMoney(limit!, short: true)}', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    color: share > .9 ? const Color(0xFFE5484D) : ink,
                    backgroundColor: ink.withValues(alpha: .18),
                  ),
                ),
              ),
              if (card.available != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Kullanılabilir ${formatMoney(card.available!, short: true)}', style: TextStyle(color: muted, fontSize: 11)),
                  ),
                ),
            ] else
              Text('Borç ${formatMoney(used)}', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 13)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
                  if (close != null)
                    Text(
                      'Kesim ${dates.format(close.close)}${due == null ? '' : ' · Son ödeme ${dates.format(due)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 10.5),
                    ),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(right: 8, left: 8), child: NetworkMark(network: card.network, color: ink)),
            ]),
          ]),
        ),
      ),
    );
  }
}
