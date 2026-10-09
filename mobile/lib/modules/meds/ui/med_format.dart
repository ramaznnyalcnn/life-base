import 'package:flutter/material.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';

const _weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// "Her gün 09:00, 21:00", "Pzt, Çar · 08:00", "8 saatte bir · 06:00'dan".
String scheduleLabel(MedSchedule s) {
  final times = s.times.join(', ');
  return switch (s.mode) {
    ScheduleMode.times => 'Her gün $times',
    ScheduleMode.weekdays => '${s.weekdays.map((d) => _weekdayShort[d - 1]).join(', ')} · $times',
    ScheduleMode.everyNDays => '${s.intervalDays} günde bir · $times',
    ScheduleMode.everyNHours => '${s.intervalHours} saatte bir · ${s.times.isEmpty ? '08:00' : s.times.first}’dan itibaren',
    ScheduleMode.asNeeded => 'Gerektiğinde',
  };
}

String statusLabel(DoseStatus status) => switch (status) {
      DoseStatus.pending => 'Bekliyor',
      DoseStatus.taken => 'Alındı',
      DoseStatus.skipped => 'Atlandı',
      DoseStatus.snoozed => 'Ertelendi',
      DoseStatus.missed => 'Kaçırıldı',
    };

Color statusColor(BuildContext context, DoseStatus status) {
  final t = LbTokens.of(context);
  return switch (status) {
    DoseStatus.taken => t.income,
    DoseStatus.missed => t.danger,
    DoseStatus.skipped => t.muted,
    DoseStatus.snoozed => t.module(LbModule.today),
    DoseStatus.pending => t.module(LbModule.meds),
  };
}

IconData formIcon(String form) => switch (form) {
      'syrup' => Icons.local_drink_rounded,
      'drops' => Icons.water_drop_rounded,
      'injection' => Icons.vaccines_rounded,
      'spray' => Icons.air_rounded,
      'cream' => Icons.spa_rounded,
      _ => Icons.medication_rounded,
    };
