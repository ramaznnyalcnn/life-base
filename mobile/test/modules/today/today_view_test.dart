import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/meds/medication.dart';
import 'package:lifebase_mobile/core/meds/meds_store.dart';
import 'package:lifebase_mobile/core/models/agenda.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/wallet/wallet_models.dart';
import 'package:lifebase_mobile/core/wallet/wallet_outbox.dart';
import 'package:lifebase_mobile/modules/today/data/today_view.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  // Monday 12 October 2026, 10:00.
  final now = DateTime(2026, 10, 12, 10);
  final today = DateTime(2026, 10, 12);
  final parol = Medication(id: 'parol', name: 'Parol', schedule: const MedSchedule.daily(['07:00', '13:00', '21:00']), startsOn: DateTime(2026, 10, 1), doseAmount: 1, doseUnit: 'tablet');

  EventOccurrence event(String title, int hour, {int minutes = 60, bool allDay = false}) => EventOccurrence(
        CalendarEvent(
          id: title,
          title: title,
          startsAt: allDay ? today : DateTime(2026, 10, 12, hour),
          endsAt: allDay ? today.add(const Duration(days: 1)) : DateTime(2026, 10, 12, hour).add(Duration(minutes: minutes)),
          allDay: allDay,
        ),
        allDay ? today : DateTime(2026, 10, 12, hour),
      );

  LocalDoseLog log(String time, String status) {
    final at = DateTime(2026, 10, 12, int.parse(time.split(':')[0]));
    return LocalDoseLog(id: doseLogId('parol', at), updatedAtMs: 0, dirty: false, medicationId: 'parol', scheduledFor: at, status: status);
  }

  List<DoseEntry> doses(Map<String, LocalDoseLog> logs, DateTime at) =>
      doseEntries([parol], logs, today, today.add(const Duration(hours: 23, minutes: 59)), at);

  test('events, Google events and doses make one timeline, all-day first', () {
    final view = buildToday(
      events: [event('Toplantı', 14), event('Bayram', 0, allDay: true)],
      google: [AgendaItem(id: 'google:1', sourceId: 1, kind: 'google', title: 'Dişçi', day: today, startsAt: DateTime(2026, 10, 12, 11), endsAt: DateTime(2026, 10, 12, 11, 30))],
      doses: doses({}, now),
      now: now,
    );

    expect([for (final item in view.timeline) item.title], ['Bayram', 'Dişçi', 'Parol', 'Toplantı', 'Parol']);
    expect(view.missed.single.dose.at, DateTime(2026, 10, 12, 7), reason: '07:00 is over two hours late');
    expect(view.next?.title, 'Dişçi');
  });

  test('a dose due a few minutes ago comes first; answered doses step aside', () {
    final at = DateTime(2026, 10, 12, 13, 10);
    final pending = buildToday(events: [event('Toplantı', 14)], google: const [], doses: doses({}, at), now: at);
    expect(pending.next?.dose?.dose.at, DateTime(2026, 10, 12, 13));

    final taken = buildToday(events: [event('Toplantı', 14)], google: const [], doses: doses({log('13:00', 'taken').id: log('13:00', 'taken')}, at), now: at);
    expect(taken.next?.title, 'Toplantı');
    expect(taken.timeline.firstWhere((i) => i.dose?.dose.at.hour == 13).done, isTrue);
  });

  test('greeting, countdown and durations read naturally', () {
    expect(greeting(DateTime(2026, 10, 12, 7)), 'Günaydın');
    expect(greeting(DateTime(2026, 10, 12, 14)), 'İyi günler');
    expect(greeting(DateTime(2026, 10, 12, 19)), 'İyi akşamlar');
    expect(greeting(DateTime(2026, 10, 12, 2)), 'İyi geceler');
    expect(countdown(DateTime(2026, 10, 12, 10, 12), now), '12 dk sonra');
    expect(countdown(DateTime(2026, 10, 12, 11, 5), now), '1 sa 5 dk sonra');
    expect(countdown(DateTime(2026, 10, 12, 12), now), '2 sa sonra');
    expect(countdown(DateTime(2026, 10, 12, 9, 52), now), '8 dk geçti');
    expect(countdown(now.add(const Duration(seconds: 20)), now), 'Şimdi');
    expect(shortDuration(TodayItem.event(event('A', 9, minutes: 90))), '1sa 30dk');
    expect(shortDuration(TodayItem.event(event('A', 9, minutes: 45))), '45dk');
    expect(shortDuration(TodayItem.event(event('A', 0, allDay: true))), 'Tüm gün');
  });

  test('the wallet glance sums today and lists what is due within a week', () {
    final wallet = WalletData(
      accounts: {
        'bank': const WalletAccount(id: 'bank', ownerId: 1, name: 'Banka', type: AccountType.bank, balance: 100000),
        'card': const WalletAccount(id: 'card', ownerId: 1, name: 'Bonus', type: AccountType.creditCard, balance: -120000, statementDay: 5, dueDay: 15),
      },
      transactions: {
        't1': WalletTransaction(id: 't1', accountId: 'card', kind: TxKind.expense, amount: 120000, occurredAt: DateTime(2026, 10, 1, 12), createdBy: 1),
        't2': WalletTransaction(id: 't2', accountId: 'bank', kind: TxKind.expense, amount: 4550, occurredAt: DateTime(2026, 10, 12, 9), createdBy: 1),
        't3': WalletTransaction(id: 't3', accountId: 'bank', kind: TxKind.income, amount: 99999, occurredAt: DateTime(2026, 10, 12, 9), createdBy: 1),
      },
      payments: {
        'rent': ScheduledPayment(id: 'rent', title: 'Kira', accountId: 'bank', amount: 1500000, dueAt: DateTime(2026, 10, 13, 9), createdBy: 1),
        'later': ScheduledPayment(id: 'later', title: 'Sigorta', accountId: 'bank', amount: 50000, dueAt: DateTime(2026, 11, 20, 9), createdBy: 1),
      },
    );

    final glance = walletGlance(wallet, now)!;
    expect(glance.spentToday, 4550);
    expect([for (final due in glance.dues) due.title], ['Kira', 'Bonus']);
    expect(glance.dues.last.due, DateTime(2026, 10, 15));
    expect(glance.dues.last.amount, 120000);
    expect(dueIn(DateTime(2026, 10, 15), now), '3 gün sonra');
    expect(dueIn(DateTime(2026, 10, 10), now), '2 gün gecikti');
    expect(walletGlance(const WalletData(), now), isNull);
  });

  test('the widget snapshot lists today and tomorrow without answered doses', () {
    final view = buildToday(
      events: [event('Toplantı', 14), event('Bayram', 0, allDay: true)],
      google: const [],
      doses: doses({log('13:00', 'taken').id: log('13:00', 'taken')}, now),
      now: now,
    );
    final snapshot = widgetSnapshot({today: view, today.add(const Duration(days: 1)): buildToday(events: const [], google: const [], doses: const [], now: now)}, now);
    final days = snapshot['days']! as Map;
    final items = days['2026-10-12']! as List;

    expect([for (final i in items) '${(i as Map)['time']} ${i['title']} ${i['detail']}'.trim()], ['Tüm gün Bayram Tüm gün', '14:00 Toplantı 1sa', '21:00 Parol · 1 tablet']);
    expect((items.first as Map)['until'], isNull);
    expect((items[1] as Map)['until'], DateTime(2026, 10, 12, 15).millisecondsSinceEpoch);
    expect(days['2026-10-13'], isEmpty);
  });
}
