import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/calendar/google_projection.dart';
import 'core/design_system/app_theme.dart';
import 'core/design_system/appearance.dart';
import 'core/notifications/reminder_sync.dart';
import 'core/sync/sync_controller.dart';
import 'modules/account/data/session_controller.dart';
import 'modules/calendar/data/server_import.dart';
import 'modules/account/ui/onboarding_screen.dart';
import 'shell/notification_handler.dart';
import 'shell/router.dart';

/// Turkish pickers, dialogs and number formats everywhere.
const _locale = Locale('tr', 'TR');
const _localizations = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class LifeBaseApp extends ConsumerWidget {
  const LifeBaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final reduceMotion = appearance.reduceMotion ||
        SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final light = AppTheme.build(appearance.palette, Brightness.light, reduceMotion: reduceMotion);
    final dark = AppTheme.build(appearance.palette, Brightness.dark, reduceMotion: reduceMotion);
    final mode = appearance.palette.darkOnly ? ThemeMode.dark : appearance.mode;
    final session = ref.watch(sessionControllerProvider);

    // The router only exists for a signed-in session; signing in or out swaps
    // the whole app frame instead of redirecting inside it.
    final ready = session.value?.ready ?? false;
    if (ready) {
      // Keeps local-first data syncing for as long as the session lasts,
      // without rebuilding the app on every sync status change.
      ref.listen(syncControllerProvider, (_, _) {});
      // Local reminders work offline; they are re-planned whenever events change.
      ref.listen(calendarReminderSyncProvider, (_, _) {});
      ref.listen(googleProjectionProvider, (_, _) {});
      ref.listen(serverCalendarImportProvider, (_, _) {});
      ref.listen(medReminderSyncProvider, (_, _) {});
      ref.listen(paymentReminderSyncProvider, (_, _) {});
      ref.listen(notificationTapProvider, (_, tap) {
        if (tap != null) handleNotificationTap(ref, tap);
      });
      return MaterialApp.router(
        title: 'LifeBase',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: const [_locale],
        localizationsDelegates: _localizations,
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        routerConfig: ref.watch(routerProvider),
      );
    }
    return MaterialApp(
      title: 'LifeBase',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: _localizations,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      home: session.isLoading && !session.hasValue
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const OnboardingScreen(),
    );
  }
}
