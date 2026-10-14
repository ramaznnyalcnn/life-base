import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/neu.dart';
import '../../../core/design_system/reveal_on_scroll.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/card_summary.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';

/// Categorical colours in fixed slot order (validated for colour-vision
/// deficiency on the app's light and dark surfaces).
const _lightSlots = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), Color(0xFFE87BA4)];
const _darkSlots = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), Color(0xFFD55181)];
const _otherColor = Color(0xFF898781);

Color _sliceColor(BuildContext context, int? slot) {
  if (slot == null) return _otherColor;
  return (Theme.of(context).brightness == Brightness.dark ? _darkSlots : _lightSlots)[slot];
}

String _percent(Cents part, Cents total) => total <= 0 ? '' : '%${(part * 100 / total).round()}';

/// A card's spending and payments: totals, categories, months, people. Each
/// block draws itself in as it scrolls into view.
class CardSummarySection extends ConsumerStatefulWidget {
  const CardSummarySection({super.key, required this.card, required this.wallet, required this.now});

  final WalletAccount card;
  final WalletData wallet;
  final DateTime now;

  @override
  ConsumerState<CardSummarySection> createState() => _CardSummarySectionState();
}

class _CardSummarySectionState extends ConsumerState<CardSummarySection> {
  var _period = SummaryPeriod.month;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final summary = summarizeCard(widget.card, widget.wallet, _period, widget.now);
    final members = {for (final m in ref.watch(walletMembersProvider).value ?? const <HouseholdMember>[]) m.userId: m.name};
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(top: 24, bottom: 8), child: Text('Özet', style: heading)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final period in SummaryPeriod.values)
          ChoiceChip(label: Text(period.label), selected: _period == period, onSelected: (_) => setState(() => _period = period)),
      ]),
      const SizedBox(height: 12),
      RevealOnScroll(
        builder: (context, _) => Row(children: [
          Expanded(child: _StatTile(label: 'Harcama', value: summary.spent)),
          const SizedBox(width: 12),
          Expanded(child: _StatTile(label: 'Ödeme', value: summary.paid)),
        ]),
      ),
      const SizedBox(height: 12),
      RevealOnScroll(
        builder: (context, reveal) => NeuSurface(
          child: summary.slices.isEmpty
              ? Text('${_period.label} harcama yok.', style: TextStyle(color: t.muted))
              : _CategoryDonut(key: ValueKey(_period), summary: summary, reveal: reveal),
        ),
      ),
      const SizedBox(height: 12),
      RevealOnScroll(
        builder: (context, reveal) => NeuSurface(child: _MonthBars(months: summary.months, reveal: reveal)),
      ),
      if (summary.byPerson.length > 1) ...[
        const SizedBox(height: 12),
        RevealOnScroll(
          builder: (context, reveal) => NeuSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Kim harcadı', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final entry in summary.byPerson.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                _PersonRow(name: members[entry.key] ?? 'Hane üyesi', amount: entry.value, total: summary.spent, reveal: reveal),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final Cents value;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return NeuSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatMoney(value), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: t.onBase)),
        ),
      ]),
    );
  }
}

/// Spending by category: a ring the user can tap, with a legend that always
/// names every slice and its amount (colour is never the only label).
class _CategoryDonut extends StatefulWidget {
  const _CategoryDonut({super.key, required this.summary, required this.reveal});
  final CardSummary summary;
  final Animation<double> reveal;

