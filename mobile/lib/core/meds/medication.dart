import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../household/household.dart';
import '../storage/app_database.dart';

enum ScheduleMode { times, weekdays, everyNDays, everyNHours, asNeeded }

/// When doses are due. Clock times are local "HH:mm".
@immutable
class MedSchedule {
  const MedSchedule({
    required this.mode,
    this.times = const [],
    this.weekdays = const [],
    this.intervalDays = 1,
    this.intervalHours = 8,
  });

  const MedSchedule.daily(List<String> times) : this(mode: ScheduleMode.times, times: times);

  factory MedSchedule.fromJson(Map<String, Object?> json) => MedSchedule(
        mode: ScheduleMode.values.asNameMap()[json['mode']] ?? ScheduleMode.asNeeded,
        times: ((json['times'] as List?) ?? const []).whereType<String>().where(_validTime).toList()..sort(),
        weekdays: ((json['weekdays'] as List?) ?? const []).whereType<num>().map((d) => d.toInt()).where((d) => d >= 1 && d <= 7).toList()..sort(),
        intervalDays: ((json['intervalDays'] as num?)?.toInt() ?? 1).clamp(1, 365),
        intervalHours: ((json['intervalHours'] as num?)?.toInt() ?? 8).clamp(1, 72),
      );

  final ScheduleMode mode;

  /// Dose times for [ScheduleMode.times], [ScheduleMode.weekdays] and
  /// [ScheduleMode.everyNDays]; the first one anchors [ScheduleMode.everyNHours].
  final List<String> times;
  final List<int> weekdays;
  final int intervalDays;
  final int intervalHours;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        if (times.isNotEmpty) 'times': [...times]..sort(),
        if (mode == ScheduleMode.weekdays) 'weekdays': [...weekdays]..sort(),
        if (mode == ScheduleMode.everyNDays) 'intervalDays': intervalDays,
        if (mode == ScheduleMode.everyNHours) 'intervalHours': intervalHours,
      };

  @override
  bool operator ==(Object other) => other is MedSchedule && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  static bool _validTime(String value) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
}

/// Upper bound for [AlarmSettings.maxRepeats].
const maxAlarmRepeats = 10;

/// How the dose alarm behaves.
@immutable
class AlarmSettings {
  const AlarmSettings({this.fullScreen = true, this.snoozeMinutes = 10, this.repeatEveryMinutes = 5, this.maxRepeats = 3});

  factory AlarmSettings.fromJson(Map<String, Object?> json) => AlarmSettings(
        fullScreen: json['fullScreen'] != false,
        snoozeMinutes: ((json['snoozeMinutes'] as num?)?.toInt() ?? 10).clamp(1, 240),
        repeatEveryMinutes: ((json['repeatEveryMinutes'] as num?)?.toInt() ?? 5).clamp(1, 120),
        maxRepeats: ((json['maxRepeats'] as num?)?.toInt() ?? 3).clamp(0, maxAlarmRepeats),
      );

  /// Open over the lock screen like an alarm clock.
  final bool fullScreen;
  final int snoozeMinutes;

  /// When not answered, ring again every [repeatEveryMinutes], [maxRepeats] times.
  final int repeatEveryMinutes;
  final int maxRepeats;

  AlarmSettings copyWith({bool? fullScreen, int? snoozeMinutes, int? repeatEveryMinutes, int? maxRepeats}) => AlarmSettings(
        fullScreen: fullScreen ?? this.fullScreen,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
        repeatEveryMinutes: repeatEveryMinutes ?? this.repeatEveryMinutes,
        maxRepeats: maxRepeats ?? this.maxRepeats,
      );

  Map<String, Object?> toJson() => {
        'fullScreen': fullScreen,
        'snoozeMinutes': snoozeMinutes,
        'repeatEveryMinutes': repeatEveryMinutes,
        'maxRepeats': maxRepeats,
      };

