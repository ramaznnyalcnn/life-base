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

/// Hosts the four modules behind the glass navigation bar.
///
/// Back button order: pop inside the current tab (handled by go_router before
/// this scope is asked) → return to Bugün → press twice to leave the app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

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
          body: widget.shell,
          bottomNavigationBar: GlassNavBar(
            items: shellDestinations,
            currentIndex: widget.shell.currentIndex,
            onSelected: _select,
          ),
        ),
      );
}
