import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum NotificationChannel {
  calendar('calendar', 'Takvim hatırlatmaları', Importance.defaultImportance),
  calendarHigh('calendar_high', 'Önemli takvim hatırlatmaları', Importance.high),

  /// Rings with the alarm sound and alarm volume, like a clock alarm.
  medsAlarm('meds_alarm', 'İlaç alarmları', Importance.max);

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
    this.fullScreen = false,
    this.actions = const [],
  });

  /// Owner, e.g. `cal`; reconciling one group never touches another.
  final String group;

  /// Stable identity within the group (event occurrence + reminder index).
  final String key;
  final String title;
  final String body;
  final DateTime at;
  final NotificationChannel channel;

  /// Opens over the lock screen (alarm-style).
  final bool fullScreen;

  /// Buttons as (action id, label); tapping one opens the app to handle it.
  final List<(String, String)> actions;

  int get id => notificationId('$group|$key');

  /// Encodes everything that should trigger a reschedule when it changes.
  String get payload => '$group|$key|${at.millisecondsSinceEpoch}|${channel.id}|${Object.hash(title, body, fullScreen)}';
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

  /// Notifications currently on screen (already fired).
  Future<List<({int id, String? payload})>> shown();
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
  PluginNotificationPort._(this._plugin, this._exactAlarms);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Without the exact-alarm grant reminders may arrive a few minutes late.
  bool get exactAlarms => _exactAlarms;
  bool _exactAlarms;

  AndroidFlutterLocalNotificationsPlugin get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;

  /// Re-reads the exact-alarm grant (it changes in system settings); true
  /// when it changed since the last read.
  Future<bool> refreshExactAlarms() async {
    final exact = await _android.canScheduleExactNotifications() ?? false;
    final changed = exact != _exactAlarms;
    _exactAlarms = exact;
    return changed;
  }

  /// Scheduled alarms keep the mode they were set with; after a grant change
  /// everything is cleared so reconciling sets it again.
  Future<void> cancelAllPending() => _plugin.cancelAllPendingNotifications();

  static Future<PluginNotificationPort?> create({void Function(String? actionId, String? payload)? onTap}) async {
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
      onDidReceiveNotificationResponse: (response) => onTap?.call(response.actionId, response.payload),
    );
    // The app may have been started by tapping a notification. Handled once
    // per process: the port is rebuilt after permission changes.
    final launch = await plugin.getNotificationAppLaunchDetails();
    if ((launch?.didNotificationLaunchApp ?? false) && !_launchHandled) {
      _launchHandled = true;
      onTap?.call(launch!.notificationResponse?.actionId, launch.notificationResponse?.payload);
    }
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    for (final channel in NotificationChannel.values) {
      final alarm = channel == NotificationChannel.medsAlarm;
      await android.createNotificationChannel(AndroidNotificationChannel(
        channel.id,
        channel.label,
        importance: channel.importance,
        sound: alarm ? _alarmSound : null,
        audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ));
    }
    await android.requestNotificationsPermission();
    final exact = await android.canScheduleExactNotifications() ?? false;
    return PluginNotificationPort._(plugin, exact);
  }

  static var _launchHandled = false;

  static const _alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

  /// Android 14+ may require the user to allow alarm-style full-screen alerts.
  Future<void> requestFullScreen() async => _android.requestFullScreenIntentPermission();

  Future<bool> notificationsEnabled() async => await _android.areNotificationsEnabled() ?? false;

  /// Asks for (or, once refused, cannot re-ask) the notification permission.
  Future<void> requestNotifications() async => _android.requestNotificationsPermission();

  /// Opens the system screen for the exact-alarm grant.
  Future<void> requestExactAlarms() async => _android.requestExactAlarmsPermission();

  @override
  Future<List<({int id, String? payload})>> pending() async =>
      [for (final p in await _plugin.pendingNotificationRequests()) (id: p.id, payload: p.payload)];

  @override
  Future<List<({int id, String? payload})>> shown() async => [
        for (final n in await _android.getActiveNotifications())
          if (n.id != null) (id: n.id!, payload: n.payload),
      ];

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> schedule(PlannedNotification n) => _plugin.zonedSchedule(
        n.id,
        n.title,
        n.body,
        tz.TZDateTime.from(n.at, tz.local),
        NotificationDetails(android: _details(n)),
        androidScheduleMode: exactAlarms ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: n.payload,
      );

  static AndroidNotificationDetails _details(PlannedNotification n) {
    if (n.channel != NotificationChannel.medsAlarm) {
      return AndroidNotificationDetails(
        n.channel.id,
        n.channel.label,
        importance: n.channel.importance,
        priority: n.channel == NotificationChannel.calendarHigh ? Priority.high : Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(n.body),
      );
    }
    return AndroidNotificationDetails(
      n.channel.id,
      n.channel.label,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: n.fullScreen,
      sound: _alarmSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      // FLAG_INSISTENT: keep ringing until answered (or the alert times out).
      additionalFlags: Int32List.fromList(const [4]),
      timeoutAfter: const Duration(minutes: 3).inMilliseconds,
      styleInformation: BigTextStyleInformation(n.body),
      actions: [
        for (final (id, label) in n.actions)
          AndroidNotificationAction(id, label, showsUserInterface: true, cancelNotification: true),
      ],
    );
  }
}
