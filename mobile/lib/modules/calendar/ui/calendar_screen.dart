import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event.dart';
import '../../../core/calendar/calendar_store.dart';
import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/models/agenda.dart';
import '../../../core/platform/device_calendar.dart';
import 'calendar_format.dart';
import 'event_detail_page.dart';
import 'event_edit_page.dart';

enum CalendarView { month, week, day }

enum CalendarSource { all, lifebase, google }

final calendarDayProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));
final calendarViewProvider = StateProvider<CalendarView>((ref) => CalendarView.month);
final calendarSourceProvider = StateProvider<CalendarSource>((ref) => CalendarSource.all);

/// One row on the calendar: a LifeBase occurrence or a Google event.
class CalendarItem {
  CalendarItem.local(EventOccurrence this.occurrence)
      : google = null,
        key = occurrence.key,
        title = occurrence.event.title,
        start = occurrence.start,
        end = occurrence.end,
        allDay = occurrence.event.allDay,
        colorValue = occurrence.event.color,
        notes = occurrence.event.notes,
        hasReminders = occurrence.event.reminders.isNotEmpty;

  CalendarItem.google(AgendaItem this.google)
      : occurrence = null,
        key = google.id,
        title = google.title,
        start = google.startsAt ?? google.day,
        end = google.endsAt ?? google.startsAt ?? google.day.add(const Duration(days: 1)),
        allDay = google.isAllDay,
        colorValue = google.metadata['color'] as int?,
        notes = google.metadata['location'] as String?,
        hasReminders = false;

  final EventOccurrence? occurrence;
  final AgendaItem? google;
  final String key;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final int? colorValue;
  final String? notes;
  final bool hasReminders;

  bool get isGoogle => google != null;

  /// Whether this item is on the calendar on [day] (multi-day items span).
  bool covers(DateTime day) {
    final first = DateUtils.dateOnly(start);
    var last = DateUtils.dateOnly(end);
    // An end at exactly midnight (or an all-day end) belongs to the day before.
    if (allDay || (end.hour == 0 && end.minute == 0 && end.isAfter(start))) last = last.subtract(const Duration(days: 1));
    if (last.isBefore(first)) last = first;
    return !day.isBefore(first) && !day.isAfter(last);
  }
}

({DateTime from, DateTime to}) visibleRange(CalendarView view, DateTime day) {
  switch (view) {
    case CalendarView.month:
      final first = DateTime(day.year, day.month);
      final gridStart = DateTime(first.year, first.month, 1 - (first.weekday - 1));
      return (from: gridStart, to: DateTime(gridStart.year, gridStart.month, gridStart.day + 41));
    case CalendarView.week:
      final start = DateTime(day.year, day.month, day.day - (day.weekday - 1));
      return (from: start, to: DateTime(start.year, start.month, start.day + 6));
    case CalendarView.day:
      return (from: day, to: day);
  }
}

