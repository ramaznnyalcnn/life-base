import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/models/agenda.dart';
import 'package:lifebase_mobile/core/platform/platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.lifebase.mobile/platform');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('widget task action includes the optimistic concurrency version', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });
    final task = AgendaItem(
      id: 'task:7',
      sourceId: 7,
      kind: 'task',
      title: 'Kontrol',
      day: DateTime(2026, 9, 16),
      metadata: const {'entity_version': 4},
    );
    final agenda = TodayAgenda(
      date: DateTime(2026, 9, 16),
      version: 1,
      overdue: const [],
      tasks: [task],
      timeline: const [],
    );

    await const PlatformBridge().updateWidget(agenda);

    expect(captured?.method, 'updateWidgetSnapshot');
    final arguments = Map<String, Object?>.from(captured?.arguments as Map);
    final payload = Map<String, Object?>.from(
      jsonDecode(arguments['payload']! as String) as Map,
    );
    final action = Map<String, Object?>.from(payload['action']! as Map);
    expect(action['entity_version'], 4);
  });
}
