import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/notifications/in_app_reminders.dart';
import 'package:lifebase_mobile/core/notifications/notifications.dart';

void main() {
  test('only reminders that came due since the last check are shown, once', () {
    PlannedNotification at(String key, int minute) =>
        PlannedNotification(group: 'cal', key: key, title: key, body: '', at: DateTime(2026, 10, 12, 9, minute));
    final all = [at('a', 0), at('b', 1), at('c', 2)];
    List<PlannedNotification> plan(DateTime from) => [for (final n in all) if (n.at.isAfter(from)) n];

    final first = dueReminders(from: DateTime(2026, 10, 12, 8, 59, 30), to: DateTime(2026, 10, 12, 9, 1), plan: plan);
    final second = dueReminders(from: DateTime(2026, 10, 12, 9, 1), to: DateTime(2026, 10, 12, 9, 1, 30), plan: plan);

    expect([for (final n in first) n.key], ['a', 'b']);
    expect(second, isEmpty);
  });
}
