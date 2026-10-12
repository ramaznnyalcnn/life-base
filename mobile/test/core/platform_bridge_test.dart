import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/platform/platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.lifebase.mobile/platform');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('the widget snapshot is handed to Android as it is', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });

    await const PlatformBridge().updateWidget('{"days":{}}');

    expect(captured?.method, 'updateWidgetSnapshot');
    expect(captured?.arguments, {'payload': '{"days":{}}'});
  });
}
