import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/fade_through_branches.dart';
import '../core/routes.dart';
import '../modules/account/data/session_controller.dart';
import '../modules/account/ui/account_screen.dart';
import '../modules/calendar/ui/calendar_screen.dart';
import '../modules/meds/ui/dose_alarm_page.dart';
import '../modules/meds/ui/meds_screen.dart';
import '../modules/notes/ui/notes_screen.dart';
import '../modules/today/ui/today_screen.dart';
import '../modules/wallet/ui/wallet_screen.dart';
import 'app_shell.dart';

/// Each tab is a branch with its own navigator, so every module keeps its
/// own back stack. Account lives above the shell on the root navigator.
GoRouter buildRouter({String initialLocation = AppRoutes.today}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  GoRoute tab(String path, Widget screen) => GoRoute(path: path, builder: (context, state) => screen);
  // One per tab: tells the shell when a page is open on top of a module.
  final stacks = List.generate(shellDestinations.length, (_) => TabStackObserver());
  // Same order as shellDestinations: Cüzdan · Takvim · Bugün · İlaç · Notlar.
  final screens = {
    AppRoutes.wallet: const WalletScreen(),
    AppRoutes.calendar: const CalendarScreen(),
    AppRoutes.today: const TodayScreen(),
    AppRoutes.meds: const MedsScreen(),
    AppRoutes.notes: const NotesScreen(),
  }.entries.toList();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell, stacks: stacks),
        navigatorContainerBuilder: (context, shell, children) =>
            FadeThroughBranches(currentIndex: shell.currentIndex, children: children),
        branches: [
          for (var i = 0; i < screens.length; i++)
            StatefulShellBranch(observers: [stacks[i]], routes: [tab(screens[i].key, screens[i].value)]),
        ],
      ),
      GoRoute(
        path: AppRoutes.account,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.alarm}/:doseId',
        parentNavigatorKey: rootKey,
        builder: (context, state) => DoseAlarmPage(doseId: state.pathParameters['doseId']!),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // A fresh router per session, so signing in again starts on Bugün.
  ref.watch(sessionControllerProvider.select((session) => session.value?.ready ?? false));
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
