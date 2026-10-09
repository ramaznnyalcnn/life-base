import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../calendar/calendar_reminders.dart';
import '../calendar/calendar_store.dart';
import '../meds/med_reminders.dart';
import '../meds/meds_store.dart';
import '../providers.dart';
import 'notifications.dart';

/// The last notification (or notification button) the user tapped, or a
/// dose alarm that rang while the app was open.
typedef NotificationTap = ({String? actionId, String payload, int at});

final notificationTapProvider = StateProvider<NotificationTap?>((ref) => null);

final notificationPortProvider = FutureProvider<PluginNotificationPort?>((ref) => PluginNotificationPort.create(
      onTap: (actionId, payload) {
        if (payload == null) return;
        ref.read(notificationTapProvider.notifier).state =
            (actionId: actionId, payload: payload, at: DateTime.now().microsecondsSinceEpoch);
      },
    ));

/// Keeps scheduled calendar reminders in step with local events: after any
/// change, and on resume so the rolling window moves forward.
final calendarReminderSyncProvider = Provider<void>((ref) {
  Timer? debounce;
  Future<void> run() async {
    final port = await ref.read(notificationPortProvider.future);
    final events = ref.read(localEventsProvider).value;
    if (port == null || events == null) return;
    await reconcileNotifications(port, calendarNotificationGroup, planCalendarReminders(events, DateTime.now()));
  }

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), run);
  }

  ref.listen(localEventsProvider, (_, next) {
    if (next.hasValue) schedule();
  }, fireImmediately: true);
  final lifecycle = AppLifecycleListener(onResume: schedule);
  ref.onDispose(() {
    debounce?.cancel();
    lifecycle.dispose();
  });
});

/// Keeps dose alarms in step with medications and dose logs. While the app
/// is open, Android neither opens the full-screen alarm nor always shows a
/// heads-up, so the alarm page is opened in-app at each ring.
final medReminderSyncProvider = Provider<void>((ref) {
  Timer? debounce;
  Timer? nextRing;
  late void Function() schedule;
  Future<void> run() async {
    final port = await ref.read(notificationPortProvider.future);
    final meds = ref.read(localMedicationsProvider).value;
    final logs = ref.read(doseLogsProvider).value;
    if (port == null || meds == null || logs == null) return;
    final now = DateTime.now();
    // Silence answered alarms first: a snoozed dose's next ring reuses the
    // id of the one on screen, and cancelling afterwards would drop it.
    for (final id in answeredShownAlarms(await port.shown(), logs, now)) {
      await port.cancel(id);
    }
    final planned = planMedReminders(meds, logs, now);
    await reconcileNotifications(port, medNotificationGroup, planned);
    nextRing?.cancel();
    final next = planned.where((n) => n.at.isAfter(now)).firstOrNull;
    if (next == null) return;
    nextRing = Timer(next.at.difference(now), () {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ref.read(notificationTapProvider.notifier).state =
            (actionId: null, payload: next.payload, at: DateTime.now().microsecondsSinceEpoch);
      }
      schedule();
    });
  }

  schedule = () {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), run);
  };

  ref.listen(localMedicationsProvider, (_, next) {
    if (next.hasValue) schedule();
  }, fireImmediately: true);
  ref.listen(doseLogsProvider, (_, next) {
    if (next.hasValue) schedule();
  }, fireImmediately: true);
  final lifecycle = AppLifecycleListener(onResume: schedule);
  ref.onDispose(() {
    debounce?.cancel();
    nextRing?.cancel();
    lifecycle.dispose();
  });
});

/// What Android currently allows for reminders and dose alarms.
typedef AlarmPermissions = ({bool notifications, bool exact, bool fullScreen});

/// Re-read on every resume, since all three change in system settings. When
/// the exact-alarm grant changes, every reminder is set again in the new mode.
final alarmPermissionsProvider = FutureProvider<AlarmPermissions?>((ref) async {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  final port = await ref.watch(notificationPortProvider.future);
  if (port == null) return null;
  if (await port.refreshExactAlarms()) {
    await port.cancelAllPending();
    ref.invalidate(calendarReminderSyncProvider);
    ref.invalidate(medReminderSyncProvider);
  }
  return (
    notifications: await port.notificationsEnabled(),
    exact: port.exactAlarms,
    fullScreen: await ref.read(platformBridgeProvider).canUseFullScreenIntent().catchError((Object _) => true),
  );
});
