import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Keeps every tab's navigator alive (like an IndexedStack) but swaps tabs
/// with a fade-through: the old tab fades out, then the new one settles in.
///
/// Each child keeps an identical wrapper structure in every state, so tab
/// navigators are never remounted and their back stacks survive.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1);
  int? _previous;
  var _generation = 0;

  @override
  void didUpdateWidget(FadeThroughBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previous = oldWidget.currentIndex;
    final reduce = LbTokens.of(context).reduceMotion || MediaQuery.disableAnimationsOf(context);
    _controller.duration = reduce ? Duration.zero : LbTokens.motion;
    final generation = ++_generation;
    _controller.forward(from: 0).whenCompleteOrCancel(() {
      // A newer switch may have started; only the latest one clears.
      if (mounted && generation == _generation) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++) _branch(i),
        ],
      );

  Widget _branch(int index) {
    final current = index == widget.currentIndex;
    final outgoing = index == _previous;
    final visible = current || outgoing;
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !current,
          child: FadeThroughTransition(
            animation: current ? _controller : kAlwaysCompleteAnimation,
            secondaryAnimation: outgoing ? _controller : kAlwaysDismissedAnimation,
            fillColor: Colors.transparent,
            child: KeyedSubtree(key: ValueKey(index), child: widget.children[index]),
          ),
        ),
      ),
    );
  }
}
