import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/providers.dart';
import 'meds_add_page.dart';

final medicationDashboardProvider = FutureProvider<Map<String, Object?>>((ref) async =>
    ref.watch(apiClientProvider)!.medicationDashboard());

class MedsScreen extends ConsumerWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final color = t.module(LbModule.meds);
    return ModuleScaffold(
      module: LbModule.meds,
      title: 'İlaç',
      addLabel: 'İlaç',
      addPageBuilder: (context) => const MedsAddPage(),
      body: ref.watch(medicationDashboardProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('İlaç bilgileri alınamadı.', style: TextStyle(color: t.muted))),
            data: (data) {
              final doses = (data['doses'] as List? ?? data['upcoming'] as List? ?? const []).cast<Map>();
              return RefreshIndicator(
                onRefresh: () => ref.refresh(medicationDashboardProvider.future),
                child: ListView(padding: moduleListPadding(context, hasAddButton: true), children: [
                  NeuSurface(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      Icon(Icons.medication_rounded, color: color, size: 32),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${doses.length}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: t.onBase)),
                        Text('yaklaşan doz', style: TextStyle(color: t.muted)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  Text('Program', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
                  const SizedBox(height: 12),
                  if (doses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('Aktif ilaç programı yok.', style: TextStyle(color: t.muted))),
                    ),
                  for (final raw in doses.take(12))
                    _DoseTile(dose: Map<String, Object?>.from(raw)),
                ]),
              );
            },
          ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.dose});
  final Map<String, Object?> dose;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        depth: 4,
        radius: LbTokens.radiusSmall + 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dose['medication_name'] as String? ?? dose['name'] as String? ?? 'İlaç',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
              Text(dose['dosage'] as String? ?? '', style: TextStyle(color: t.muted, fontSize: 12)),
            ]),
          ),
          Text(_time(dose['notify_at'] ?? dose['scheduled_for']),
              style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase)),
        ]),
      ),
    );
  }

  static String _time(Object? raw) {
    if (raw == null) return '';
    final value = DateTime.tryParse('$raw')?.toLocal();
    return value == null ? '' : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
