import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/reminder_defaults.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/modules/calendar/ui/event_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('a new event is saved locally with the default reminders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.build(LbPalette.kum, Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EventEditPage(day: DateTime(2099, 10, 12)))),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // Saving without a title is refused.
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('Başlık gerekli'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Diş hekimi');
    await tester.enterText(find.widgetWithText(TextField, 'Not (isteğe bağlı)'), 'Kontrol');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = CalendarEvent.fromRow(await db.select(db.localEvents).getSingle());
    expect(saved.title, 'Diş hekimi');
    expect(saved.notes, 'Kontrol');
    expect(saved.startsAt, DateTime(2099, 10, 12, 9));
    expect(saved.endsAt, DateTime(2099, 10, 12, 10));
    expect(saved.reminders, DefaultReminders.fallback);
    expect(find.byType(EventEditPage), findsNothing);
  });
}
