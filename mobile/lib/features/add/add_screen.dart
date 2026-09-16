import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/catalog.dart';
import '../../core/models/operation.dart';
import '../../core/providers.dart';
import '../calendar/calendar_screen.dart';
import '../finance/finance_screen.dart';
import '../health/health_screen.dart';
import '../today/today_controller.dart';

typedef OperationSetup = ({
  List<OperationDefinition> definitions,
  OperationContextData context,
});

final operationSetupProvider = FutureProvider<OperationSetup>((ref) async {
  final result = await ref.watch(apiClientProvider)!.operationSetup();
  return (definitions: result.$1, context: result.$2);
});

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  String? _group;
  OperationDefinition? _operation;
  final Map<String, Object?> _values = {};
  var _review = false;
  var _saving = false;

  @override
  Widget build(BuildContext context) => ref.watch(operationSetupProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('İşlem seçenekleri alınamadı.')),
        data: (setup) => AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
          child: _group == null
              ? _groups(setup)
              : _operation == null
                  ? _operations(setup)
                  : _review
                      ? _reviewPage(setup)
                      : _form(setup),
        ),
      );

  Widget _groups(OperationSetup setup) => ListView(
        key: const ValueKey('groups'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Ne yapmak istiyorsun?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Bir alan seç. Yazmadan adım adım ilerle.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _GroupCard(icon: Icons.task_alt_rounded, title: 'Planla', subtitle: 'Görev, etkinlik ve rutin', onTap: () => setState(() => _group = 'planning')),
          _GroupCard(icon: Icons.account_balance_wallet_rounded, title: 'Finans', subtitle: 'Harcama, gelir, transfer ve ödeme', onTap: () => setState(() => _group = 'finance')),
          _GroupCard(icon: Icons.medication_rounded, title: 'Sağlık', subtitle: 'İlaç programı ve doz', onTap: () => setState(() => _group = 'health')),
        ],
      );

  Widget _operations(OperationSetup setup) {
    final items = setup.definitions.where((item) => item.group == _group).toList();
    return ListView(key: const ValueKey('operations'), padding: const EdgeInsets.fromLTRB(12, 4, 16, 32), children: [
      Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: 'Geri', onPressed: _reset, icon: const Icon(Icons.arrow_back))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('İşlem seç', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 16),
      ...items.map((item) => Card(child: ListTile(
        minTileHeight: 68,
        title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _operation = item),
      ))),
    ]);
  }

  Widget _form(OperationSetup setup) => ListView(
        key: ValueKey('form-${_operation!.key}'),
        padding: const EdgeInsets.fromLTRB(12, 4, 16, 120),
        children: [
          Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: 'Geri', onPressed: () => setState(() { _operation = null; _values.clear(); }), icon: const Icon(Icons.arrow_back))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(_operation!.label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 20),
          ..._operation!.fields.where(_visible).map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _field(field, setup.context),
              )),
          FilledButton.icon(
            onPressed: _valid ? () => setState(() => _review = true) : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Kontrol et'),
          ),
        ],
      );

  Widget _field(OperationField field, OperationContextData operationContext) {
    final title = Text(field.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
    if (field.kind == FieldKind.choice) {
      final sourceOptions = operationContext.sources[field.optionSource] ?? const <ChoiceOption>[];
      final medicationId = _values['medication_id'];
      final options = field.key == 'scheduled_for' && medicationId != null
          ? sourceOptions
              .where((option) => option.metadata['medication_id'] == medicationId)
              .toList()
          : sourceOptions;
      final multiple = field.multiple;
      final selected = (_values[field.key] as List<Object?>?) ?? <Object?>[];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title, const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((option) {
          final isSelected = multiple ? selected.contains(option.value) : _values[field.key] == option.value;
          return ChoiceChip(
            label: Text(option.label),
            selected: isSelected,
            onSelected: option.enabled ? (_) => setState(() {
              if (multiple) {
                final next = List<Object?>.from(selected);
                isSelected ? next.remove(option.value) : next.add(option.value);
                _values[field.key] = next;
              } else {
                if (field.key == 'medication_id' &&
                    _values[field.key] != option.value) {
                  _values.remove('scheduled_for');
                }
                _values[field.key] = option.value;
                if (field.key == 'scheduled_for') {
                  final selectedMedication = option.metadata['medication_id'];
                  if (selectedMedication != null) {
                    _values['medication_id'] = selectedMedication;
                  }
                }
                final version = option.metadata['entity_version'];
                if (version != null) _values['expected_version'] = version;
              }
            }) : null,
          );
        }).toList()),
      ]);
    }
    if (field.kind == FieldKind.boolean) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: title,
        value: _values[field.key] as bool? ?? false,
        onChanged: (value) => setState(() => _values[field.key] = value),
      );
    }
    if (field.kind == FieldKind.date || field.kind == FieldKind.datetime) {
      return _PickerTile(
        title: field.label,
        value: _values[field.key] == null ? 'Seç' : _display(_values[field.key]),
        icon: Icons.calendar_today_rounded,
        onTap: () => _pickDate(field),
      );
    }
    if (field.kind == FieldKind.time) {
      return _PickerTile(
        title: field.label,
        value: _values[field.key] == null ? 'Seç' : _display(_values[field.key]),
        icon: Icons.schedule_rounded,
        onTap: () => _pickTime(field),
      );
    }
    if (field.kind == FieldKind.duration) {
      final choices = field.key == 'reminder_offsets_minutes' ? [0, 15, 60, 180, 1440] : [5, 10, 15, 30, 60];
      final multiple = field.key == 'reminder_offsets_minutes';
      final values = (_values[field.key] as List<int>?) ?? <int>[];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title, const SizedBox(height: 10),
        Wrap(spacing: 8, children: choices.map((minutes) {
          final selected = multiple ? values.contains(minutes) : _values[field.key] == minutes;
          return ChoiceChip(label: Text(minutes == 1440 ? '1 gün' : minutes == 0 ? 'Yok' : '$minutes dk'), selected: selected, onSelected: (_) => setState(() {
            if (multiple) {
              final next = List<int>.from(values);
              selected ? next.remove(minutes) : next.add(minutes);
              _values[field.key] = next.where((value) => value > 0).toList();
            } else {
              _values[field.key] = minutes;
            }
          }));
        }).toList()),
      ]);
    }
    final numeric = field.kind == FieldKind.money;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      title, const SizedBox(height: 10),
      TextFormField(
        initialValue: _values[field.key]?.toString(),
        maxLength: field.maxLength,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))] : null,
        decoration: InputDecoration(hintText: numeric ? '0,00' : 'Kısa ad'),
        onChanged: (value) => setState(() => _values[field.key] = numeric ? value.replaceAll(',', '.') : value.trim()),
      ),
    ]);
  }

  Widget _reviewPage(OperationSetup setup) => ListView(
        key: const ValueKey('review'),
        padding: const EdgeInsets.fromLTRB(12, 4, 16, 32),
        children: [
          Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: 'Geri', onPressed: () => setState(() => _review = false), icon: const Icon(Icons.arrow_back))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Son kontrol', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
          const SizedBox(height: 20),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: _operation!.fields.where((field) => _visible(field) && _values.containsKey(field.key)).map((field) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(field.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                Expanded(child: Text(_resolved(field, setup.context), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            )).toList()),
          )),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      );

  bool _visible(OperationField field) {
    if (field.key == 'expected_version') return false;
    if (field.visibleWhen case final conditions?) {
      if (!conditions.entries.every((entry) => _values[entry.key] == entry.value)) return false;
    }
    if (field.key == 'weekdays') return _values['schedule_mode'] != 'interval';
    if (field.key == 'interval_days') return _values['schedule_mode'] == 'interval';
    return true;
  }

  bool get _valid => _operation!.fields.where(_visible).every((field) {
    if (!field.required) return true;
    final value = _values[field.key];
    return value != null && value != '' && (value is! List || value.isNotEmpty);
  });

  Future<void> _pickDate(OperationField field) async {
    final selected = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (selected == null) return;
    if (field.kind == FieldKind.datetime) {
      if (!mounted) return;
      final clock = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (clock == null) return;
      setState(() => _values[field.key] = DateTime(selected.year, selected.month, selected.day, clock.hour, clock.minute).toIso8601String());
    } else {
      setState(() => _values[field.key] = DateFormat('yyyy-MM-dd').format(selected));
    }
  }

  Future<void> _pickTime(OperationField field) async {
    final selected = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (selected == null) return;
    final time = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}:00';
    setState(() {
      if (field.key == 'scheduled_at') {
        final due = DateTime.tryParse(_values['due_on']?.toString() ?? '') ?? DateTime.now();
        _values[field.key] = DateTime(due.year, due.month, due.day, selected.hour, selected.minute).toIso8601String();
      } else if (field.key == 'dose_times') {
        _values[field.key] = [time];
      } else {
        _values[field.key] = time;
      }
    });
  }

  String _resolved(OperationField field, OperationContextData data) {
    final value = _values[field.key];
    final options = data.sources[field.optionSource] ?? const <ChoiceOption>[];
    if (value is List) return value.map((item) => options.where((option) => option.value == item).firstOrNull?.label ?? '$item').join(', ');
    return options.where((option) => option.value == value).firstOrNull?.label ?? _display(value);
  }

  String _display(Object? value) => value is List ? value.join(', ') : '${value ?? ''}';

  Future<void> _save() async {
    setState(() => _saving = true);
    final sync = ref.read(syncServiceProvider)!;
    await sync.enqueue(OperationEnvelope(requestId: const Uuid().v4(), operationKey: _operation!.key, values: Map.of(_values)));
    final report = await sync.flush();
    await ref.read(platformBridgeProvider).syncNow();
    ref.invalidate(todayAgendaProvider);
    ref.invalidate(calendarItemsProvider);
    ref.invalidate(financeProvider);
    ref.invalidate(medicationDashboardProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(report.paused ? 'İşlem sıraya alındı. Oturum yenilenince gönderilecek.' : 'Kaydedildi.')));
    setState(() { _saving = false; _group = null; _operation = null; _values.clear(); _review = false; });
  }

  void _reset() => setState(() { _group = null; _operation = null; _values.clear(); _review = false; });
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      CircleAvatar(radius: 26, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle)])),
      const Icon(Icons.chevron_right),
    ])),
  ));
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.title, required this.value, required this.icon, required this.onTap});
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(minTileHeight: 64, leading: Icon(icon), title: Text(title), trailing: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)), onTap: onTap));
}
