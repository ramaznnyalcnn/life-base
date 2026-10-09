import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum NotificationChannel {
  calendar('calendar', 'Takvim hatırlatmaları', Importance.defaultImportance),
  calendarHigh('calendar_high', 'Önemli takvim hatırlatmaları', Importance.high);

  const NotificationChannel(this.id, this.label, this.importance);
  final String id;
  final String label;
  final Importance importance;
}

/// A notification the app wants to exist at [at].
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.group,
    required this.key,
    required this.title,
    required this.body,
    required this.at,
    this.channel = NotificationChannel.calendar,
  });

  /// Owner, e.g. `cal`; reconciling one group never touches another.
  final String group;

  /// Stable identity within the group (event occurrence + reminder index).
  final String key;
  final String title;
  final String body;
  final DateTime at;
  final NotificationChannel channel;

  int get id => notificationId('$group|$key');

  /// Encodes everything that should trigger a reschedule when it changes.
  String get payload => '$group|$key|${at.millisecondsSinceEpoch}|${channel.id}|${Object.hash(title, body)}';
}

/// FNV-1a: unlike String.hashCode it is stable across app runs, so the same
/// reminder keeps the same Android notification id.
int notificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

abstract interface class NotificationPort {
  Future<List<({int id, String? payload})>> pending();
  Future<void> schedule(PlannedNotification notification);
  Future<void> cancel(int id);
}

/// Makes the scheduled notifications of [group] match [desired]: cancels
/// stale ones, schedules missing or changed ones, leaves the rest alone.
Future<void> reconcileNotifications(NotificationPort port, String group, List<PlannedNotification> desired) async {
  final wanted = {for (final n in desired) n.id: n};
  final existing = {
    for (final p in await port.pending())
      if (p.payload?.startsWith('$group|') ?? false) p.id: p.payload,
  };
  for (final entry in existing.entries) {
    final keep = wanted[entry.key];
    if (keep == null || keep.payload != entry.value) await port.cancel(entry.key);
  }
  for (final notification in desired) {
    if (existing[notification.id] != notification.payload) await port.schedule(notification);
  }
}

/// Android implementation backed by flutter_local_notifications.
class PluginNotificationPort implements NotificationPort {
  PluginNotificationPort._(this._plugin, this.exactAlarms);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Without the exact-alarm grant reminders may arrive a few minutes late.
  final bool exactAlarms;

  static Future<PluginNotificationPort?> create({void Function(String? payload)? onTap}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } on Object {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
    );
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    for (final channel in NotificationChannel.values) {
      await android.createNotificationChannel(AndroidNotificationChannel(channel.id, channel.label, importance: channel.importance));
    }
    await android.requestNotificationsPermission();
    final exact = await android.canScheduleExactNotifications() ?? false;
    return PluginNotificationPort._(plugin, exact);
  }

  /// Opens the system screen for the exact-alarm grant.
  Future<void> requestExactAlarms() async =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

  @override
  Future<List<({int id, String? payload})>> pending() async =>
      [for (final p in await _plugin.pendingNotificationRequests()) (id: p.id, payload: p.payload)];

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> schedule(PlannedNotification n) => _plugin.zonedSchedule(
        n.id,
        n.title,
        n.body,
        tz.TZDateTime.from(n.at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            n.channel.id,
            n.channel.label,
            importance: n.channel.importance,
            priority: n.channel == NotificationChannel.calendarHigh ? Priority.high : Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
            styleInformation: BigTextStyleInformation(n.body),
          ),
        ),
        androidScheduleMode: exactAlarms ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: n.payload,
      );
}
