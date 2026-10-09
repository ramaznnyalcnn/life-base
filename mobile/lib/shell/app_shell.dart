import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/glass_nav_bar.dart';
import '../core/design_system/tokens.dart';

const shellDestinations = [
  GlassNavItem(
    label: 'Bugün',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny_rounded,
    module: LbModule.today,
  ),
  GlassNavItem(
    label: 'Cüzdan',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    module: LbModule.wallet,
  ),
  GlassNavItem(
    label: 'Takvim',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    module: LbModule.calendar,
  ),
  GlassNavItem(
    label: 'İlaç',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication_rounded,
    module: LbModule.meds,
  ),
];

/// Tracks whether a tab's navigator has a page open above the module root.
class TabStackObserver extends NavigatorObserver {
  final nested = ValueNotifier(false);

  void _update() => WidgetsBinding.instance.addPostFrameCallback((_) => nested.value = navigator?.canPop() ?? false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update();
}

/// Hosts the four modules behind the glass navigation bar.
///
/// Back button order: pop inside the current tab (handled by go_router before
/// this scope is asked) → return to Bugün → press twice to leave the app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell, this.stacks = const []});

  final StatefulNavigationShell shell;

  /// Per-tab stack observers; the bar steps aside while a page is open.
  final List<TabStackObserver> stacks;

  static const exitWindow = Duration(seconds: 2);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBack;

  void _select(int index) {
    // Tapping the active tab again returns it to its first page.
    widget.shell.goBranch(index, initialLocation: index == widget.shell.currentIndex);
  }

  void _handleBack() {
    if (widget.shell.currentIndex != 0) {
      widget.shell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < AppShell.exitWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Çıkmak için tekrar bas'),
        duration: AppShell.exitWindow,
      ));
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          extendBody: true,
          // A tab navigator reports "cannot pop" once its last page closes.
          // The shell always handles back (switch tab or confirm exit), so
          // Android must never be told otherwise, or predictive back closes
          // the app without asking Flutter.
          body: NotificationListener<NavigationNotification>(
            onNotification: (notification) {
              if (notification.canHandlePop) return false;
              const NavigationNotification(canHandlePop: true).dispatch(context);
              return true;
            },
            child: widget.shell,
          ),
          bottomNavigationBar: _HidingBar(
            hidden: widget.stacks.length > widget.shell.currentIndex ? widget.stacks[widget.shell.currentIndex].nested : null,
            child: GlassNavBar(
              items: shellDestinations,
              currentIndex: widget.shell.currentIndex,
              onSelected: _select,
            ),
          ),
        ),
      );
}

/// Slides the bar away (like a chat opening over a list) while [hidden].
class _HidingBar extends StatelessWidget {
  const _HidingBar({required this.hidden, required this.child});

  final ValueListenable<bool>? hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = hidden;
    if (listenable == null) return child;
    final reduce = LbTokens.of(context).reduceMotion || MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, isHidden, _) => AnimatedSize(
        duration: reduce ? Duration.zero : LbTokens.motion,
        curve: LbTokens.curve,
        alignment: Alignment.topCenter,
        child: isHidden ? const SizedBox(width: double.infinity) : child,
      ),
    );
  }
}
