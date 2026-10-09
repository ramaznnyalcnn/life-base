import 'dart:ui';

import 'package:flutter/material.dart';

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

/// Floating frosted-glass capsule. A soft bubble glides behind the active
/// destination; only the active destination shows its label.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const height = 66.0;
  static const _inner = 6.0;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final active = t.module(items[currentIndex].module);
    final duration = t.reduceMotion ? Duration.zero : LbTokens.motion;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: t.shade.withValues(alpha: t.brightness == Brightness.dark ? .7 : .45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: height,
                padding: const EdgeInsets.all(_inner),
                decoration: BoxDecoration(
                  color: t.glass,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(color: t.glassBorder),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final slot = constraints.maxWidth / items.length;
                  return Stack(children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: LbTokens.curve,
                      left: slot * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: slot,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: LbTokens.curve,
                        decoration: BoxDecoration(
                          color: active.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(height / 2),
                          border: Border.all(color: active.withValues(alpha: .22)),
                        ),
                      ),
                    ),
                    Row(children: [
                      for (var i = 0; i < items.length; i++)
                        SizedBox(
                          width: slot,
                          child: _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            color: i == currentIndex ? active : t.muted,
                            duration: duration,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ]),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.color,
    required this.duration,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color color;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: duration,
                  builder: (context, value, _) =>
                      Icon(selected ? item.selectedIcon : item.icon, color: value, size: 23),
                ),
                AnimatedSize(
                  duration: duration,
                  curve: LbTokens.curve,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ),
      );
}
