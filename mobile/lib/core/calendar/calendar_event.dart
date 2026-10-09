import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../storage/app_database.dart';

enum RecurrenceFreq { daily, weekly, monthly, yearly }

/// Repetition of an event. "Every N days" is [RecurrenceFreq.daily] with an
/// [interval]; weekly rules may pick specific [weekdays] (1 = Monday).
@immutable
class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.weekdays = const [],
    this.until,
    this.exdates = const [],
  });

  factory RecurrenceRule.fromJson(Map<String, Object?> json) => RecurrenceRule(
        freq: RecurrenceFreq.values.asNameMap()[json['freq']] ?? RecurrenceFreq.daily,
        interval: ((json['interval'] as num?)?.toInt() ?? 1).clamp(1, 999),
        weekdays: (json['weekdays'] as List? ?? const []).whereType<num>().map((d) => d.toInt()).where((d) => d >= 1 && d <= 7).toList()..sort(),
        until: _day(json['until']),
        exdates: (json['exdates'] as List? ?? const []).map(_day).whereType<DateTime>().toList(),
      );

  final RecurrenceFreq freq;
  final int interval;
  final List<int> weekdays;

  /// Last day (inclusive) an occurrence may start on.
  final DateTime? until;

  /// Days whose occurrence was removed ("only this one" deletes and edits).
  final List<DateTime> exdates;

  RecurrenceRule copyWith({DateTime? until, bool clearUntil = false, List<DateTime>? exdates}) => RecurrenceRule(
        freq: freq,
        interval: interval,
        weekdays: weekdays,
        until: clearUntil ? null : until ?? this.until,
        exdates: exdates ?? this.exdates,
      );

  Map<String, Object?> toJson() => {
        'freq': freq.name,
        'interval': interval,
        if (weekdays.isNotEmpty) 'weekdays': [...weekdays]..sort(),
        if (until != null) 'until': _dayString(until!),
        if (exdates.isNotEmpty) 'exdates': exdates.map(_dayString).toList(),
      };

  @override
  bool operator ==(Object other) => other is RecurrenceRule && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

enum ReminderPriority { normal, high }

/// A reminder either [offset] before the occurrence starts, or at a fixed
/// moment [at] (only meaningful for one-off events).
@immutable
class ReminderSpec {
  const ReminderSpec.before(Duration this.offset, {this.priority = ReminderPriority.normal}) : at = null;
  const ReminderSpec.at(DateTime this.at, {this.priority = ReminderPriority.normal}) : offset = null;

  factory ReminderSpec.fromJson(Map<String, Object?> json) {
    final priority = json['priority'] == 'high' ? ReminderPriority.high : ReminderPriority.normal;
    final at = json['at'] is String ? DateTime.tryParse(json['at']! as String) : null;
    if (at != null) return ReminderSpec.at(at.toUtc(), priority: priority);
    return ReminderSpec.before(Duration(minutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0), priority: priority);
  }

  final Duration? offset;
  final DateTime? at;
  final ReminderPriority priority;

  ReminderSpec withPriority(ReminderPriority value) =>
      at != null ? ReminderSpec.at(at!, priority: value) : ReminderSpec.before(offset!, priority: value);

  DateTime fireTime(DateTime occurrenceStart) => at ?? occurrenceStart.subtract(offset!);

  Map<String, Object?> toJson() => {
        if (at != null) 'at': at!.toUtc().toIso8601String() else 'offsetMinutes': offset!.inMinutes,
        if (priority == ReminderPriority.high) 'priority': 'high',
      };

  @override
  bool operator ==(Object other) =>
      other is ReminderSpec && other.offset == offset && other.at == at && other.priority == priority;

  @override
  int get hashCode => Object.hash(offset, at, priority);
}

