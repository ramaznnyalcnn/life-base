import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/platform/device_calendar.dart';

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
}
