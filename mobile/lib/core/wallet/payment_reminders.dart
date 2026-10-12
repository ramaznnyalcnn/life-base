import '../notifications/notifications.dart';
import 'wallet_models.dart';

const paymentNotificationGroup = 'wal';

/// The hour of the day payment reminders ring.
const paymentReminderHour = 9;

/// A reminder the day before a payment is due and one on the day, both at
/// [paymentReminderHour]; paid and past ones are left out.
List<PlannedNotification> planPaymentReminders(Iterable<ScheduledPayment> payments, DateTime now) {
  final planned = <PlannedNotification>[];
  for (final payment in payments) {
    if (payment.completed) continue;
    final due = payment.dueAt;
    final dueDay = DateTime(due.year, due.month, due.day, paymentReminderHour);
    for (final (index, at, body) in [
      (0, dueDay.subtract(const Duration(days: 1)), 'Yarın son gün'),
      (1, dueDay, 'Bugün son gün'),
    ]) {
      if (!at.isAfter(now)) continue;
      planned.add(PlannedNotification(
        group: paymentNotificationGroup,
        // The due date is part of the key: paying a monthly one moves both on.
        key: '${payment.id}@${due.millisecondsSinceEpoch}#$index',
        title: '${payment.title} · ${formatMoney(payment.amount, short: true)}',
        body: body,
        at: at,
        channel: NotificationChannel.wallet,
      ));
    }
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned;
}