final calendarItemsProvider = Provider<List<CalendarItem>>((ref) {
  final range = visibleRange(ref.watch(calendarViewProvider), ref.watch(calendarDayProvider));
  final source = ref.watch(calendarSourceProvider);
  final local = source == CalendarSource.google
      ? const <CalendarItem>[]
      : occurrencesIn(ref.watch(localEventsProvider).value ?? const [], range.from, range.to).map(CalendarItem.local);
  final google = source == CalendarSource.lifebase
      ? const <CalendarItem>[]
      : (ref.watch(deviceEventsProvider((from: range.from, to: range.to))).value ?? const []).map(CalendarItem.google);
  return [...local, ...google]..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final day = ref.watch(calendarDayProvider);
    final items = ref.watch(calendarItemsProvider);
    final t = LbTokens.of(context);
    final reduce = t.reduceMotion || MediaQuery.disableAnimationsOf(context);

    void move(int direction) {
      final DateTime next;
      switch (view) {
        case CalendarView.month:
          final target = DateTime(day.year, day.month + direction);
          final lastDay = DateTime(target.year, target.month + 1, 0).day;
          next = DateTime(target.year, target.month, math.min(day.day, lastDay));
        case CalendarView.week:
          next = DateTime(day.year, day.month, day.day + 7 * direction);
        case CalendarView.day:
          next = DateTime(day.year, day.month, day.day + direction);
      }
      ref.read(calendarDayProvider.notifier).state = next;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final dayItems = items.where((item) => item.covers(day)).toList();

    Widget swipe(Widget child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() > 250) move(v < 0 ? 1 : -1);
          },
          child: child,
        );

    return ModuleScaffold(
      module: LbModule.calendar,
      title: 'Takvim',
      addLabel: 'Etkinlik',
      addPageBuilder: (context) => EventEditPage(day: ref.read(calendarDayProvider)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(children: [
            IconButton(tooltip: 'Önceki', onPressed: () => move(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) ref.read(calendarDayProvider.notifier).state = picked;
                },
                child: Text(
                  view == CalendarView.day ? DateFormat('d MMMM y', 'tr_TR').format(day) : DateFormat('MMMM y', 'tr_TR').format(day),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase),
                ),
              ),
            ),
            IconButton(tooltip: 'Sonraki', onPressed: () => move(1), icon: const Icon(Icons.chevron_right_rounded)),
            if (day != today)
              TextButton(onPressed: () => ref.read(calendarDayProvider.notifier).state = today, child: const Text('Bugün')),
            const _SourceMenu(),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<CalendarView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CalendarView.month, label: Text('Ay')),
                ButtonSegment(value: CalendarView.week, label: Text('Hafta')),
                ButtonSegment(value: CalendarView.day, label: Text('Gün')),
              ],
              selected: {view},
              onSelectionChanged: (value) => ref.read(calendarViewProvider.notifier).state = value.first,
            ),
          ),
        ),
        if (view == CalendarView.month)
          swipe(AnimatedSwitcher(
            duration: reduce ? Duration.zero : LbTokens.motion,
            child: _MonthGrid(key: ValueKey('${day.year}-${day.month}'), month: day, selected: day, today: today, items: items),
          )),
        if (view == CalendarView.week) swipe(_WeekStrip(selected: day, today: today, items: items)),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : LbTokens.motionShort,
            child: view == CalendarView.day
                ? swipe(_DayTimeline(key: ValueKey(day), day: day, items: dayItems, isToday: day == today))
                : _DayList(key: ValueKey(day), day: day, items: dayItems),
          ),
        ),
      ]),
    );
  }
}

class _SourceMenu extends ConsumerWidget {
  const _SourceMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(calendarSourceProvider);
    return PopupMenuButton<CalendarSource>(
      tooltip: 'Gösterilen takvimler',
      icon: Icon(source == CalendarSource.all ? Icons.filter_list_rounded : Icons.filter_list_alt),
      initialValue: source,
      onSelected: (value) => ref.read(calendarSourceProvider.notifier).state = value,
      itemBuilder: (_) => const [
        PopupMenuItem(value: CalendarSource.all, child: Text('Tümü')),
        PopupMenuItem(value: CalendarSource.lifebase, child: Text('Sadece LifeBase')),
        PopupMenuItem(value: CalendarSource.google, child: Text('Sadece Google')),
      ],
    );
  }
}

List<Color> _dots(BuildContext context, List<CalendarItem> items, DateTime day) =>
    items.where((item) => item.covers(day)).take(3).map((item) => eventColor(context, item.colorValue)).toList();

