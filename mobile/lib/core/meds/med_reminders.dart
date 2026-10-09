import 'package:intl/intl.dart';

import '../notifications/notifications.dart';
import '../storage/app_database.dart';
import 'medication.dart';
import 'meds_store.dart';

const medNotificationGroup = 'med';

/// Notification buttons on a dose alarm.
const doseActions = [('take', 'Aldım'), ('snooze', 'Ertele'), ('skip', 'Atla')];

/// Alarms for unanswered doses in the next [horizon]: one at the dose time
/// (or when a snooze ends), then a reminder every `repeatEveryMinutes`, up to
/// `maxRepeats` times. Answered doses ring no more.
List<PlannedNotification> planMedReminders(
  List<Medication> meds,
  Map<String, LocalDoseLog> logs,
  DateTime now, {
  Duration horizon = const Duration(days: 3),
  int max = 150,
}) {
  final planned = <PlannedNotification>[];
  final entries = doseEntries(meds, logs, now.subtract(const Duration(hours: 3)), now.add(horizon), now);
  for (final entry in entries) {
    if (entry.status == DoseStatus.taken || entry.status == DoseStatus.skipped) continue;
    final med = entry.dose.medication;
    final snoozedUntil = entry.status == DoseStatus.snoozed ? entry.log!.snoozedUntil!.toLocal() : null;
    final first = snoozedUntil ?? entry.dose.at;
    for (var i = 0; i <= med.alarm.maxRepeats; i++) {
      final at = first.add(Duration(minutes: med.alarm.repeatEveryMinutes * i));
      if (!at.isAfter(now)) continue;
      planned.add(PlannedNotification(
        group: medNotificationGroup,
        key: '${entry.dose.id}#$i',
        title: med.name,
        body: doseAlarmBody(entry.dose, repeat: i > 0 || snoozedUntil != null),
        at: at,
        channel: NotificationChannel.medsAlarm,
        fullScreen: med.alarm.fullScreen,
        actions: doseActions,
      ));
    }
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned.take(max).toList();
}

/// "1 tablet · Yemekten sonra · 09:00" (repeats start with "Hâlâ alınmadı").
String doseAlarmBody(ScheduledDose dose, {bool repeat = false}) {
  final med = dose.medication;
  final parts = [
    if (repeat) 'Hâlâ alınmadı',
    med.doseLabel,
    if (med.mealRelation != null) mealRelations[med.mealRelation] ?? med.mealRelation!,
    DateFormat('HH:mm').format(dose.at),
  ];
  final note = med.notes?.trim();
  return note == null || note.isEmpty ? parts.join(' · ') : '${parts.join(' · ')}\n$note';
}

/// Ids of dose alarms still on screen (ringing) whose dose has been answered
/// since: taken, skipped or snoozed doses stop ringing everywhere. Matched by
/// id, since every ring's id derives from its dose id.
List<int> answeredShownAlarms(List<int> shown, Map<String, LocalDoseLog> logs, DateTime now) {
  final onScreen = shown.toSet();
  if (onScreen.isEmpty) return const [];
  final since = now.subtract(const Duration(days: 1));
  return [
    for (final log in logs.values)
      if (log.deletedAtMs == null && log.scheduledFor.isAfter(since) && _answered(log, now))
        for (var i = 0; i <= maxAlarmRepeats; i++)
          if (notificationId('$medNotificationGroup|${log.id}#$i') case final id when onScreen.contains(id)) id,
  ];
}

bool _answered(LocalDoseLog log, DateTime now) =>
    log.status == 'taken' || log.status == 'skipped' || (log.status == 'snoozed' && (log.snoozedUntil?.isAfter(now) ?? false));

/// Dose id inside a med notification payload (`med|<doseId>#<n>|...`).
String? doseIdFromPayload(String payload) {
  final parts = payload.split('|');
  if (parts.length < 2 || parts.first != medNotificationGroup) return null;
  return parts[1].split('#').first;
}
