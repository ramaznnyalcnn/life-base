import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/platform/platform_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/wallet/card_secrets.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import 'card_face.dart';
import 'wallet_format.dart';

/// A card that turns over when tapped: to its details after the owner
/// unlocks them, or, when this phone holds none, to an offer to add them. It
/// turns back by itself after [showFor] or when the app goes to the background.
class SecureCard extends ConsumerStatefulWidget {
  const SecureCard({super.key, required this.card, required this.wallet, required this.now, this.onEdit, this.showFor = const Duration(seconds: 30)});

  final WalletAccount card;
  final WalletData wallet;
  final DateTime now;

  /// The card's edit button (and "Ekle" on a back without details).
  final VoidCallback? onEdit;
  final Duration showFor;

  @override
  ConsumerState<SecureCard> createState() => _SecureCardState();
}

class _SecureCardState extends ConsumerState<SecureCard> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AppLifecycleListener _lifecycle;
  // Read up front: ref is gone by dispose, when screenshots must be allowed again.
  late final PlatformBridge _bridge;
  CardSecrets? _secrets;

  /// Turned over to the back (with or without details).
  bool _turned = false;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _close);
    _bridge = ref.read(platformBridgeProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _turn.dispose();
    if (_secrets != null) _secure(false);
    super.dispose();
  }

  bool get _reduce => LbTokens.of(context).reduceMotion || MediaQuery.disableAnimationsOf(context);

  void _secure(bool on) => unawaited(_bridge.setSecure(on).catchError((Object _) {}));

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open() async {
    if (_busy) return;
    _busy = true;
    try {
      final store = ref.read(cardSecretsStoreProvider);
      final stored = store.supported && await store.has(widget.card.id).catchError((Object _) => false);
      if (!mounted) return;
      if (stored) {
        final problem = await ref.read(cardUnlockerProvider).unlock('${widget.card.name} kart bilgilerini göster');
        if (!mounted) return;
        if (problem != null) {
          _message(problem);
          return;
        }
        final secrets = await store.read(widget.card.id);
        if (!mounted || secrets == null) return;
        _secure(true);
        _secrets = secrets;
      }
      setState(() => _turned = true);
      _reduce ? _turn.value = 1 : await _turn.forward();
      _timer?.cancel();
      _timer = Timer(widget.showFor, _close);
    } finally {
      _busy = false;
    }
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!_turned || !mounted) return;
    _reduce ? _turn.value = 0 : await _turn.reverse();
    if (!mounted) return;
    final hadSecrets = _secrets != null;
    setState(() {
      _turned = false;
      _secrets = null;
    });
    if (hadSecrets) _secure(false);
  }

  @override
  Widget build(BuildContext context) {
    final front = CardFace(card: widget.card, wallet: widget.wallet, now: widget.now, onEdit: widget.onEdit);
    return Semantics(
      button: true,
      hint: _turned ? 'Kartı çevirmek için dokun' : 'Kart bilgilerini göstermek için dokun',
      child: GestureDetector(
        onTap: _turned ? _close : _open,
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) {
            final angle = Curves.easeInOutCubic.transform(_turn.value) * math.pi;
            final showBack = angle > math.pi / 2 && _turned;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _secrets == null
                          ? _MissingBack(card: widget.card, onAdd: ref.read(cardSecretsStoreProvider).supported ? widget.onEdit : null)
                          : CardBack(card: widget.card, secrets: _secrets!, onCopied: _message),
                    )
                  : front,
            );
          },
        ),
      ),
    );
  }
}

/// The back of the card: full number (copyable), expiry, CVV, holder and the
/// bank's phone number.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.card, required this.secrets, required this.onCopied});

  final WalletAccount card;
  final CardSecrets secrets;
  final ValueChanged<String> onCopied;

  @override
  Widget build(BuildContext context) {
    final (_, ink) = schemeOf(card.color);
    final muted = ink.withValues(alpha: .72);
    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );

    return CardSurface(
      color: card.color,
      dim: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
        child: DefaultTextStyle(
          style: TextStyle(color: ink),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.lock_open_rounded, size: 16, color: muted),
                  const SizedBox(width: 12),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        secrets.groupedNumber,
                        style: const TextStyle(fontSize: 21, letterSpacing: 1.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kart numarasını kopyala',
                    color: ink,
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: secrets.number));
                      onCopied('Kart numarası kopyalandı');
                    },
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  if (secrets.expiry != null) ...[field('SKT', secrets.expiry!), const SizedBox(width: 24)],
                  if (secrets.cvv != null) field('CVV', secrets.cvv!),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [if (secrets.holder != null) secrets.holder!, if (secrets.supportPhone != null) 'Müşteri hizmetleri ${secrets.supportPhone}'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The back of a card whose details are not on this phone.
class _MissingBack extends StatelessWidget {
  const _MissingBack({required this.card, required this.onAdd});
  final WalletAccount card;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final (_, ink) = schemeOf(card.color);
    return CardSurface(
      color: card.color,
      dim: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: ink),
            const SizedBox(height: 8),
            Text(
              onAdd == null ? 'Kart bilgileri yalnızca telefonda saklanır.' : 'Kart numarası, SKT ve CVV bu telefonda kayıtlı değil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Ekle')),
            ],
          ],
        ),
      ),
    );
  }
}
