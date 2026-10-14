import 'package:flutter/material.dart';

/// Fades and slides its content in the first time it scrolls into view.
/// [builder] gets the same 0→1 animation, so charts inside can draw in step.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({super.key, required this.builder});

  final Widget Function(BuildContext context, Animation<double> reveal) builder;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _controller.status != AnimationStatus.dismissed) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.92) _controller.forward();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(_curve),
          child: widget.builder(context, _curve),
        ),
      );
}
