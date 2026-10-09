import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../calendar/calendar_reminders.dart';
import '../calendar/calendar_store.dart';
import 'notifications.dart';

/// Payload of the last notification the user tapped; the shell navigates.
final notificationTapProvider = StateProvider<String?>((ref) => null);

final notificationPortProvider = FutureProvider<PluginNotificationPort?>((ref) => PluginNotificationPort.create(
      onTap: (payload) => ref.read(notificationTapProvider.notifier).state = payload,
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
