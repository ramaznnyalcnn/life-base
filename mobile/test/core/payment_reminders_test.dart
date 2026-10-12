import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/notifications/notifications.dart';
import 'package:lifebase_mobile/core/wallet/payment_reminders.dart';
import 'package:lifebase_mobile/core/wallet/wallet_models.dart';

ScheduledPayment rent({DateTime? due, bool completed = false, bool monthly = true}) => ScheduledPayment(
      id: 'rent',
      title: 'Kira',
      accountId: 'bank',
      amount: 1500000,
      dueAt: due ?? DateTime(2026, 10, 31, 9),
      repeatMonthly: monthly,
      completed: completed,
      createdBy: 1,
    );

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('a payment rings the day before and on the day at nine', () {
    final planned = planPaymentReminders([rent()], DateTime(2026, 10, 12));

    expect([for (final n in planned) n.at], [DateTime(2026, 10, 30, 9), DateTime(2026, 10, 31, 9)]);
    expect([for (final n in planned) n.body], ['Yarın son gün', 'Bugün son gün']);
    expect(planned.first.title, 'Kira · ₺15.000');
    expect(planned.first.channel, NotificationChannel.wallet);
  });

  test('past, paid and due-today-after-nine reminders are left out', () {
    expect(planPaymentReminders([rent(completed: true)], DateTime(2026, 10, 12)), isEmpty);
    expect(planPaymentReminders([rent()], DateTime(2026, 10, 31, 10)), isEmpty);
    expect(planPaymentReminders([rent()], DateTime(2026, 10, 30, 12)).single.body, 'Bugün son gün');
  });

  test('paying a monthly payment moves its reminders to the next due date', () {
    final paid = rent().paid(DateTime(2026, 10, 30, 20));
    final before = planPaymentReminders([rent()], DateTime(2026, 10, 12));
    final after = planPaymentReminders([paid], DateTime(2026, 10, 30, 20));

    expect(paid.dueAt, DateTime(2026, 11, 30, 9));
    expect(paid.completed, isFalse);
    expect(after.first.at, DateTime(2026, 11, 29, 9));
    expect(after.first.id, isNot(before.first.id));
    expect(rent(monthly: false).paid(DateTime(2026, 10, 30)).completed, isTrue);
  });
}
