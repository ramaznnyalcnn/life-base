import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final routerProvider = Provider<GoRouter>((ref) => GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const SessionGate()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ]));

class LifeBaseApp extends ConsumerWidget {
  const LifeBaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'LifeBase',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
      );
}

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const OnboardingScreen(),
      data: (value) => value.ready ? const AppShell() : const OnboardingScreen(),
    );
  }
}
