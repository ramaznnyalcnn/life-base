import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/routes.dart';
import 'package:lifebase_mobile/modules/account/ui/account_screen.dart';
import 'package:lifebase_mobile/modules/calendar/ui/event_edit_page.dart';
import 'package:lifebase_mobile/shell/router.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    // A tap that lands on something else (e.g. the add button hidden under
    // the floating bar) must fail the test, not just warn.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  // No device calendar in tests: the Android channel answers "nothing here"
  // (an unmocked channel would never reply inside fake async time).
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('app.lifebase.mobile/platform'),
        (call) async => call.method == 'googleStatus' ? <String, Object?>{} : <Object?>[],
      ));

  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.build(LbPalette.kum, Brightness.light),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String location() => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  testWidgets('glass bar offers the five modules, Bugün in the middle, and starts there', (tester) async {
    await pumpApp(tester);

    final labels = ['Cüzdan', 'Takvim', 'Bugün', 'İlaç', 'Notlar'];
    final xs = [for (final label in labels) tester.getCenter(find.bySemanticsLabel(label).last).dx];
    expect(xs, [...xs]..sort(), reason: 'left to right in this order');
    expect(location(), AppRoutes.today);
  });

  testWidgets('sliding a finger along the bar opens the tab it ends on', (tester) async {
    await pumpApp(tester);
    final bugun = tester.getCenter(find.bySemanticsLabel('Bugün').last);
    final notlar = tester.getCenter(find.bySemanticsLabel('Notlar').last);

    final gesture = await tester.startGesture(bugun);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(bugun, notlar, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(location(), AppRoutes.today, reason: 'nothing opens until the finger lifts');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(location(), AppRoutes.notes);
  });

  testWidgets('back inside a tab returns to the previous page, not out of the app', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Takvim');
    await tester.tap(find.byKey(const ValueKey('add-calendar')));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditPage), findsOneWidget);

    await pressBack(tester);

    expect(find.byType(EventEditPage), findsNothing);
    expect(location(), AppRoutes.calendar);
  });

  testWidgets('back on another tab root goes to Bugün', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Cüzdan');
    expect(location(), AppRoutes.wallet);

    await pressBack(tester);

    expect(location(), AppRoutes.today);
  });

  testWidgets('back on Bugün asks for a second press before leaving', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpApp(tester);

    await pressBack(tester);
    expect(find.text('Çıkmak için tekrar bas'), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    await pressBack(tester);
    expect(calls, contains('SystemNavigator.pop'));
  });

  testWidgets('the bar steps aside while a page is open and returns after', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Takvim');
    await tester.tap(find.byKey(const ValueKey('add-calendar')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cüzdan'), findsNothing);

    await pressBack(tester);
    expect(find.bySemanticsLabel('Cüzdan'), findsWidgets);
  });

  testWidgets('each tab keeps its own back stack while switching', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Takvim');
    await tester.tap(find.byKey(const ValueKey('add-calendar')));
    await tester.pumpAndSettle();

    // e.g. tapping an item on Bugün jumps to another tab.
    router.go(AppRoutes.wallet);
    await tester.pumpAndSettle();
    expect(find.byType(EventEditPage), findsNothing);

    await openTab(tester, 'Takvim');
    expect(find.byType(EventEditPage), findsOneWidget);
  });

  testWidgets('profile button opens account above the shell and back returns', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'İlaç');

    await tester.tap(find.bySemanticsLabel('Hesap ve ayarlar'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);

    await pressBack(tester);
    expect(find.byType(AccountScreen), findsNothing);
    expect(location(), AppRoutes.meds);
  });

  testWidgets('Android is always told the app handles back, so it never closes the app itself', (tester) async {
    // With predictive back, Android exits without asking Flutter when the
    // framework reports it cannot handle back. A tab's navigator reports that
    // after its last page pops; the shell must override it.
    final handlesBack = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') handlesBack.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpApp(tester);

    await openTab(tester, 'Takvim');
    await tester.tap(find.byKey(const ValueKey('add-calendar')));
    await tester.pumpAndSettle();
    await pressBack(tester);

    expect(handlesBack, isNotEmpty);
    expect(handlesBack.last, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('back on an add page with unsaved input asks first and stays in the tab', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Takvim');
    await tester.tap(find.byKey(const ValueKey('add-calendar')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Yarım kalan');
    await tester.pump();

    await pressBack(tester);

    expect(find.text('Vazgeçilsin mi?'), findsOneWidget);
    expect(location(), AppRoutes.calendar);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditPage), findsOneWidget);
  });

  testWidgets('a link to a calendar day opens the calendar on that day', (tester) async {
    await pumpApp(tester);
    router.go(AppRoutes.calendarOn(DateTime(2026, 12, 25)));
    await tester.pumpAndSettle();

    expect(location(), AppRoutes.calendar);
    expect(find.text('Aralık 2026'), findsOneWidget);
  });
}
