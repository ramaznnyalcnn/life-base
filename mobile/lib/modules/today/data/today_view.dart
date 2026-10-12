import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/meds/medication.dart';
import '../../../core/meds/meds_store.dart';
import '../../../core/models/agenda.dart';
import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';

enum TodayKind { event, google, dose }

/// One line of Bugün's timeline: a LifeBase event, a Google event or a dose.
@immutable
class TodayItem {
  const TodayItem._({
    required this.kind,
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.important = false,
    this.occurrence,
    this.dose,
  });

  factory TodayItem.event(EventOccurrence occurrence) => TodayItem._(
        kind: TodayKind.event,
        id: 'event:${occurrence.key}',
        title: occurrence.event.title,
        start: occurrence.start,
        end: occurrence.end,
        allDay: occurrence.event.allDay,
        important: occurrence.event.important,
        occurrence: occurrence,
      );

  factory TodayItem.google(AgendaItem item) => TodayItem._(
        kind: TodayKind.google,
        id: item.id,
        title: item.title,
        start: item.startsAt ?? item.day,
        end: item.endsAt,
        allDay: item.isAllDay,
      );

  factory TodayItem.dose(DoseEntry entry) => TodayItem._(
        kind: TodayKind.dose,
        id: 'dose:${entry.dose.id}',
        title: entry.dose.medication.name,
        start: entry.dose.at,
        dose: entry,
      );

  final TodayKind kind;
  final String id;
  final String title;

  /// Local time; midnight for all-day events.
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final bool important;
  final EventOccurrence? occurrence;
  final DoseEntry? dose;

  /// Answered doses stay in the timeline, struck through.
  bool get done => dose != null && (dose!.status == DoseStatus.taken || dose!.status == DoseStatus.skipped);
}

@immutable
class TodayView {
  const TodayView({required this.timeline, required this.next, required this.missed});

  /// All-day first, then by time.
  final List<TodayItem> timeline;

  /// The soonest thing still ahead: an event yet to start or a dose not yet
  /// answered (a dose due a few minutes ago comes first).
  final TodayItem? next;

  /// Today's doses left unanswered too long.
  final List<DoseEntry> missed;
}

TodayView buildToday({
  required List<EventOccurrence> events,
  required List<AgendaItem> google,
  required List<DoseEntry> doses,
  required DateTime now,
}) {
  final timeline = [
    ...events.map(TodayItem.event),
    ...google.map(TodayItem.google),
    for (final dose in doses)
      if (dose.status != DoseStatus.missed) TodayItem.dose(dose),
  ]..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
  final upcoming = timeline.where((item) {
    if (item.allDay) return false;
    if (item.dose != null) return item.dose!.status == DoseStatus.pending || item.dose!.status == DoseStatus.snoozed;
    return !item.start.isBefore(now);
  });
  return TodayView(
    timeline: timeline,
    next: upcoming.firstOrNull,
    missed: [for (final dose in doses) if (dose.status == DoseStatus.missed) dose],
  );
}

/// "Günaydın", "İyi günler", "İyi akşamlar", "İyi geceler".
String greeting(DateTime now) => switch (now.hour) {
      >= 5 && < 11 => 'Günaydın',
      >= 11 && < 17 => 'İyi günler',
      >= 17 && < 22 => 'İyi akşamlar',
      _ => 'İyi geceler',
    };

/// "Şimdi", "12 dk sonra", "1 sa 5 dk sonra", "8 dk geçti".
String countdown(DateTime at, DateTime now) {
  final minutes = at.difference(now).inSeconds / 60;
  final whole = minutes.abs().ceil();
  if (whole == 0 || minutes.abs() < 1) return 'Şimdi';
  final text = whole < 60 ? '$whole dk' : (whole % 60 == 0 ? '${whole ~/ 60} sa' : '${whole ~/ 60} sa ${whole % 60} dk');
  return minutes > 0 ? '$text sonra' : '$text geçti';
}

/// "45dk", "1sa", "1sa 30dk", "Tüm gün".
String shortDuration(TodayItem item) {
  if (item.allDay) return 'Tüm gün';
  final minutes = item.end?.difference(item.start).inMinutes ?? 0;
  if (minutes <= 0) return '';
  if (minutes < 60) return '${minutes}dk';
  return minutes % 60 == 0 ? '${minutes ~/ 60}sa' : '${minutes ~/ 60}sa ${minutes % 60}dk';
}

/// Something in the wallet that wants paying soon.
@immutable
class WalletDue {
  const WalletDue({required this.title, required this.due, required this.amount, this.payment});

  final String title;
  final DateTime due;
  final Cents amount;

  /// Set for a planned payment (so Bugün can offer "Ödendi").
  final ScheduledPayment? payment;
}

@immutable
class WalletGlance {
  const WalletGlance({required this.spentToday, required this.dues});

  final Cents spentToday;

  /// Card statements and planned payments due within a week or overdue, soonest first.
  final List<WalletDue> dues;
}

/// Bugün's look at the wallet; null when there are no accounts yet.
WalletGlance? walletGlance(WalletData wallet, DateTime now, {Duration within = const Duration(days: 7)}) {
  if (wallet.accounts.values.where((a) => a.active).isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(within);
  final spent = wallet.transactions.values
      .where((tx) => tx.kind == TxKind.expense && !tx.occurredAt.isBefore(today) && tx.occurredAt.isBefore(today.add(const Duration(days: 1))))
      .fold<Cents>(0, (sum, tx) => sum + tx.amount);
  final dues = <WalletDue>[
    for (final card in wallet.accounts.values.where((a) => a.active && a.isCard))
      if (upcomingDue(card, wallet, now) case final period? when period.due != null && !period.due!.isAfter(horizon))
        WalletDue(title: card.name, due: period.due!, amount: period.remaining),
    for (final payment in wallet.payments.values)
      if (!payment.completed && !payment.dueAt.isAfter(horizon))
        WalletDue(title: payment.title, due: payment.dueAt, amount: payment.amount, payment: payment),
  ]..sort((a, b) => a.due.compareTo(b.due));
  return WalletGlance(spentToday: spent, dues: dues);
}

/// "Bugün", "Yarın", "3 gün sonra", "2 gün gecikti".
String dueIn(DateTime due, DateTime now) {
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return switch (days) {
    0 => 'Bugün',
    1 => 'Yarın',
    < 0 => '${-days} gün gecikti',
    _ => '$days gün sonra',
  };
}

/// What the 3×1 home-screen widget shows, for today and tomorrow: the widget
/// refreshes on its own every half hour and drops what has ended, so it stays
/// right even when the app is not opened.
Map<String, Object?> widgetSnapshot(Map<DateTime, TodayView> days, DateTime now) {
  final time = DateFormat('HH:mm');
  return {
    'generated_at': now.millisecondsSinceEpoch,
    'days': {
      for (final entry in days.entries)
        DateFormat('yyyy-MM-dd').format(entry.key): [
          for (final item in entry.value.timeline.where((item) => !item.done))
            {
              'time': item.allDay ? 'Tüm gün' : time.format(item.start),
              'title': item.dose == null ? item.title : '${item.title} · ${item.dose!.dose.medication.doseLabel}',
              'detail': item.dose == null ? shortDuration(item) : '',
              // The widget hides an entry once it has ended (all-day: never).
              'until': item.allDay ? null : (item.end ?? item.start.add(const Duration(minutes: 30))).millisecondsSinceEpoch,
            },
        ],
    },
  };
}
