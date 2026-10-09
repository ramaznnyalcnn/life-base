import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/agenda.dart';
import '../../../core/models/operation.dart';
import '../../../core/providers.dart';

final todayAgendaProvider = FutureProvider<TodayAgenda>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) throw StateError('Oturum yok');
  final agenda = await api.today(DateTime.now());
  await ref.read(platformBridgeProvider).updateWidget(agenda);
  return agenda;
});

final quickActionProvider = Provider<QuickActionController>(QuickActionController.new);
final optimisticCompletedProvider = StateProvider<Set<String>>((ref) => <String>{});

class QuickActionController {
  QuickActionController(this.ref);
  final Ref ref;

  Future<void> complete(AgendaItem item) async {
    ref.read(optimisticCompletedProvider.notifier).state = {
      ...ref.read(optimisticCompletedProvider),
      item.id,
    };
    final operation = switch (item.kind) {
      'task' => OperationEnvelope(
          requestId: const Uuid().v4(),
          operationKey: 'planning.task.complete',
          values: {
            'task_id': item.sourceId,
            'expected_version': item.metadata['entity_version'],
          },
        ),
      'medication' => OperationEnvelope(
          requestId: const Uuid().v4(),
          operationKey: 'health.medication.take',
          values: {
            'medication_id': item.sourceId,
            'scheduled_for': item.metadata['scheduled_for'],
          },
        ),
      _ => throw StateError('Bu öğe hızlı tamamlanamaz.'),
    };
    final sync = ref.read(syncServiceProvider)!;
    await sync.enqueue(operation);
    final report = await sync.flush();
    await ref.read(platformBridgeProvider).syncNow();
    if (!report.paused && report.conflicts == 0) {
      final next = {...ref.read(optimisticCompletedProvider)}..remove(item.id);
      ref.read(optimisticCompletedProvider.notifier).state = next;
    }
    ref.invalidate(todayAgendaProvider);
  }

  Future<void> snooze(AgendaItem item, int minutes) async {
    if (item.kind != 'medication') return;
    final sync = ref.read(syncServiceProvider)!;
    await sync.enqueue(OperationEnvelope(
      requestId: const Uuid().v4(),
      operationKey: 'health.medication.snooze',
      values: {
        'medication_id': item.sourceId,
        'scheduled_for': item.metadata['scheduled_for'],
        'snooze_minutes': minutes,
      },
    ));
    await sync.flush();
    await ref.read(platformBridgeProvider).syncNow();
    ref.invalidate(todayAgendaProvider);
  }
}
