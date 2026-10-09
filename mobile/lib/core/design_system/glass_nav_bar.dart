import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.module,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final LbModule module;
}

/// Floating "liquid glass" tab bar: a frosted, saturated capsule with a light
/// rim; every tab shows its icon and a small label, and a soft lens springs
/// behind the active one. Slide a finger along the bar and the lens follows,
/// ticking at each tab; let go to open it.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const height = 70.0;
  static const _inner = 5.0;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 420, damping: 30);

  /// Lens position in tabs (0 = first); fractional while moving.
  late final AnimationController _lens = AnimationController.unbounded(vsync: this, value: widget.currentIndex.toDouble());
  bool _pressed = false;
  bool _dragging = false;
  int? _hovered;

  bool get _reduce => LbTokens.of(context).reduceMotion || MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.currentIndex != widget.currentIndex) _settle(widget.currentIndex);
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  void _settle(int index) {
    if (_reduce) {
      _lens.value = index.toDouble();
    } else {
      _lens.animateWith(SpringSimulation(_spring, _lens.value, index.toDouble(), _lens.velocity));
    }
  }

  int _indexAt(double dx, double slot) => (dx / slot).floor().clamp(0, widget.items.length - 1);

  void _select(int index) {
    _settle(index);
    if (index != widget.currentIndex) widget.onSelected(index);
  }

  void _follow(double dx, double slot) {
    final index = _indexAt(dx, slot);
    if (index != _hovered) {
      _hovered = index;
      HapticFeedback.selectionClick();
    }
    final target = ((dx - slot / 2) / slot).clamp(0.0, widget.items.length - 1.0);
    if (_reduce) {
      _lens.value = index.toDouble();
    } else {
      _lens.value = target;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(GlassNavBar.height / 2));

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(color: t.shade.withValues(alpha: dark ? .55 : .35), blurRadius: 30, offset: const Offset(0, 12)),
              BoxShadow(color: t.shade.withValues(alpha: dark ? .35 : .18), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              // Frosted and a little more saturated than what is behind it.
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                inner: const ColorFilter.matrix(_saturate),
              ),
              child: CustomPaint(
                foregroundPainter: _GlassRim(dark: dark),
                child: Container(
                  height: GlassNavBar.height,
                  padding: const EdgeInsets.all(GlassNavBar._inner),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(Colors.white.withValues(alpha: dark ? .06 : .22), t.glass),
                        t.glass,
                      ],
                    ),
                  ),
                  child: LayoutBuilder(builder: (context, constraints) => _content(context, constraints.maxWidth)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, double width) {
    final t = LbTokens.of(context);
    final items = widget.items;
    final slot = width / items.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (details) {
        setState(() => _pressed = false);
        _select(_indexAt(details.localPosition.dx, slot));
      },
      onHorizontalDragStart: (details) {
        setState(() {
          _pressed = true;
          _dragging = true;
          _hovered = widget.currentIndex;
        });
        _lens.stop();
        _follow(details.localPosition.dx, slot);
      },
      onHorizontalDragUpdate: (details) => _follow(details.localPosition.dx, slot),
      onHorizontalDragEnd: (_) {
        final index = _lens.value.round().clamp(0, items.length - 1);
        setState(() {
          _pressed = false;
          _dragging = false;
          _hovered = null;
        });
        _select(index);
      },
      child: AnimatedBuilder(
        animation: _lens,
        builder: (context, _) {
          final position = _lens.value;
          final nearest = position.round().clamp(0, items.length - 1);
          final active = t.module(items[nearest].module);
          // Stretch most halfway between two tabs, like a drop of liquid.
          final between = (position - position.roundToDouble()).abs();
          final stretch = _reduce ? 1.0 : 1 + .24 * between;
          return Stack(children: [
            Positioned(
              left: slot * position,
              top: 0,
              bottom: 0,
              width: slot,
              child: AnimatedScale(
                scale: _pressed && !_reduce ? 1.06 : 1,
                duration: LbTokens.motionShort,
                curve: LbTokens.curve,
                child: Transform.scale(scaleX: stretch, child: _Lens(color: active)),
              ),
            ),
            Row(children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: slot,
                  child: _Tab(
                    item: items[i],
                    selected: i == nearest,
                    color: i == nearest ? active : t.muted,
                    onTap: () => _select(i),
                  ),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// Saturation ×1.4 (keeps luminance).
const _saturate = <double>[
  1.2546, -0.2146, -0.0400, 0, 0, //
  -0.0854, 1.1254, -0.0400, 0, 0, //
  -0.0854, -0.2146, 1.3000, 0, 0, //
  0, 0, 0, 1, 0,
];

class _Lens extends StatelessWidget {
  const _Lens({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = LbTokens.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(GlassNavBar.height)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: dark ? .08 : .35), color.withValues(alpha: .16)),
            color.withValues(alpha: .16),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
    );
  }
}

/// A light catching the top-left edge of the glass and fading out.
class _GlassRim extends CustomPainter {
  const _GlassRim({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? .32 : .85),
          Colors.white.withValues(alpha: dark ? .04 : .18),
          Colors.white.withValues(alpha: dark ? .12 : .4),
        ],
        stops: const [0, .55, 1],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(.6), Radius.circular(size.height / 2)), paint);
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) => oldDelegate.dark != dark;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.color, required this.onTap});

  final GlassNavItem item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: item.label,
        onTap: onTap,
        excludeSemantics: true,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: LbTokens.motionShort,
                curve: LbTokens.curve,
                child: Icon(selected ? item.selectedIcon : item.icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: .1,
                ),
              ),
            ]),
          ),
        ),
      );
}
