import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../calendar/calendar_reminders.dart';
import '../calendar/calendar_store.dart';
import '../household/household.dart';
import '../meds/med_reminders.dart';
import '../meds/meds_store.dart';
import '../wallet/payment_reminders.dart';
import '../wallet/wallet_store.dart';
import 'notifications.dart';
import 'reminder_sync.dart';

/// Reminders due between [from] (exclusive) and [to] (inclusive), from the
/// same planners that schedule the phone's notifications.
List<PlannedNotification> dueReminders({
  required DateTime from,
  required DateTime to,
  required List<PlannedNotification> Function(DateTime from) plan,
}) =>
    [for (final n in plan(from)) if (n.at.isAfter(from) && !n.at.isAfter(to)) n]..sort((a, b) => a.at.compareTo(b.at));

/// The reminder to show in the app right now, where the system cannot show
/// notifications (the web: only while the tab is open).
final inAppReminderProvider = StateProvider<PlannedNotification?>((ref) => null);

/// Checks every half minute for calendar, dose and payment reminders that
/// have come due, when there is no notification port.
final inAppReminderSyncProvider = Provider<void>((ref) {
  var last = DateTime.now();
  Timer? timer;
  Future<void> check() async {
    if (await ref.read(notificationPortProvider.future) != null) return;
    final now = DateTime.now();
    final due = dueReminders(
      from: last,
      to: now,
      plan: (from) => [
        ...planCalendarReminders(remindedHere(ref.read(localEventsProvider).value ?? const [], (e) => e.notify, ref.read(walletMeProvider)), from),
        ...planMedReminders(remindedHere(ref.read(localMedicationsProvider).value ?? const [], (m) => m.notify, ref.read(walletMeProvider)),
            ref.read(doseLogsProvider).value ?? const {}, from),
        ...planPaymentReminders(ref.read(walletProvider).value?.payments.values ?? const [], from),
      ],
    );
    last = now;
    for (final reminder in due) {
      ref.read(inAppReminderProvider.notifier).state = reminder;
    }
  }

  timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  ref.onDispose(() => timer?.cancel());
});
