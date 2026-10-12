import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/tokens.dart';

/// Soft note colours (index stored on the note).
List<Color> noteColors(BuildContext context) {
  final dark = LbTokens.of(context).brightness == Brightness.dark;
  return dark
      ? const [Color(0xFFE8C468), Color(0xFF86CFA5), Color(0xFF8DB7F0), Color(0xFFF199B3), Color(0xFFC4B2F5), Color(0xFFF0A672)]
      : const [Color(0xFFC99A1E), Color(0xFF2E8B57), Color(0xFF2F6FB8), Color(0xFFC2456B), Color(0xFF6447B0), Color(0xFFC8662B)];
}

Color? noteColor(BuildContext context, int? index) {
  if (index == null) return null;
  final colors = noteColors(context);
  return index >= 0 && index < colors.length ? colors[index] : null;
}

/// "Bugün 15:00", "Yarın", "Pazartesi 09:00", "16 Ekim Cuma 15:00", "12 Mart 2027".
String eventWhen(DateTime at, {required bool allDay}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final date = switch (diff) {
    0 => 'Bugün',
    1 => 'Yarın',
    _ when diff > 1 && diff < 7 => DateFormat('EEEE', 'tr_TR').format(at),
    _ => DateFormat(at.year == now.year ? 'd MMMM EEEE' : 'd MMMM y', 'tr_TR').format(at),
  };
  return allDay ? date : '$date ${DateFormat('HH:mm').format(at)}';
}
