import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/meds/medication.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/core/routes.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/modules/calendar/ui/event_detail_page.dart';
import 'package:lifebase_mobile/modules/today/data/today_controller.dart';
import 'package:lifebase_mobile/shell/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.lifebase.mobile/platform'),
      (call) async => call.method == 'googleStatus' ? <String, Object?>{} : <Object?>[],
    );
  });

  testWidgets('Bugün puts the late dose first, takes it, and opens events in its own stack', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final day = DateUtils.dateOnly(DateTime.now());
    final now = day.add(const Duration(hours: 9, minutes: 5));
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.localMedications).insert(Medication(
      id: 'parol',
      name: 'Parol',
      schedule: const MedSchedule.daily(['09:00']),
      startsOn: day,
      doseAmount: 1,
      doseUnit: 'tablet',
    ).toRow(0));
    await db.into(db.localEvents).insert(CalendarEvent(
      id: 'meet',
      title: 'Toplantı',
      startsAt: day.add(const Duration(hours: 14)),
      endsAt: day.add(const Duration(hours: 15)),
    ).toRow(0));

    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        minuteClockProvider.overrideWith((ref) => Stream.value(now)),
      ],
      child: MaterialApp.router(theme: AppTheme.build(LbPalette.kum, Brightness.light), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SIRADAKİ'), findsOneWidget);
    expect(find.text('5 dk geçti'), findsOneWidget);
    expect(find.textContaining('Günaydın'), findsOneWidget);

    await tester.tap(find.text('Aldım'));
    await tester.pump(const Duration(seconds: 1));
    final log = await tester.runAsync(() => db.select(db.localDoseLogs).getSingle());
    await tester.pump(const Duration(seconds: 1));
    expect(log!.status, 'taken');
    expect(find.text('4 sa 55 dk sonra'), findsOneWidget, reason: 'the meeting is next now');

    await tester.tap(find.text('Toplantı').last);
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailPage), findsOneWidget);
    expect(find.text('SIRADAKİ'), findsNothing, reason: 'the event opens over Bugün');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailPage), findsNothing);
    expect(find.text('SIRADAKİ'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.today);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