  @override
  bool operator ==(Object other) => other is AlarmSettings && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

const medForms = {
  'tablet': 'Tablet',
  'capsule': 'Kapsül',
  'syrup': 'Şurup',
  'drops': 'Damla',
  'injection': 'İğne',
  'spray': 'Sprey',
  'cream': 'Krem',
  'other': 'Diğer',
};

const doseUnits = ['tablet', 'kapsül', 'mg', 'ml', 'damla', 'ölçek', 'puf', 'IU', 'adet'];

const mealRelations = {
  'empty_stomach': 'Aç karnına',
  'before_meal': 'Yemekten önce',
  'with_meal': 'Yemekle',
  'after_meal': 'Yemekten sonra',
};

@immutable
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.schedule,
    required this.startsOn,
    this.form = 'tablet',
    this.doseAmount = 1,
    this.doseUnit = 'tablet',
    this.mealRelation,
    this.notes,
    this.endsOn,
    this.stock,
    this.stockAlert,
    this.alarm = const AlarmSettings(),
    this.active = true,
    this.createdBy,
    this.notify = notifyAll,
  });

  factory Medication.fromRow(LocalMedication row) => Medication(
        id: row.id,
        name: row.name,
        form: row.form,
        doseAmount: row.doseAmount,
        doseUnit: row.doseUnit,
        mealRelation: row.mealRelation,
        notes: row.notes,
        schedule: MedSchedule.fromJson(Map<String, Object?>.from(jsonDecode(row.schedule) as Map)),
        startsOn: _dateOf(row.startsOn),
        endsOn: row.endsOn == null ? null : _dateOf(row.endsOn!),
        stock: row.stock,
        stockAlert: row.stockAlert,
        alarm: AlarmSettings.fromJson(Map<String, Object?>.from(jsonDecode(row.alarm) as Map)),
        active: row.active,
        createdBy: row.createdBy,
        notify: row.notify,
      );

  final String id;
  final String name;
  final String form;
  final double doseAmount;
  final String doseUnit;
  final String? mealRelation;
  final String? notes;
  final MedSchedule schedule;

  /// First and last (inclusive) day of the course, local dates.
  final DateTime startsOn;
  final DateTime? endsOn;
  final double? stock;
  final double? stockAlert;
  final AlarmSettings alarm;
  final bool active;

  /// Household member who added it.
  final int? createdBy;

  /// Whose phone rings: [notifyAll] or a user id.
  final String notify;

  bool get lowStock => stock != null && stockAlert != null && stock! <= stockAlert!;
  bool get asNeeded => schedule.mode == ScheduleMode.asNeeded;

  /// "1 tablet", "2,5 ml"
  String get doseLabel => '${formatAmount(doseAmount)} $doseUnit';

  bool endedBy(DateTime day) => endsOn != null && DateTime(day.year, day.month, day.day).isAfter(endsOn!);

  Medication copyWith({
    String? id,
    String? name,
    String? form,
    double? doseAmount,
    String? doseUnit,
    String? mealRelation,
    bool clearMealRelation = false,
    String? notes,
    bool clearNotes = false,
    MedSchedule? schedule,
    DateTime? startsOn,
    DateTime? endsOn,
    bool clearEndsOn = false,
    double? stock,
    bool clearStock = false,
    double? stockAlert,
    bool clearStockAlert = false,
    AlarmSettings? alarm,
    bool? active,
    int? createdBy,
    String? notify,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        form: form ?? this.form,
        doseAmount: doseAmount ?? this.doseAmount,
        doseUnit: doseUnit ?? this.doseUnit,
        mealRelation: clearMealRelation ? null : mealRelation ?? this.mealRelation,
        notes: clearNotes ? null : notes ?? this.notes,
        schedule: schedule ?? this.schedule,
        startsOn: startsOn ?? this.startsOn,
        endsOn: clearEndsOn ? null : endsOn ?? this.endsOn,
        stock: clearStock ? null : stock ?? this.stock,
        stockAlert: clearStockAlert ? null : stockAlert ?? this.stockAlert,
        alarm: alarm ?? this.alarm,
        active: active ?? this.active,
        createdBy: createdBy ?? this.createdBy,
        notify: notify ?? this.notify,
      );

  LocalMedicationsCompanion toRow(int stampMs) => LocalMedicationsCompanion.insert(
        id: id,
        name: name,
        form: Value(form),
        doseAmount: Value(doseAmount),
        doseUnit: Value(doseUnit),
        mealRelation: Value(mealRelation),
        notes: Value(notes),
        schedule: jsonEncode(schedule.toJson()),
        startsOn: DateTime.utc(startsOn.year, startsOn.month, startsOn.day),
        endsOn: Value(endsOn == null ? null : DateTime.utc(endsOn!.year, endsOn!.month, endsOn!.day)),
        stock: Value(stock),
        stockAlert: Value(stockAlert),
        alarm: Value(jsonEncode(alarm.toJson())),
        active: Value(active),
        createdBy: Value(createdBy),
        notify: Value(notify),
        updatedAtMs: stampMs,
        deletedAtMs: const Value(null),
        dirty: const Value(true),
      );

  /// Scheduled doses due in [from, to) (local time), oldest first.
  List<ScheduledDose> dosesBetween(DateTime from, DateTime to) {
    if (!active || asNeeded) return const [];
    final result = <ScheduledDose>[];
    final lastDay = endsOn;
    bool inCourse(DateTime at) {
      final day = DateTime(at.year, at.month, at.day);
      return !day.isBefore(startsOn) && (lastDay == null || !day.isAfter(lastDay));
    }

    void add(DateTime at) {
      if (!at.isBefore(from) && at.isBefore(to) && inCourse(at)) result.add(ScheduledDose(this, at));
    }

    final s = schedule;
    if (s.mode == ScheduleMode.everyNHours) {
      final anchorTime = _parse(s.times.isEmpty ? '08:00' : s.times.first);
      var at = DateTime(startsOn.year, startsOn.month, startsOn.day, anchorTime.$1, anchorTime.$2);
      final step = Duration(hours: s.intervalHours);
      if (from.isAfter(at)) {
        at = at.add(step * (from.difference(at).inMinutes ~/ step.inMinutes));
      }
      for (; at.isBefore(to); at = at.add(step)) {
        add(at);
      }
      return result;
    }
    for (var day = DateTime(from.year, from.month, from.day); day.isBefore(to); day = DateTime(day.year, day.month, day.day + 1)) {
      final due = switch (s.mode) {
        ScheduleMode.weekdays => s.weekdays.contains(day.weekday),
        ScheduleMode.everyNDays => !day.isBefore(startsOn) && day.difference(startsOn).inDays % s.intervalDays == 0,
        _ => true,
      };
      if (!due) continue;
      for (final time in s.times) {
        final (h, m) = _parse(time);
        add(DateTime(day.year, day.month, day.day, h, m));
      }
    }
    return result..sort((a, b) => a.at.compareTo(b.at));
  }
}

