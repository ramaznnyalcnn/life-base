import 'package:flutter/foundation.dart';

/// A date (and maybe a time) mentioned in a note, found by fixed Turkish
/// rules — no AI, works offline.
@immutable
class DateHint {
  const DateHint({required this.start, required this.hasTime, required this.spans});

  /// Local time; midnight when [hasTime] is false.
  final DateTime start;
  final bool hasTime;

  /// Where the date and time words are in the text (start, end).
  final List<(int, int)> spans;

  @override
  String toString() => 'DateHint($start, hasTime: $hasTime)';
}

const _months = ['ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran', 'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'];
const _weekdays = ['pazartesi', 'salı', 'çarşamba', 'perşembe', 'cuma', 'cumartesi', 'pazar'];

// Letters around a match must not continue a word ("cumartesi" is not "cuma").
const _before = r'(?<![\p{L}\d])';
// Turkish suffixes may follow, with or without an apostrophe: yarına, cuma'ya, 15:00'te.
const _suffix = r"(?:'?\p{L}{0,5})?(?![\p{L}\d])";

RegExp _re(String body) => RegExp('$_before(?:$body)$_suffix', unicode: true);

// Longest first, so "cumartesi" is not read as "cuma" plus a suffix.
final _weekdayNames = ([..._weekdays]..sort((a, b) => b.length.compareTo(a.length))).join('|');
final _nextWeekday = _re('haftaya ($_weekdayNames)(?: günü)?');
final _weekday = _re('($_weekdayNames)(?: günü)?');
final _relative = _re(r'bugün|bu gün|yarın|öbür gün|ertesi gün|(\d{1,2}) gün sonra');
final _nextWeek = _re('haftaya');
final _namedDate = _re('(\\d{1,2}) (${_months.join('|')})(?: (\\d{4}))?');
final _slashDate = _re(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?');
final _dottedDate = _re(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})');
final _shortDottedDate = _re(r'(\d{1,2})\.(\d{1,2})');
final _clock = _re(r'(?:saat )?([01]?\d|2[0-3])[:.]([0-5]\d)');
final _period = _re(r'(sabah|öğleden sonra|akşam|gece) (?:saat )?(\d{1,2})(?:[:.]([0-5]\d))?');
final _hourOnly = _re(r'saat (\d{1,2})');
final _noon = _re('öğlen|öğle');

