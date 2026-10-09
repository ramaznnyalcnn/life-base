import 'package:flutter/material.dart';

import 'tokens.dart';

List<BoxShadow> neuShadows(LbTokens t, {double depth = LbTokens.depth}) {
  if (depth <= 0) return const [];
  final dark = t.brightness == Brightness.dark;
  return [
    BoxShadow(
      color: t.shade.withValues(alpha: dark ? .9 : .75),
      offset: Offset(depth * .7, depth * .7),
      blurRadius: depth * 2.2,
    ),
    BoxShadow(
      color: t.highlight.withValues(alpha: dark ? .55 : .9),
      offset: Offset(-depth * .7, -depth * .7),
      blurRadius: depth * 2.2,
    ),
  ];
}

/// A raised (or, with [sunken], recessed) soft surface.
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = LbTokens.radius,
    this.depth = LbTokens.depth,
    this.sunken = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double depth;
  final bool sunken;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Container(
      padding: padding,
      decoration: neuDecoration(t, radius: radius, depth: depth, sunken: sunken, color: color),
      child: child,
    );
  }
}

BoxDecoration neuDecoration(
  LbTokens t, {
  double radius = LbTokens.radius,
  double depth = LbTokens.depth,
  bool sunken = false,
  Color? color,
}) {
  final fill = color ?? t.base;
  if (sunken) {
    // Flutter has no inset shadow; a concave gradient reads as pressed-in.
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(fill, t.shade, .35)!, Color.lerp(fill, t.highlight, .35)!],
      ),
    );
  }
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: neuShadows(t, depth: depth),
  );
}

/// Soft button that sinks into the surface while pressed.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.radius = LbTokens.radiusSmall,
    this.semanticLabel,
    this.color,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;
  final Color? color;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  var _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: t.reduceMotion ? Duration.zero : LbTokens.motionShort,
          curve: LbTokens.curve,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: widget.padding,
          decoration: neuDecoration(
            t,
            radius: widget.radius,
            depth: enabled ? (_pressed ? 0 : LbTokens.depth * .7) : 0,
            sunken: _pressed,
            color: widget.color,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: IconTheme.merge(
              data: IconThemeData(color: enabled ? t.onBase : t.muted),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: enabled ? t.onBase : t.muted,
                  fontWeight: FontWeight.w700,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
