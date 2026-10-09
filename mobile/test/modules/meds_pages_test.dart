import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/meds/medication.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/core/routes.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/modules/meds/ui/med_detail_page.dart';
import 'package:lifebase_mobile/modules/meds/ui/med_edit_page.dart';
import 'package:lifebase_mobile/shell/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  late AppDatabase db;
  late List<MethodCall> platformCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.lifebase.mobile/platform'),
      (call) async {
        platformCalls.add(call);
        return call.method == 'googleStatus' ? <String, Object?>{} : <Object?>[];
      },
    );
  });

  /// A phone-sized screen and a fresh database, closed with the test. The
  /// tree is unmounted first so drift's stream timers finish inside it.
  void setUpTest(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  final today = DateUtils.dateOnly(DateTime.now());
  Medication vitamin({DateTime? startsOn}) => Medication(
        id: 'm1',
        name: 'D vitamini',
        schedule: const MedSchedule.daily(['09:00']),
        startsOn: startsOn ?? today.subtract(const Duration(days: 3)),
        stock: 10,
      );

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.build(LbPalette.kum, Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('the alarm records the answer, leaves, and gives up the lock screen', (tester) async {
    setUpTest(tester);
    await db.into(db.localMedications).insert(vitamin().toRow(1));
    final dose = ScheduledDose(vitamin(), today.add(const Duration(hours: 9)));
    final router = buildRouter(initialLocation: '${AppRoutes.alarm}/${Uri.encodeComponent(dose.id)}');
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.build(LbPalette.kum, Brightness.light), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('D vitamini'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(platformCalls.where((c) => c.method == 'setShowOverLockScreen').map((c) => c.arguments['enabled']), [true]);

    await tester.tap(find.text('Aldım'));
    await tester.pumpAndSettle();

    final log = await db.select(db.localDoseLogs).getSingle();
    expect(log.id, dose.id);
    expect(log.status, 'taken');
    expect((await db.select(db.localMedications).getSingle()).stock, 9);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.meds);
    expect(platformCalls.where((c) => c.method == 'setShowOverLockScreen').last.arguments['enabled'], false);
    await unmount(tester);
  });

  testWidgets('a new medication needs a name and is saved locally', (tester) async {
    setUpTest(tester);
    await pumpPage(tester, const MedEditPage());

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('İlaç adı gerekli'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'İlaç adı'), 'Parol');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = Medication.fromRow(await db.select(db.localMedications).getSingle());
    expect(saved.name, 'Parol');
    expect(saved.schedule, const MedSchedule.daily(['09:00']));
    expect(saved.startsOn, today);
    expect(find.text('aç'), findsOneWidget, reason: 'the form closes after saving');
    await unmount(tester);
  });

  testWidgets('finishing a course ends it yesterday; restarting opens a new one today', (tester) async {
    setUpTest(tester);
    await db.into(db.localMedications).insert(vitamin().toRow(1));
    await pumpPage(tester, const MedDetailPage(medicationId: 'm1'));

    await tester.tap(find.text('Bitir (alarmlar susar)'));
    await tester.pumpAndSettle();
    var row = Medication.fromRow(await db.select(db.localMedications).getSingle());
    expect(row.endsOn, today.subtract(const Duration(days: 1)));
    expect(row.active, isTrue);

    await tester.tap(find.text('Yeniden başlat'));
    await tester.pumpAndSettle();
    row = Medication.fromRow(await db.select(db.localMedications).getSingle());
    expect(row.endsOn, isNull);
    expect(row.startsOn, today);
    await unmount(tester);
  });
}