/// Six-week month grid. Each day shows up to three colour dots.
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({super.key, required this.month, required this.selected, required this.today, required this.items});
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final start = visibleRange(CalendarView.month, month).from;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        Row(children: [
          for (final name in weekdayShort)
            Expanded(child: Center(child: Text(name, style: TextStyle(color: t.muted, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 4),
        for (var week = 0; week < 6; week++)
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(builder: (context) {
                  final day = DateTime(start.year, start.month, start.day + week * 7 + i);
                  return _DayCell(
                    day: day,
                    inMonth: day.month == month.month,
                    selected: day == selected,
                    today: day == today,
                    colors: _dots(context, items, day),
                    onTap: () => ref.read(calendarDayProvider.notifier).state = day,
                  );
                }),
              ),
          ]),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.colors,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final accent = t.module(LbModule.calendar);
    return Semantics(
      button: true,
      selected: selected,
      label: '${DateFormat('d MMMM EEEE', 'tr_TR').format(day)}${colors.isEmpty ? '' : ', etkinlik var'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 46,
          margin: const EdgeInsets.all(2),
          decoration: selected ? neuDecoration(t, radius: 14, sunken: true) : null,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 28,
              height: 24,
              alignment: Alignment.center,
              decoration: today ? BoxDecoration(color: accent.withValues(alpha: .18), borderRadius: BorderRadius.circular(8)) : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: today ? accent : (inMonth ? t.onBase : t.muted.withValues(alpha: .55)),
                  fontWeight: selected || today ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final color in colors)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({required this.selected, required this.today, required this.items});
  final DateTime selected;
  final DateTime today;
  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final start = visibleRange(CalendarView.week, selected).from;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(start.year, start.month, start.day + i);
              return Column(children: [
                Text(weekdayShort[i], style: TextStyle(color: t.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                _DayCell(
                  day: day,
                  inMonth: true,
                  selected: day == selected,
                  today: day == today,
                  colors: _dots(context, items, day),
                  onTap: () => ref.read(calendarDayProvider.notifier).state = day,
                ),
              ]);
            }),
          ),
      ]),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({super.key, required this.day, required this.items});
  final DateTime day;
  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return ListView(
      padding: moduleListPadding(context, hasAddButton: true).copyWith(top: 12),
      children: [
        Text(DateFormat('d MMMM, EEEE', 'tr_TR').format(day),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('Bu gün boş.', style: TextStyle(color: t.muted))),
          ),
        for (final item in items) _ItemTile(item: item, day: day),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.day});
  final CalendarItem item;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final color = eventColor(context, item.colorValue);
    final continues = !DateUtils.isSameDay(item.start, day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => openCalendarItem(context, item),
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            SizedBox(
              width: 58,
              child: Text(
                item.allDay ? 'Tüm gün' : (continues ? 'devam' : DateFormat('HH:mm').format(item.start)),
                style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
                if (item.notes != null)
                  Text(item.notes!.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.muted, fontSize: 12)),
              ]),
            ),
            if (item.isGoogle) Text('Google', style: TextStyle(color: t.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            if (item.occurrence?.isRecurring ?? false) Icon(Icons.repeat_rounded, size: 16, color: t.muted),
            if (item.hasReminders)
              Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.notifications_none_rounded, size: 16, color: t.muted)),
          ]),
        ),
      ),
    );
  }
}

/// 24-hour column with events placed by time; overlapping events share the
/// width side by side.
class _DayTimeline extends StatefulWidget {
  const _DayTimeline({super.key, required this.day, required this.items, required this.isToday});
  final DateTime day;
  final List<CalendarItem> items;
  final bool isToday;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  static const hourHeight = 60.0;
  late final ScrollController _scroll;

  List<CalendarItem> get _timed => widget.items.where((i) => !i.allDay && DateUtils.isSameDay(i.start, widget.day)).toList();

