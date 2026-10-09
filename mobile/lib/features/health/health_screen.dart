import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

final medicationDashboardProvider = FutureProvider<Map<String, Object?>>((ref) async =>
    ref.watch(apiClientProvider)!.medicationDashboard());

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(medicationDashboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('Sağlık bilgileri alınamadı.')),
        data: (data) {
          final doses = (data['doses'] as List? ?? data['upcoming'] as List? ?? const []).cast<Map>();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(medicationDashboardProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.medication_rounded)),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${doses.length}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const Text('yaklaşan doz'),
                  ]),
                ]),
              )),
              const SizedBox(height: 20),
              Text('İlaç programı', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (doses.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aktif ilaç programı yok.'))),
              ...doses.take(12).map((raw) {
                final dose = Map<String, Object?>.from(raw);
                return Card(child: ListTile(
                  minTileHeight: 72,
                  leading: const Icon(Icons.medication_liquid_rounded),
                  title: Text(dose['medication_name'] as String? ?? dose['name'] as String? ?? 'İlaç'),
                  subtitle: Text(dose['dosage'] as String? ?? ''),
                  trailing: Text(_time(dose['notify_at'] ?? dose['scheduled_for'])),
                ));
              }),
            ]),
          );
        },
      );

  static String _time(Object? raw) {
    if (raw == null) return '';
    final value = DateTime.tryParse('$raw')?.toLocal();
    return value == null ? '' : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
