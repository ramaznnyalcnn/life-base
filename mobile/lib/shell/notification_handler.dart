import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar/calendar_reminders.dart';
import '../core/meds/med_reminders.dart';
import '../core/meds/meds_store.dart';
import '../core/notifications/reminder_sync.dart';
import '../core/providers.dart';
import '../core/routes.dart';
import '../core/wallet/payment_reminders.dart';
import 'router.dart';

/// Routes a tapped notification: calendar reminders open Takvim, payment
/// reminders Cüzdan; dose alarm
/// buttons record the answer, and the alarm itself opens the full-screen page.
Future<void> handleNotificationTap(WidgetRef ref, NotificationTap tap) async {
  final router = ref.read(routerProvider);
  if (tap.payload.startsWith('$calendarNotificationGroup|')) {
    router.go(AppRoutes.calendar);
    return;
  }
  if (tap.payload.startsWith('$paymentNotificationGroup|')) {
    router.go(AppRoutes.wallet);
    return;
  }
  final doseId = doseIdFromPayload(tap.payload);
  if (doseId == null) return;
  final dose = await findDose(ref.read(databaseProvider), doseId);
  if (dose == null) return;
  final actions = ref.read(doseActionsProvider);
  switch (tap.actionId) {
    case 'take':
      await actions.take(dose);
    case 'skip':
      await actions.skip(dose);
    case 'snooze':
      await actions.snooze(dose, dose.medication.alarm.snoozeMinutes);
    default:
      // `go`, not `push`: the full-screen intent and a later tap on the same
      // notification must not stack two alarm pages.
      router.go('${AppRoutes.alarm}/${Uri.encodeComponent(doseId)}');
      return;
  }
  // A button answered the alarm; the app must not stay above the lock screen.
  await ref.read(platformBridgeProvider).setShowOverLockScreen(false).catchError((Object _) {});
  router.go(AppRoutes.meds);
}