/// One scheduled intake of a medication.
@immutable
class ScheduledDose {
  const ScheduledDose(this.medication, this.at);

  final Medication medication;

  /// Local time the dose is due.
  final DateTime at;

  /// Sync document id shared by every device: `<medicationId>@<UTC ISO>`.
  String get id => doseLogId(medication.id, at);

  @override
  bool operator ==(Object other) => other is ScheduledDose && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String doseLogId(String medicationId, DateTime at) =>
    '$medicationId@${at.toUtc().toIso8601String().split('.').first}Z';

/// The reverse of [doseLogId]; [at] is local time.
({String medicationId, DateTime at})? parseDoseLogId(String id) {
  final split = id.lastIndexOf('@');
  final at = split < 0 ? null : DateTime.tryParse(id.substring(split + 1));
  return at == null ? null : (medicationId: id.substring(0, split), at: at.toLocal());
}

enum DoseStatus { pending, taken, skipped, snoozed, missed }

/// A dose's state given its log. Doses still unanswered [missedAfter] past
/// their time count as missed.
DoseStatus doseStatus(ScheduledDose dose, LocalDoseLog? log, DateTime now, {Duration missedAfter = const Duration(hours: 2)}) {
  if (log != null && log.deletedAtMs == null) {
    switch (log.status) {
      case 'taken':
        return DoseStatus.taken;
      case 'skipped':
        return DoseStatus.skipped;
      case 'snoozed':
        if (log.snoozedUntil != null && log.snoozedUntil!.isAfter(now)) return DoseStatus.snoozed;
    }
  }
  return now.difference(dose.at) > missedAfter ? DoseStatus.missed : DoseStatus.pending;
}

String formatAmount(double value) {
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}

(int, int) _parse(String time) {
  final parts = time.split(':');
  return (int.parse(parts[0]), int.parse(parts[1]));
}

DateTime _dateOf(DateTime stored) {
  final utc = stored.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}
