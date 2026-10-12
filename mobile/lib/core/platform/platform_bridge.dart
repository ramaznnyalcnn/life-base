import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  const PlatformBridge();

  static const _channel = MethodChannel('app.lifebase.mobile/platform');

  // Everything here is Android (calendar, alarms, widget, background sync);
  // on the web there is no such side, so each call quietly does nothing.
  static Future<T?> _invoke<T>(String method, [Object? arguments]) =>
      kIsWeb ? Future<T?>.value() : _channel.invokeMethod<T>(method, arguments);
  static Future<List<T>?> _invokeList<T>(String method, [Object? arguments]) =>
      kIsWeb ? Future<List<T>?>.value() : _channel.invokeListMethod<T>(method, arguments);
  static Future<Map<K, V>?> _invokeMap<K, V>(String method, [Object? arguments]) =>
      kIsWeb ? Future<Map<K, V>?>.value() : _channel.invokeMapMethod<K, V>(method, arguments);

  Future<bool> requestCalendarAccess() async =>
      await _invoke<bool>('requestCalendarAccess') ?? false;

  Future<bool> calendarWritable() async =>
      await _invoke<bool>('calendarWritable') ?? false;

  Future<bool> requestNotificationAccess() async =>
      await _invoke<bool>('requestNotificationAccess') ?? false;

  Future<bool> requestOnboardingPermissions() async =>
      await _invoke<bool>('requestOnboardingPermissions') ?? false;

  Future<void> scheduleSync() => _invoke<void>('scheduleSync');

  Future<void> syncNow() => _invoke<void>('syncNow');

  Future<void> clearSession() => _invoke<void>('clearSession');

  /// Google accounts that have calendars on this device.
  Future<List<String>> googleAccounts() async =>
      (await _invokeList<Object?>('googleAccounts') ?? const []).cast<String>();

  /// Reads from the account's own calendars and writes into its primary one.
  Future<bool> connectGoogle(String account) async =>
      await _invoke<bool>('connectGoogle', {'account': account}) ?? false;

  Future<({String? account, bool permission})> googleStatus() async {
    final raw = await _invokeMap<String, Object?>('googleStatus') ?? const {};
    return (account: raw['account'] as String?, permission: raw['permission'] == true);
  }

  /// False when Android 14+ has withheld full-screen (alarm-style) alerts.
  Future<bool> canUseFullScreenIntent() async =>
      await _invoke<bool>('canUseFullScreenIntent') ?? true;

  /// Lets the dose alarm page show above the lock screen (off afterwards).
  Future<void> setShowOverLockScreen(bool enabled) =>
      _invoke<void>('setShowOverLockScreen', {'enabled': enabled});

  /// Writes the app's local events into the connected Google calendar.
  /// Blocks screenshots and blanks the recent-apps preview while card
  /// details are on screen.
  Future<void> setSecure(bool enabled) => _invoke<void>('setSecure', {'enabled': enabled});

  Future<void> projectLocalEvents(String itemsJson) =>
      _invoke<void>('projectLocalEvents', {'items': itemsJson});

  Future<List<Map<String, Object?>>> deviceEvents(DateTime from, DateTime to) async {
    final values = await _invokeList<Object?>('deviceEvents', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
        }) ??
        const [];
    return values.cast<Map>().map((item) => Map<String, Object?>.from(item)).toList();
  }

  Future<void> saveSyncConfig({required String serverUrl, required String token}) =>
      _invoke<void>('saveSyncConfig', {
        'serverUrl': serverUrl,
        'token': token,
      });

  /// Hands the home-screen widget its JSON snapshot (see `widgetSnapshot`).
  Future<void> updateWidget(String payload) => _invoke<void>('updateWidgetSnapshot', {'payload': payload});
}
