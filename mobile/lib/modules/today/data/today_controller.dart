import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_store.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/platform/device_calendar.dart';
import '../../../core/providers.dart';
import '../../../core/wallet/wallet_store.dart';
import 'today_view.dart';

/// The current time, ticking on each minute (countdowns, missed doses, the date).
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;
  void tick() {
    final now = DateTime.now();
    controller.add(now);
    timer = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), tick);
  }

  tick();
  final lifecycle = AppLifecycleListener(onResume: () {
    timer?.cancel();
    tick();
  });
  ref.onDispose(() {
    timer?.cancel();
    lifecycle.dispose();
    unawaited(controller.close());
  });
  return controller.stream;
});

DateTime _now(Ref ref) => ref.watch(minuteClockProvider).value ?? DateTime.now();

/// Bugün for [day]: LifeBase and Google events plus doses, all from the device.
final todayViewProvider = Provider.family<TodayView, DateTime>((ref, day) {
  final now = _now(ref);
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
  return buildToday(
    events: occurrencesIn(ref.watch(localEventsProvider).value ?? const [], start, start),
    google: ref.watch(deviceEventsProvider((from: start, to: start))).value ?? const [],
    doses: doseEntries(ref.watch(localMedicationsProvider).value ?? const [], ref.watch(doseLogsProvider).value ?? const {}, start, end, now),
    now: now,
  );
});

final todayWalletProvider = Provider<WalletGlance?>((ref) {
  final wallet = ref.watch(walletProvider).value;
  return wallet == null ? null : walletGlance(wallet, _now(ref));
});

/// Keeps the home-screen widget's snapshot in step with today and tomorrow.
final todayWidgetSyncProvider = Provider<void>((ref) {
  String? last;
  Timer? debounce;
  void push() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final snapshot = widgetSnapshot({
        today: ref.read(todayViewProvider(today)),
        tomorrow: ref.read(todayViewProvider(tomorrow)),
      }, now)
        ..remove('generated_at');
      final payload = jsonEncode(snapshot);
      if (payload == last) return;
      last = payload;
      await ref.read(platformBridgeProvider).updateWidget(payload).catchError((Object _) {});
    });
  }

  ref.listen(minuteClockProvider, (previous, next) {
    // A new day changes which days the snapshot covers.
    final before = previous?.value, after = next.value;
    if (before == null || after == null || before.day != after.day) push();
  }, fireImmediately: true);
  ref.listen(localEventsProvider, (_, _) => push());
  ref.listen(localMedicationsProvider, (_, _) => push());
  ref.listen(doseLogsProvider, (_, _) => push());
  ref.onDispose(() => debounce?.cancel());
});