  @override
  State<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<_CategoryDonut> {
  int? _selected;

  static const _size = 180.0;
  static const _stroke = 22.0;

  int? _hit(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    final d = local - center;
    final radius = d.distance;
    // A generous ring: the thumb is bigger than the stroke.
    if (radius < _size / 2 - _stroke - 14 || radius > _size / 2 + 8) return null;
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final total = widget.summary.slices.fold<int>(0, (s, c) => s + c.amount);
    if (total <= 0) return null;
    var start = 0.0;
    for (var i = 0; i < widget.summary.slices.length; i++) {
      final sweep = widget.summary.slices[i].amount / total * 2 * math.pi;
      if (angle >= start && angle < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final slices = widget.summary.slices;
    final total = slices.fold<int>(0, (s, c) => s + c.amount);
    if ((_selected ?? 0) >= slices.length) _selected = null;
    final selected = _selected == null ? null : slices[_selected!];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Kategoriler', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          onTapUp: (details) => setState(() {
            final hit = _hit(details.localPosition);
            _selected = hit == _selected ? null : hit;
          }),
          child: SizedBox.square(
            dimension: _size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, grow, _) => AnimatedBuilder(
                animation: widget.reveal,
                builder: (context, _) => CustomPaint(
                  painter: _DonutPainter(
                    slices: slices,
                    colors: [for (final s in slices) _sliceColor(context, s.slot)],
                    progress: grow * widget.reveal.value,
                    selected: _selected,
                    stroke: _stroke,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(_stroke + 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(selected?.name ?? 'Toplam',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(formatMoney(selected?.amount ?? total, short: true),
                              style: TextStyle(color: t.onBase, fontWeight: FontWeight.w900, fontSize: 18)),
                        ),
                        if (selected != null) Text(_percent(selected.amount, total), style: TextStyle(color: t.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < slices.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selected = _selected == i ? null : i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: _sliceColor(context, slices[i].slot), borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(slices[i].name,
                    style: TextStyle(color: t.onBase, fontWeight: _selected == i ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text(formatMoney(slices[i].amount, short: true), style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700)),
              SizedBox(
                width: 48,
                child: Text(_percent(slices[i].amount, total), textAlign: TextAlign.end, style: TextStyle(color: t.muted)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.colors, required this.progress, required this.selected, required this.stroke});

  final List<CategorySlice> slices;
  final List<Color> colors;
  final double progress;
  final int? selected;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (s, c) => s + c.amount);
    if (total <= 0) return;
    final radius = size.shortestSide / 2 - stroke / 2 - 3;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    // A 2px gap between slices, as an angle on this ring.
    final gap = slices.length > 1 ? 2 / radius : 0.0;
    final limit = 2 * math.pi * progress;
    var start = 0.0;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].amount / total * 2 * math.pi;
      final visible = math.min(sweep, limit - start) - gap;
      if (visible > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == selected ? stroke + 6 : stroke
          ..color = selected == null || i == selected ? colors[i] : colors[i].withValues(alpha: .35);
        canvas.drawArc(rect, -math.pi / 2 + start + gap / 2, visible, false, paint);
      }
      start += sweep;
      if (start >= limit) break;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.selected != selected || old.slices != slices || old.colors != colors;
}

/// The last six months' spending as bars; tap a month to read its amount.
class _MonthBars extends StatefulWidget {
  const _MonthBars({required this.months, required this.reveal});
  final List<MonthSpend> months;
  final Animation<double> reveal;

  @override
  State<_MonthBars> createState() => _MonthBarsState();
}

class _MonthBarsState extends State<_MonthBars> {
  late int _selected = widget.months.length - 1;

  static const _height = 120.0;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final months = widget.months;
    final top = months.fold<int>(0, (m, e) => math.max(m, e.amount));
    final color = _sliceColor(context, 0);
    final label = DateFormat('MMM', 'tr_TR');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Aylık harcama', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700))),
        Text('${DateFormat('MMMM', 'tr_TR').format(months[_selected].month)} · ${formatMoney(months[_selected].amount, short: true)}',
            style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 16),
      AnimatedBuilder(
        animation: widget.reveal,
        builder: (context, _) => SizedBox(
          height: _height,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = i),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      height: top <= 0 ? 2 : math.max(2, months[i].amount / top * _height * widget.reveal.value),
                      decoration: BoxDecoration(
                        color: i == _selected ? color : color.withValues(alpha: .4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
      Container(height: 1, color: t.shade),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: Text(label.format(months[i].month),
                textAlign: TextAlign.center,
                style: TextStyle(color: i == _selected ? t.onBase : t.muted, fontSize: 12, fontWeight: i == _selected ? FontWeight.w800 : null)),
          ),
      ]),
    ]);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, required this.amount, required this.total, required this.reveal});
  final String name;
  final Cents amount;
  final Cents total;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final share = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(name, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w700))),
          Text('${formatMoney(amount, short: true)}  ${_percent(amount, total)}', style: TextStyle(color: t.muted)),
        ]),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: reveal,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share * reveal.value,
              minHeight: 6,
              backgroundColor: t.sunken,
              color: t.onBase.withValues(alpha: .55),
            ),
          ),
        ),
      ]),
    );
  }
}
