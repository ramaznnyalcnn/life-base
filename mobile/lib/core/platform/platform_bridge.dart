import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/agenda.dart';

class PlatformBridge {
  const PlatformBridge();

  static const _channel = MethodChannel('app.lifebase.mobile/platform');

  Future<bool> requestCalendarAccess() async =>
      await _channel.invokeMethod<bool>('requestCalendarAccess') ?? false;

  Future<bool> calendarWritable() async =>
      await _channel.invokeMethod<bool>('calendarWritable') ?? false;

  Future<bool> requestNotificationAccess() async =>
      await _channel.invokeMethod<bool>('requestNotificationAccess') ?? false;

  Future<bool> requestOnboardingPermissions() async =>
      await _channel.invokeMethod<bool>('requestOnboardingPermissions') ?? false;

  Future<void> scheduleSync() => _channel.invokeMethod<void>('scheduleSync');

  Future<void> syncNow() => _channel.invokeMethod<void>('syncNow');

  Future<void> clearSession() => _channel.invokeMethod<void>('clearSession');

  /// Google accounts that have calendars on this device.
  Future<List<String>> googleAccounts() async =>
      (await _channel.invokeListMethod<Object?>('googleAccounts') ?? const []).cast<String>();

  /// Reads from the account's own calendars and writes into its primary one.
  Future<bool> connectGoogle(String account) async =>
      await _channel.invokeMethod<bool>('connectGoogle', {'account': account}) ?? false;

  Future<({String? account, bool permission})> googleStatus() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('googleStatus') ?? const {};
    return (account: raw['account'] as String?, permission: raw['permission'] == true);
  }

  /// False when Android 14+ has withheld full-screen (alarm-style) alerts.
  Future<bool> canUseFullScreenIntent() async =>
      await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;

  /// Lets the dose alarm page show above the lock screen (off afterwards).
  Future<void> setShowOverLockScreen(bool enabled) =>
      _channel.invokeMethod<void>('setShowOverLockScreen', {'enabled': enabled});

  /// Writes the app's local events into the connected Google calendar.
  Future<void> projectLocalEvents(String itemsJson) =>
      _channel.invokeMethod<void>('projectLocalEvents', {'items': itemsJson});

  Future<List<Map<String, Object?>>> deviceEvents(DateTime from, DateTime to) async {
    final values = await _channel.invokeListMethod<Object?>('deviceEvents', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
        }) ??
        const [];
    return values.cast<Map>().map((item) => Map<String, Object?>.from(item)).toList();
  }

  Future<void> saveSyncConfig({required String serverUrl, required String token}) =>
      _channel.invokeMethod<void>('saveSyncConfig', {
        'serverUrl': serverUrl,
        'token': token,
      });

  Future<void> updateWidget(TodayAgenda agenda) =>
      _channel.invokeMethod<void>('updateWidgetSnapshot', {
        'payload': jsonEncode({
          'next': agenda.nextItem?.displayTitle ?? '',
          'count': agenda.tasks.where((item) => !item.isCompleted).length +
              agenda.timeline.where((item) => !item.isCompleted).length,
          'action': _widgetAction(agenda),
        }),
      });

  static Map<String, Object?>? _widgetAction(TodayAgenda agenda) {
    final candidates = [...agenda.tasks, ...agenda.timeline]
        .where((item) => !item.isCompleted && (item.kind == 'task' || item.kind == 'medication'));
    final item = candidates.firstOrNull;
    if (item == null) return null;
    return {
      'kind': item.kind,
      'id': item.sourceId,
      'scheduled_for': item.metadata['scheduled_for'],
      'entity_version': item.metadata['entity_version'],
    };
  }
}