/// A calendar event as the app works with it (one row of `local_events`).
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.notes,
    this.allDay = false,
    this.color,
    this.important = false,
    this.recurrence,
    this.reminders = const [],
    this.updatedAtMs = 0,
  });

  factory CalendarEvent.fromRow(LocalEvent row) => CalendarEvent(
        id: row.id,
        title: row.title,
        notes: row.notes,
        startsAt: row.allDay ? _asDate(row.startsAt) : row.startsAt.toLocal(),
        endsAt: row.endsAt == null ? null : (row.allDay ? _asDate(row.endsAt!) : row.endsAt!.toLocal()),
        allDay: row.allDay,
        color: row.color,
        important: row.important,
        recurrence: row.recurrence == null ? null : RecurrenceRule.fromJson(Map<String, Object?>.from(jsonDecode(row.recurrence!) as Map)),
        reminders: (jsonDecode(row.reminders) as List).cast<Map>().map((r) => ReminderSpec.fromJson(Map<String, Object?>.from(r))).toList(),
        updatedAtMs: row.updatedAtMs,
      );

  final String id;
  final String title;
  final String? notes;

  /// Local wall-clock start. All-day events use midnight of their first day.
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final int? color;
  final bool important;
  final RecurrenceRule? recurrence;
  final List<ReminderSpec> reminders;
  final int updatedAtMs;

  /// The row stored for this event, stamped [stampMs] and queued for sync.
  LocalEventsCompanion toRow(int stampMs) => LocalEventsCompanion.insert(
        id: id,
        title: title,
        notes: Value(notes),
        startsAt: allDay ? DateTime.utc(startsAt.year, startsAt.month, startsAt.day) : startsAt.toUtc(),
        endsAt: Value(endsAt == null ? null : (allDay ? DateTime.utc(endsAt!.year, endsAt!.month, endsAt!.day) : endsAt!.toUtc())),
        allDay: Value(allDay),
        color: Value(color),
        important: Value(important),
        recurrence: Value(recurrence == null ? null : jsonEncode(recurrence!.toJson())),
        reminders: Value(jsonEncode([for (final r in reminders) r.toJson()])),
        updatedAtMs: stampMs,
        deletedAtMs: const Value(null),
        dirty: const Value(true),
      );

  Duration get duration {
    final end = endsAt;
    if (end == null || !end.isAfter(startsAt)) return allDay ? const Duration(days: 1) : Duration.zero;
    return end.difference(startsAt);
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? notes,
    bool clearNotes = false,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? allDay,
    int? color,
    bool clearColor = false,
    bool? important,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
    List<ReminderSpec>? reminders,
  }) =>
      CalendarEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        notes: clearNotes ? null : notes ?? this.notes,
        startsAt: startsAt ?? this.startsAt,
        endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
        allDay: allDay ?? this.allDay,
        color: clearColor ? null : color ?? this.color,
        important: important ?? this.important,
        recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
        reminders: reminders ?? this.reminders,
        updatedAtMs: updatedAtMs,
      );

  /// Occurrences that overlap the local-date range [from, to] (inclusive).
  List<EventOccurrence> occurrencesBetween(DateTime from, DateTime to) {
    final first = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    final rule = recurrence;
    final span = duration;
    bool overlaps(DateTime start) {
      final startDay = DateTime(start.year, start.month, start.day);
      final end = start.add(span);
      final endDay = allDay ? startDay.add(Duration(days: (span.inDays - 1).clamp(0, 3650))) : DateTime(end.year, end.month, end.day);
      return !startDay.isAfter(last) && !endDay.isBefore(first);
    }

    if (rule == null) {
      return overlaps(startsAt) ? [EventOccurrence(this, startsAt)] : const [];
    }
    final excluded = {for (final d in rule.exdates) _dayKey(d)};
    final result = <EventOccurrence>[];
    // Start early enough that multi-day occurrences beginning before the
    // window are still found.
    final scanFrom = first.subtract(Duration(days: span.inDays + 1));
    for (final start in _starts(rule, scanFrom, last)) {
      if (excluded.contains(_dayKey(start))) continue;
      if (overlaps(start)) result.add(EventOccurrence(this, start));
    }
    return result;
  }

  Iterable<DateTime> _starts(RecurrenceRule rule, DateTime scanFrom, DateTime last) sync* {
    final base = startsAt;
    final until = rule.until;
    final end = until != null && until.isBefore(last) ? until : last;
    DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, base.hour, base.minute);
    final baseDay = DateTime(base.year, base.month, base.day);
    switch (rule.freq) {
      case RecurrenceFreq.daily:
        var day = baseDay;
        if (scanFrom.isAfter(day)) {
          final skip = scanFrom.difference(day).inDays ~/ rule.interval;
          day = _addDays(day, skip * rule.interval);
        }
        for (; !day.isAfter(end); day = _addDays(day, rule.interval)) {
          if (!day.isBefore(baseDay)) yield at(day);
        }
      case RecurrenceFreq.weekly:
        final days = rule.weekdays.isEmpty ? [base.weekday] : rule.weekdays;
        final weekStart = _addDays(baseDay, -(base.weekday - 1));
        var week = weekStart;
        if (scanFrom.isAfter(week)) {
          final skip = scanFrom.difference(week).inDays ~/ (7 * rule.interval);
          week = _addDays(week, skip * 7 * rule.interval);
        }
        for (; !week.isAfter(end); week = _addDays(week, 7 * rule.interval)) {
          for (final weekday in days) {
            final day = _addDays(week, weekday - 1);
            if (day.isBefore(baseDay) || day.isAfter(end)) continue;
            yield at(day);
          }
        }
      case RecurrenceFreq.monthly:
      case RecurrenceFreq.yearly:
        final months = rule.freq == RecurrenceFreq.monthly ? rule.interval : 12 * rule.interval;
        for (var i = 0;; i += months) {
          final month = DateTime(base.year, base.month + i);
          if (month.isAfter(end)) break;
          // Skip months without this day (no 31 February) instead of overflowing.
          final lastDay = DateTime(month.year, month.month + 1, 0).day;
          if (base.day > lastDay) continue;
          final day = DateTime(month.year, month.month, base.day);
          if (day.isAfter(end)) break;
          yield at(day);
        }
    }
  }
}

/// One concrete appearance of an event on the calendar.
@immutable
class EventOccurrence {
  const EventOccurrence(this.event, this.start);

  final CalendarEvent event;
  final DateTime start;

  DateTime get end => start.add(event.duration);
  String get key => '${event.id}@${_dayString(start)}';
  bool get isRecurring => event.recurrence != null;

  /// When this occurrence's reminders fire. Fixed-time reminders only apply
  /// to one-off events.
  List<({DateTime at, ReminderSpec spec, int index})> reminderTimes() => [
        for (var i = 0; i < event.reminders.length; i++)
          if (event.reminders[i].at == null || !isRecurring)
            (at: event.reminders[i].fireTime(event.allDay ? DateTime(start.year, start.month, start.day, 9) : start), spec: event.reminders[i], index: i),
      ];
}

DateTime _asDate(DateTime value) {
  final utc = value.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Adds calendar days without drifting across DST changes.
DateTime _addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _dayString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _day(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}