/// Lower-cases Turkish text without changing its length (dotted İ).
String _lower(String text) {
  final out = StringBuffer();
  for (final char in text.split('')) {
    out.write(switch (char) {
      'İ' => 'i',
      'I' => 'ı',
      _ => char.toLowerCase(),
    });
  }
  return out.toString();
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// The first date and the first time mentioned in [text], if any.
///
/// A time alone means today (tomorrow once it has passed). A weekday means
/// its next occurrence (today when it is today and the time is still ahead).
/// A date without a year that has passed this year means next year.
DateHint? findDateHint(String text, DateTime now) {
  final lower = _lower(text);
  final today = _day(now);
  final spans = <(int, int)>[];

  // Dates -------------------------------------------------------------------
  DateTime? day;
  var weekdayOnly = false;
  RegExpMatch? first(RegExp re) => re.firstMatch(lower);
  final candidates = <(RegExpMatch, DateTime? Function(RegExpMatch))>[];

  void candidate(RegExp re, DateTime? Function(RegExpMatch m) parse) {
    final m = first(re);
    if (m != null) candidates.add((m, parse));
  }

  candidate(_relative, (m) {
    final word = m.group(0)!;
    if (word.startsWith('bugün') || word.startsWith('bu gün')) return today;
    if (word.startsWith('yarın')) return today.add(const Duration(days: 1));
    if (word.startsWith('öbür') || word.startsWith('ertesi')) return today.add(const Duration(days: 2));
    return today.add(Duration(days: int.parse(m.group(1)!)));
  });
  candidate(_nextWeekday, (m) {
    final weekday = _weekdays.indexOf(m.group(1)!) + 1;
    final monday = today.subtract(Duration(days: today.weekday - 1)).add(const Duration(days: 7));
    return monday.add(Duration(days: weekday - 1));
  });
  candidate(_namedDate, (m) {
    final d = int.parse(m.group(1)!);
    final month = _months.indexOf(m.group(2)!) + 1;
    return _date(d, month, m.group(3), today);
  });
  candidate(_slashDate, (m) => _date(int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3), today));
  candidate(_dottedDate, (m) => _date(int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3), today));
  // "13.10" reads like a time too; it is a date only when a time sits beside it.
  final full = first(_dottedDate);
  final short = _shortDottedDate.allMatches(lower).where((m) => full == null || !_overlaps(m, full)).firstOrNull;
  if (short != null && _clock.allMatches(lower).any((c) => !_overlaps(c, short))) {
    candidates.add((short, (m) => _date(int.parse(m.group(1)!), int.parse(m.group(2)!), null, today)));
  }
  final weekdayMatch = first(_weekday);
  if (weekdayMatch != null && !candidates.any((c) => _overlaps(c.$1, weekdayMatch))) {
    candidates.add((weekdayMatch, (m) {
      final weekday = _weekdays.indexOf(m.group(1)!) + 1;
      weekdayOnly = true;
      return today.add(Duration(days: (weekday - today.weekday) % 7));
    }));
  }
  if (candidates.isEmpty) {
    candidate(_nextWeek, (_) => today.add(const Duration(days: 7)));
  }
  candidates.sort((a, b) => a.$1.start.compareTo(b.$1.start));
  for (final (match, parse) in candidates) {
    final value = parse(match);
    if (value != null) {
      day = value;
      spans.add((match.start, match.end));
      break;
    }
  }

  // Times ------------------------------------------------------------------
  int? hour;
  var minute = 0;
  final dateSpan = spans.firstOrNull;
  bool clear(RegExpMatch m) => dateSpan == null || m.end <= dateSpan.$1 || m.start >= dateSpan.$2;
  final period = _period.allMatches(lower).where(clear).firstOrNull;
  final clock = _clock.allMatches(lower).where(clear).firstOrNull;
  final bare = _hourOnly.allMatches(lower).where(clear).firstOrNull;
  final noon = _noon.allMatches(lower).where(clear).firstOrNull;
  if (period != null) {
    final h = int.parse(period.group(2)!);
    minute = period.group(3) == null ? 0 : int.parse(period.group(3)!);
    hour = switch (period.group(1)) {
      'sabah' => h % 12,
      'gece' => h <= 4 ? h : (h % 12) + 12,
      _ => h < 12 ? h + 12 : h,
    };
    spans.add((period.start, period.end));
  } else if (clock != null) {
    hour = int.parse(clock.group(1)!);
    minute = int.parse(clock.group(2)!);
    spans.add((clock.start, clock.end));
  } else if (bare != null && int.parse(bare.group(1)!) <= 23) {
    final h = int.parse(bare.group(1)!);
    // "saat 3'te" means the afternoon.
    hour = h >= 1 && h <= 6 ? h + 12 : h;
    spans.add((bare.start, bare.end));
  } else if (noon != null) {
    hour = 12;
    spans.add((noon.start, noon.end));
  }

  if (day == null && hour == null) return null;
  var start = DateTime((day ?? today).year, (day ?? today).month, (day ?? today).day, hour ?? 0, minute);
  if (day == null && start.isBefore(now)) start = start.add(const Duration(days: 1));
  if (weekdayOnly && hour != null && start.isBefore(now)) start = start.add(const Duration(days: 7));
  spans.sort((a, b) => a.$1.compareTo(b.$1));
  return DateHint(start: start, hasTime: hour != null, spans: spans);
}

DateTime? _date(int d, int month, String? yearText, DateTime today) {
  if (month < 1 || month > 12 || d < 1) return null;
  var year = yearText == null ? today.year : int.parse(yearText);
  if (yearText != null && yearText.length == 2) year += 2000;
  if (d > DateTime(year, month + 1, 0).day) return null;
  var date = DateTime(year, month, d);
  if (yearText == null && date.isBefore(today)) date = DateTime(year + 1, month, d);
  return date;
}

bool _overlaps(RegExpMatch a, RegExpMatch b) => a.start < b.end && b.start < a.end;

/// [text] without the date and time words, tidied (for an event title).
String withoutHint(String text, DateHint hint) {
  final out = StringBuffer();
  var at = 0;
  for (final (start, end) in hint.spans) {
    if (start < at) continue;
    out.write(text.substring(at, start));
    at = end;
  }
  out.write(text.substring(at));
  return out.toString().replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '').trim();
}
