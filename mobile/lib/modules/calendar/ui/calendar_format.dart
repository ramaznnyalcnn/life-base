import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/design_system/tokens.dart';

/// Event colours chosen to read well on both light and dark surfaces.
const eventColors = <int>[
  0xFFE5736F, // mercan
  0xFFF0A04B, // turuncu
  0xFFE2C044, // hardal
  0xFF6FBF73, // yeşil
  0xFF46B1A6, // turkuaz
  0xFF5B9BE0, // mavi
  0xFF9378D6, // mor
  0xFFE07AA8, // pembe
];

Color eventColor(BuildContext context, int? value) =>
    value == null ? LbTokens.of(context).module(LbModule.calendar) : Color(value);

const weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String timeRange(DateTime start, DateTime end, {required bool allDay}) {
  if (allDay) return 'Tüm gün';
  final f = DateFormat('HH:mm');
  return end.isAfter(start) ? '${f.format(start)} – ${f.format(end)}' : f.format(start);
}

/// "Her gün", "3 günde bir", "Her hafta Pzt, Çar", "Her ay 5'inde" + until.
String recurrenceLabel(RecurrenceRule rule, DateTime start) {
  final every = rule.interval;
  final base = switch (rule.freq) {
    RecurrenceFreq.daily => every == 1 ? 'Her gün' : '$every günde bir',
    RecurrenceFreq.weekly => '${every == 1 ? 'Her hafta' : '$every haftada bir'} '
        '${(rule.weekdays.isEmpty ? [start.weekday] : rule.weekdays).map((d) => weekdayShort[d - 1]).join(', ')}',
    RecurrenceFreq.monthly => '${every == 1 ? 'Her ay' : '$every ayda bir'} ${start.day}. gün',
    RecurrenceFreq.yearly => 'Her yıl ${DateFormat('d MMMM', 'tr_TR').format(start)}',
  };
  final until = rule.until;
  return until == null ? base : '$base · ${DateFormat('d MMM y', 'tr_TR').format(until)} tarihine kadar';
}
