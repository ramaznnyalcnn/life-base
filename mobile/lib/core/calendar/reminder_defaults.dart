import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_event.dart';

/// Quick picks offered when adding a reminder.
const reminderPresets = [
  ReminderSpec.before(Duration.zero),
  ReminderSpec.before(Duration(minutes: 10)),
  ReminderSpec.before(Duration(minutes: 30)),
  ReminderSpec.before(Duration(hours: 1)),
  ReminderSpec.before(Duration(days: 1)),
];

/// "Anında", "10 dk önce", "1 sa 30 dk önce", "2 gün önce", "9 Eki 08:00".
String reminderLabel(ReminderSpec spec) {
  final at = spec.at;
  if (at != null) return DateFormat('d MMM HH:mm', 'tr_TR').format(at.toLocal());
  final offset = spec.offset!;
  if (offset == Duration.zero) return 'Anında';
  final days = offset.inDays, hours = offset.inHours % 24, minutes = offset.inMinutes % 60;
  final parts = [if (days > 0) '$days gün', if (hours > 0) '$hours sa', if (minutes > 0) '$minutes dk'];
  return '${parts.join(' ')} önce';
}

final defaultRemindersProvider = NotifierProvider<DefaultReminders, List<ReminderSpec>>(DefaultReminders.new);

/// The reminder set every new event starts with (editable in settings).
class DefaultReminders extends Notifier<List<ReminderSpec>> {
  static const _key = 'calendar.default_reminders';
  static const fallback = [ReminderSpec.before(Duration(minutes: 30))];

  @override
  List<ReminderSpec> build() {
    _load();
    return fallback;
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || !ref.mounted) return;
    state = (jsonDecode(raw) as List).cast<Map>().map((r) => ReminderSpec.fromJson(Map<String, Object?>.from(r))).toList();
  }

  Future<void> set(List<ReminderSpec> value) async {
    state = value;
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final r in value) r.toJson()]));
  }
}
