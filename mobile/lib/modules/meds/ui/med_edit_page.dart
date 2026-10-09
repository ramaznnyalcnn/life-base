import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/meds/medication.dart';
import '../data/medications_repository.dart';

const _weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _suggestedTimes = ['08:00', '09:00', '13:00', '18:00', '20:00', '22:00'];

/// Add or edit a medication (the İlaç module's own form).
class MedEditPage extends ConsumerStatefulWidget {
  const MedEditPage({super.key, this.initial});

  final Medication? initial;

  @override
  ConsumerState<MedEditPage> createState() => _MedEditPageState();
}

class _MedEditPageState extends ConsumerState<MedEditPage> {
  late Medication _med;
  late final Medication _original;
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _amount;
  late final TextEditingController _stock;
  late final TextEditingController _stockAlert;
  late bool _trackStock;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _med = widget.initial ??
        Medication(
          id: ref.read(medicationsRepositoryProvider).newId(),
          name: '',
          schedule: const MedSchedule.daily(['09:00']),
          startsOn: today,
        );
    _original = _med;
    _trackStock = _med.stock != null;
    _name = TextEditingController(text: _med.name)..addListener(_refresh);
    _notes = TextEditingController(text: _med.notes ?? '')..addListener(_refresh);
    _amount = TextEditingController(text: formatAmount(_med.doseAmount))..addListener(_refresh);
    _stock = TextEditingController(text: _med.stock == null ? '' : formatAmount(_med.stock!))..addListener(_refresh);
    _stockAlert = TextEditingController(text: _med.stockAlert == null ? '' : formatAmount(_med.stockAlert!))..addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _notes, _amount, _stock, _stockAlert]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Medication get _current {
    final notes = _notes.text.trim();
    return _med.copyWith(
      name: _name.text.trim(),
      notes: notes.isEmpty ? null : notes,
      clearNotes: notes.isEmpty,
      doseAmount: _number(_amount.text) ?? _med.doseAmount,
      stock: _trackStock ? (_number(_stock.text) ?? 0) : null,
      clearStock: !_trackStock,
      stockAlert: _trackStock ? _number(_stockAlert.text) : null,
      clearStockAlert: !_trackStock || _number(_stockAlert.text) == null,
    );
  }

  bool get _dirty {
    final a = _current, b = _original;
    return a.name != b.name ||
        a.notes != b.notes ||
        a.form != b.form ||
        a.doseAmount != b.doseAmount ||
        a.doseUnit != b.doseUnit ||
        a.mealRelation != b.mealRelation ||
        a.schedule != b.schedule ||
        a.startsOn != b.startsOn ||
        a.endsOn != b.endsOn ||
        a.stock != b.stock ||
        a.stockAlert != b.stockAlert ||
        a.alarm != b.alarm;
  }

  String? get _problem {
    final m = _current;
    if (m.name.isEmpty) return 'İlaç adı gerekli';
    if ((_number(_amount.text) ?? 0) <= 0) return 'Doz miktarı sıfırdan büyük olmalı';
    final s = m.schedule;
    if (s.mode != ScheduleMode.asNeeded && s.times.isEmpty) return 'En az bir saat seç';
    if (s.mode == ScheduleMode.weekdays && s.weekdays.isEmpty) return 'En az bir gün seç';
    if (m.endsOn != null && m.endsOn!.isBefore(m.startsOn)) return 'Bitiş, başlangıçtan önce olamaz';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await ref.read(medicationsRepositoryProvider).save(_current);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _setSchedule(MedSchedule schedule) => setState(() => _med = _med.copyWith(schedule: schedule));

  Future<void> _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked == null) return;
    _toggleTime('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}', add: true);
  }

  void _toggleTime(String time, {required bool add}) {
    final s = _med.schedule;
    final times = {...s.times};
    add ? times.add(time) : times.remove(time);
    _setSchedule(MedSchedule(mode: s.mode, times: times.toList()..sort(), weekdays: s.weekdays, intervalDays: s.intervalDays, intervalHours: s.intervalHours));
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final s = _med.schedule;
    final dateFmt = DateFormat('d MMMM y', 'tr_TR');
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(text, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        );

    return AddPageScaffold(
      title: _isNew ? 'Yeni ilaç' : 'İlacı düzenle',
      dirty: _dirty,
      onSave: _save,
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        TextField(
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.words,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          decoration: const InputDecoration(hintText: 'İlaç adı'),
        ),
        const SizedBox(height: 16),
        _Section(children: [
          label('Form'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in medForms.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _med.form == entry.key,
                onSelected: (_) => setState(() => _med = _med.copyWith(form: entry.key)),
              ),
          ]),
          const SizedBox(height: 12),
          label('Doz'),
          Row(children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final unit in doseUnits)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(unit),
                        selected: _med.doseUnit == unit,
                        onSelected: (_) => setState(() => _med = _med.copyWith(doseUnit: unit)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          label('Ne zaman?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (mode, text) in const [
              (ScheduleMode.times, 'Her gün'),
              (ScheduleMode.weekdays, 'Belirli günler'),
              (ScheduleMode.everyNDays, 'N günde bir'),
              (ScheduleMode.everyNHours, 'N saatte bir'),
              (ScheduleMode.asNeeded, 'Gerektiğinde'),
            ])
              ChoiceChip(
                label: Text(text),
                selected: s.mode == mode,
                onSelected: (_) => _setSchedule(MedSchedule(
                  mode: mode,
                  times: s.times.isEmpty && mode != ScheduleMode.asNeeded ? const ['09:00'] : s.times,
                  weekdays: s.weekdays.isEmpty ? [DateTime.now().weekday] : s.weekdays,
                  intervalDays: s.intervalDays,
                  intervalHours: s.intervalHours,
                )),
              ),
          ]),
          const SizedBox(height: 12),
          if (s.mode == ScheduleMode.weekdays)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_weekdayShort[d - 1]),
                  selected: s.weekdays.contains(d),
                  onSelected: (on) => _setSchedule(MedSchedule(
                    mode: s.mode,
                    times: s.times,
                    weekdays: on ? [...s.weekdays, d] : (s.weekdays.length > 1 ? ([...s.weekdays]..remove(d)) : s.weekdays),
                  )),
                ),
            ]),
          if (s.mode == ScheduleMode.everyNDays)
            _Stepper(
              text: s.intervalDays == 1 ? 'Her gün' : '${s.intervalDays} günde bir',
              onMinus: s.intervalDays > 1 ? () => _setSchedule(MedSchedule(mode: s.mode, times: s.times, intervalDays: s.intervalDays - 1)) : null,
              onPlus: () => _setSchedule(MedSchedule(mode: s.mode, times: s.times, intervalDays: s.intervalDays + 1)),
            ),
          if (s.mode == ScheduleMode.everyNHours) ...[
            _Stepper(
              text: '${s.intervalHours} saatte bir',
              onMinus: s.intervalHours > 1 ? () => _setSchedule(MedSchedule(mode: s.mode, times: s.times, intervalHours: s.intervalHours - 1)) : null,
              onPlus: s.intervalHours < 72 ? () => _setSchedule(MedSchedule(mode: s.mode, times: s.times, intervalHours: s.intervalHours + 1)) : null,
            ),
            Text('İlk doz saati aşağıda; sonrakiler arka arkaya hesaplanır.', style: TextStyle(color: t.muted, fontSize: 12)),
          ],
          if (s.mode != ScheduleMode.asNeeded) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final time in s.mode == ScheduleMode.everyNHours ? s.times.take(1) : s.times)
                InputChip(
                  label: Text(time, style: const TextStyle(fontWeight: FontWeight.w800)),
                  onDeleted: s.times.length > 1 ? () => _toggleTime(time, add: false) : null,
                  onPressed: () async {
                    final (h, m) = (int.parse(time.substring(0, 2)), int.parse(time.substring(3)));
                    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
                    if (picked == null) return;
                    _toggleTime(time, add: false);
                    _toggleTime('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}', add: true);
                  },
                ),
              if (s.mode != ScheduleMode.everyNHours) ...[
                ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Saat'), onPressed: _addTime),
                for (final time in _suggestedTimes.where((x) => !s.times.contains(x)).take(3))
                  ActionChip(label: Text('+ $time'), onPressed: () => _toggleTime(time, add: true)),
              ],
            ]),
          ] else
            Text('Alarm çalmaz; aldığında İlaç ekranından kaydedersin.', style: TextStyle(color: t.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        _Section(children: [
          _Row(
            label: 'Başlangıç',
            value: dateFmt.format(_med.startsOn),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _med.startsOn, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() => _med = _med.copyWith(startsOn: picked));
            },
          ),
          _Row(
            label: 'Bitiş',
            value: _med.endsOn == null ? 'Süresiz' : '${dateFmt.format(_med.endsOn!)} · ${_med.endsOn!.difference(_med.startsOn).inDays + 1} gün',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _med.endsOn ?? _med.startsOn.add(const Duration(days: 6)),
                firstDate: _med.startsOn,
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _med = _med.copyWith(endsOn: picked));
            },
          ),
          Wrap(spacing: 8, children: [
            for (final days in const [5, 7, 10, 14, 30])
              ActionChip(
                label: Text('$days gün'),
                onPressed: () => setState(() => _med = _med.copyWith(endsOn: _med.startsOn.add(Duration(days: days - 1)))),
              ),
            if (_med.endsOn != null)
              ActionChip(label: const Text('Süresiz'), onPressed: () => setState(() => _med = _med.copyWith(clearEndsOn: true))),
          ]),
          const SizedBox(height: 8),
        ]),
        const SizedBox(height: 16),
        _Section(children: [
          label('Yemekle ilişkisi'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in mealRelations.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _med.mealRelation == entry.key,
                onSelected: (on) => setState(() => _med = on ? _med.copyWith(mealRelation: entry.key) : _med.copyWith(clearMealRelation: true)),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Not (örn. bol suyla)'),
          ),
          const SizedBox(height: 4),
        ]),
        const SizedBox(height: 16),
        _Section(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Stok takibi'),
            subtitle: const Text('Her alınan doz stoktan düşer'),
            value: _trackStock,
            onChanged: (on) => setState(() => _trackStock = on),
          ),
          if (_trackStock)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _stock,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Elde (${_med.doseUnit})'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _stockAlert,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Uyarı eşiği'),
                ),
              ),
            ]),
          const SizedBox(height: 8),
        ]),
        if (!_med.asNeeded) ...[
          const SizedBox(height: 16),
          _Section(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tam ekran alarm'),
              subtitle: const Text('Kilit ekranında alarm gibi açılır'),
              value: _med.alarm.fullScreen,
              onChanged: (on) => setState(() => _med = _med.copyWith(alarm: _med.alarm.copyWith(fullScreen: on))),
            ),
            label('Ertele'),
            _MinuteChips(
              values: const [5, 10, 15, 30],
              selected: _med.alarm.snoozeMinutes,
              onSelected: (v) => setState(() => _med = _med.copyWith(alarm: _med.alarm.copyWith(snoozeMinutes: v))),
            ),
            label('Alınmazsa tekrar çal'),
            _MinuteChips(
              values: const [5, 10, 15, 30],
              selected: _med.alarm.repeatEveryMinutes,
              onSelected: (v) => setState(() => _med = _med.copyWith(alarm: _med.alarm.copyWith(repeatEveryMinutes: v))),
            ),
            _Stepper(
              text: _med.alarm.maxRepeats == 0 ? 'Tekrar yok' : '${_med.alarm.maxRepeats} kez tekrar',
              onMinus: _med.alarm.maxRepeats > 0 ? () => setState(() => _med = _med.copyWith(alarm: _med.alarm.copyWith(maxRepeats: _med.alarm.maxRepeats - 1))) : null,
              onPlus: _med.alarm.maxRepeats < maxAlarmRepeats ? () => setState(() => _med = _med.copyWith(alarm: _med.alarm.copyWith(maxRepeats: _med.alarm.maxRepeats + 1))) : null,
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NeuSurface(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: t.muted),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.text, required this.onMinus, required this.onPlus});
  final String text;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          IconButton.filledTonal(tooltip: 'Azalt', onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          Expanded(
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: LbTokens.of(context).onBase, fontWeight: FontWeight.w800)),
          ),
          IconButton.filledTonal(tooltip: 'Artır', onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ]),
      );
}

class _MinuteChips extends StatelessWidget {
  const _MinuteChips({required this.values, required this.selected, required this.onSelected});
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: [
        for (final v in {...values, selected}.toList()..sort())
          ChoiceChip(label: Text('$v dk'), selected: v == selected, onSelected: (_) => onSelected(v)),
      ]);
}
