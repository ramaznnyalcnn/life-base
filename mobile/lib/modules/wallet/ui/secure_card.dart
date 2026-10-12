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

/// A card that turns over to its details after the owner unlocks them, and
/// turns back by itself after [showFor] or when the app goes to the background.
class SecureCard extends ConsumerStatefulWidget {
  const SecureCard({super.key, required this.card, required this.wallet, required this.now, this.showFor = const Duration(seconds: 30)});

  final WalletAccount card;
  final WalletData wallet;
  final DateTime now;
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
    final store = ref.read(cardSecretsStoreProvider);
    if (!store.supported) {
      _message('Kart bilgileri yalnızca telefonda saklanır.');
      return;
    }
    if (!await store.has(widget.card.id)) {
      _message('Bu kartın bilgileri bu cihazda kayıtlı değil. Düzenle\'den ekleyebilirsin.');
      return;
    }
    _busy = true;
    try {
      final problem = await ref.read(cardUnlockerProvider).unlock('${widget.card.name} kart bilgilerini göster');
      if (!mounted) return;
      if (problem != null) {
        _message(problem);
        return;
      }
      final secrets = await store.read(widget.card.id);
      if (!mounted || secrets == null) return;
      _secure(true);
      setState(() => _secrets = secrets);
      _reduce ? _turn.value = 1 : await _turn.forward();
      _timer?.cancel();
      _timer = Timer(widget.showFor, _close);
    } finally {
      _busy = false;
    }
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (_secrets == null || !mounted) return;
    _reduce ? _turn.value = 0 : await _turn.reverse();
    if (!mounted) return;
    setState(() => _secrets = null);
    _secure(false);
  }

  @override
  Widget build(BuildContext context) {
    final front = CardFace(card: widget.card, wallet: widget.wallet, now: widget.now);
    return Semantics(
      button: true,
      hint: _secrets == null ? 'Kart bilgilerini göstermek için dokun' : 'Kartı kapatmak için dokun',
      child: GestureDetector(
        onTap: _secrets == null ? _open : _close,
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) {
            final angle = Curves.easeInOutCubic.transform(_turn.value) * math.pi;
            final showBack = angle > math.pi / 2 && _secrets != null;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: CardBack(card: widget.card, secrets: _secrets!, onCopied: _message),
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
    final (gradient, ink) = schemeOf(card.color);
    final muted = ink.withValues(alpha: .72);
    Widget field(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: muted, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, fontFeatures: [FontFeature.tabularFigures()])),
        ]);

    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: gradient),
          boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
          child: DefaultTextStyle(
            style: TextStyle(color: ink),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontWeight: FontWeight.w700))),
                Icon(Icons.lock_open_rounded, size: 16, color: muted),
                const SizedBox(width: 12),
              ]),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(secrets.groupedNumber,
                        style: const TextStyle(fontSize: 21, letterSpacing: 1.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
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
              ]),
              const Spacer(),
              Row(children: [
                if (secrets.expiry != null) ...[field('SKT', secrets.expiry!), const SizedBox(width: 24)],
                if (secrets.cvv != null) field('CVV', secrets.cvv!),
              ]),
              const SizedBox(height: 6),
              Text(
                [if (secrets.holder != null) secrets.holder!, if (secrets.supportPhone != null) 'Müşteri hizmetleri ${secrets.supportPhone}'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