  @override
  void initState() {
    super.initState();
    final timed = _timed;
    final firstHour = timed.isEmpty ? (widget.isToday ? DateTime.now().hour - 1 : 8) : timed.first.start.hour - 1;
    _scroll = ScrollController(initialScrollOffset: math.max(0, firstHour) * hourHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final timed = _timed;
    final allDay = widget.items.where((i) => !timed.contains(i)).toList();
    final columns = layoutColumns(timed);
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    return Column(children: [
      if (allDay.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in allDay)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: eventColor(context, item.colorValue), radius: 5),
                label: Text(item.title),
                onPressed: () => openCalendarItem(context, item),
              ),
          ]),
        ),
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox(
            height: 24 * hourHeight,
            child: LayoutBuilder(builder: (context, constraints) {
              const gutter = 56.0;
              final width = constraints.maxWidth - gutter - 16;
              final now = DateTime.now();
              return Stack(children: [
                for (var h = 0; h < 24; h++)
                  Positioned(
                    top: h * hourHeight,
                    left: 0,
                    right: 0,
                    child: Row(children: [
                      SizedBox(
                        width: gutter,
                        child: Text('${h.toString().padLeft(2, '0')}:00', textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: t.shade.withValues(alpha: .5), height: 1)),
                    ]),
                  ),
                for (final item in timed) _block(context, item, columns[item]!, gutter, width),
                if (widget.isToday)
                  Positioned(
                    top: (now.hour * 60 + now.minute) / 60 * hourHeight,
                    left: gutter - 4,
                    right: 0,
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle)),
                      Expanded(child: Container(height: 2, color: t.danger)),
                    ]),
                  ),
              ]);
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _block(BuildContext context, CalendarItem item, (int, int) slot, double gutter, double width) {
    final t = LbTokens.of(context);
    final (column, count) = slot;
    final top = (item.start.hour * 60 + item.start.minute) / 60 * hourHeight;
    final minutes = math.max(30, item.end.difference(item.start).inMinutes);
    final height = math.min(minutes / 60 * hourHeight, 24 * hourHeight - top) - 2;
    final color = eventColor(context, item.colorValue);
    return Positioned(
      top: top,
      left: gutter + column * width / count,
      width: width / count - 4,
      height: height,
      child: GestureDetector(
        onTap: () => openCalendarItem(context, item),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Text(
            '${DateFormat('HH:mm').format(item.start)} ${item.title}',
            maxLines: math.max(1, (height / 18).floor()),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/// Greedy column assignment for overlapping timed items:
/// item → (its column, number of columns in its overlap group).
Map<CalendarItem, (int, int)> layoutColumns(List<CalendarItem> items) {
  final sorted = [...items]..sort((a, b) => a.start.compareTo(b.start));
  final result = <CalendarItem, (int, int)>{};
  var group = <CalendarItem>[];
  var columnEnds = <DateTime>[];
  DateTime? groupEnd;

  void flush() {
    for (final item in group) {
      result[item] = (result[item]!.$1, columnEnds.length);
    }
    group = [];
    columnEnds = [];
    groupEnd = null;
  }

  for (final item in sorted) {
    final end = item.end.isAfter(item.start) ? item.end : item.start.add(const Duration(minutes: 30));
    if (groupEnd != null && !item.start.isBefore(groupEnd!)) flush();
    var column = columnEnds.indexWhere((e) => !item.start.isBefore(e));
    if (column == -1) {
      column = columnEnds.length;
      columnEnds.add(end);
    } else {
      columnEnds[column] = end;
    }
    result[item] = (column, 1);
    group.add(item);
    if (groupEnd == null || end.isAfter(groupEnd!)) groupEnd = end;
  }
  flush();
  return result;
}

/// LifeBase items open their detail page; Google items show a read-only sheet.
void openCalendarItem(BuildContext context, CalendarItem item) {
  final occurrence = item.occurrence;
  if (occurrence != null) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EventDetailPage(occurrence: occurrence)));
    return;
  }
  final t = LbTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('d MMMM y, EEEE', 'tr_TR').format(item.start)} · ${timeRange(item.start, item.end, allDay: item.allDay)}',
            style: TextStyle(color: t.onBase),
          ),
          if (item.notes != null) ...[const SizedBox(height: 6), Text(item.notes!, style: TextStyle(color: t.muted))],
          const SizedBox(height: 16),
          Text('Google takviminden geliyor; değişiklikleri Google Takvim’de yap.', style: TextStyle(color: t.muted, fontSize: 12)),
        ]),
      ),
    ),
  );
}
