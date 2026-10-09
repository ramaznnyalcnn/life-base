import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agenda.dart';
import '../providers.dart';

/// Agenda kind for events read from the user's own Google calendar.
const googleKind = 'google';

/// Converts a raw Calendar Provider instance into an agenda item.
///
/// All-day instances are stored at UTC midnight, so their day must be read in
/// UTC; timed instances are shown in local time.
AgendaItem deviceEventToAgendaItem(Map<String, Object?> raw) {
  final allDay = raw['all_day'] == true;
  final begin = DateTime.fromMillisecondsSinceEpoch((raw['begin']! as num).toInt(), isUtc: true);
  final end = DateTime.fromMillisecondsSinceEpoch((raw['end']! as num).toInt(), isUtc: true);
  final day = allDay ? DateTime(begin.year, begin.month, begin.day) : DateTime(begin.toLocal().year, begin.toLocal().month, begin.toLocal().day);
  final title = (raw['title'] as String?)?.trim();
  return AgendaItem(
    id: 'google:${raw['id']}',
    sourceId: raw['id']!,
    kind: googleKind,
    title: title == null || title.isEmpty ? '(Başlıksız)' : title,
    day: day,
    startsAt: allDay ? null : begin.toLocal(),
    endsAt: allDay ? null : end.toLocal(),
    isAllDay: allDay,
    metadata: {
      if (raw['location'] != null) 'location': raw['location'],
      if (raw['color'] != null) 'color': raw['color'],
    },
  );
}

/// Events of the connected Google account between two local dates (inclusive).
final deviceEventsProvider = FutureProvider.family<List<AgendaItem>, ({DateTime from, DateTime to})>((ref, range) async {
  final from = DateTime(range.from.year, range.from.month, range.from.day);
  final to = DateTime(range.to.year, range.to.month, range.to.day).add(const Duration(days: 1));
  try {
    final raw = await ref.watch(platformBridgeProvider).deviceEvents(from, to);
    return raw.map(deviceEventToAgendaItem).toList();
  } on Object {
    // Not connected, no permission, or not on Android: the module still works.
    return const [];
  }
});

/// The Google account LifeBase reads from and writes to, if connected.
final googleCalendarStatusProvider = FutureProvider<({String? account, bool permission})>((ref) async {
  try {
    return await ref.watch(platformBridgeProvider).googleStatus();
  } on Object {
    return (account: null, permission: false);
  }
});
