import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/models/agenda.dart';
import 'package:lifebase_mobile/core/platform/device_calendar.dart';
import 'package:lifebase_mobile/modules/calendar/ui/calendar_screen.dart';
import 'package:lifebase_mobile/modules/today/ui/today_screen.dart';

void main() {
  test('all-day Google events keep their calendar day regardless of timezone', () {
    // The Calendar Provider stores all-day instances at UTC midnight.
    final item = deviceEventToAgendaItem({
      'id': '7:1',
      'title': 'Bayram',
      'begin': DateTime.utc(2026, 10, 29).millisecondsSinceEpoch,
      'end': DateTime.utc(2026, 10, 30).millisecondsSinceEpoch,
      'all_day': true,
    });

    expect(item.day, DateTime(2026, 10, 29));
    expect(item.startsAt, isNull);
    expect(item.isAllDay, isTrue);
    expect(item.kind, googleKind);
  });

  test('timed Google events are shown in local time and untitled ones get a label', () {
    final begin = DateTime(2026, 10, 9, 14, 30);
    final item = deviceEventToAgendaItem({
      'id': '8:1',
      'title': '  ',
      'begin': begin.millisecondsSinceEpoch,
      'end': begin.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'all_day': false,
      'color': 0xFF4285F4,
    });

    expect(item.startsAt, begin);
    expect(item.day, DateTime(2026, 10, 9));
    expect(item.title, '(Başlıksız)');
    expect(item.metadata['color'], 0xFF4285F4);
  });

  AgendaItem at(String id, String kind, DateTime day, [int? hour]) => AgendaItem(
        id: id,
        sourceId: id,
        kind: kind,
        title: id,
        day: day,
        startsAt: hour == null ? null : DateTime(day.year, day.month, day.day, hour),
        isAllDay: hour == null,
      );

  test('calendar merges server items and Google events by day, all-day first', () {
    final d1 = DateTime(2026, 10, 9), d2 = DateTime(2026, 10, 10);
    final merged = mergeAgenda(
      [at('server-d2', 'event', d2, 9), at('server-d1', 'event', d1, 15)],
      [at('google-d1', googleKind, d1, 10), at('google-allday', googleKind, d1)],
    );

    expect(merged.map((e) => e.id), ['google-allday', 'google-d1', 'server-d1', 'server-d2']);
  });

  test('next item prefers a sooner upcoming Google event over the server one', () {
    final day = DateTime(2026, 10, 9);
    final now = DateTime(2026, 10, 9, 8);
    final server = at('server', 'event', day, 12);

    expect(nextItem(server, [at('google', googleKind, day, 10)], now)?.id, 'google');
    expect(nextItem(server, [at('later', googleKind, day, 13)], now)?.id, 'server');
    expect(nextItem(server, [at('past', googleKind, day, 7)], now)?.id, 'server');
    expect(nextItem(null, [at('google', googleKind, day, 10)], now)?.id, 'google');
  });
}
