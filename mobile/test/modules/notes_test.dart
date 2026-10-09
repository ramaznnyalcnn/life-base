import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/calendar/calendar_event.dart';
import 'package:lifebase_mobile/core/calendar/events_repository.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/notes/date_hint.dart';
import 'package:lifebase_mobile/core/notes/note.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/modules/notes/data/notes_repository.dart';
import 'package:lifebase_mobile/modules/notes/ui/note_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('repository', () {
    late AppDatabase db;
    late NotesRepository notes;
    late EventsRepository events;
    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
      events = EventsRepository(db);
      notes = NotesRepository(db, events: events, defaultReminders: () => const [ReminderSpec.before(Duration(minutes: 30))]);
    });
    tearDown(() => db.close());

    test('a note becomes a linked event; edits follow it; unlinking can delete it', () async {
      const note = Note(id: 'n1', body: 'yarın 15:00 dişçi\ndolgu kontrolü');
      final now = DateTime(2026, 10, 9, 10);
      final linked = await notes.addToCalendar(note, findDateHint(note.body, now)!);

      final event = (await events.find(linked.eventId!))!;
      expect(event.title, 'dişçi');
      expect(event.startsAt, DateTime(2026, 10, 10, 15));
      expect(event.endsAt, DateTime(2026, 10, 10, 16));
      expect(event.reminders, const [ReminderSpec.before(Duration(minutes: 30))]);
      expect(Note.fromRow(await db.select(db.localNotes).getSingle()).eventId, event.id);

      await notes.save(linked.copyWith(body: 'yarın 15:00 dişçi\ndolgu kontrolü, sigorta kartı'));
      expect((await events.find(event.id))!.notes, contains('sigorta kartı'));

      await notes.removeFromCalendar(linked, deleteEvent: true);
      expect(await events.find(event.id), isNull);
      expect(Note.fromRow(await db.select(db.localNotes).getSingle()).eventId, isNull);
    });

    test('deleting a note deletes its lines too, and both are queued for sync', () async {
      await notes.save(const Note(id: 'l', kind: NoteKind.list, title: 'Market'));
      await notes.saveItem(const NoteItem(id: 'i1', noteId: 'l', content: 'Süt', position: 1));
      await notes.delete('l');
      final item = await db.select(db.localNoteItems).getSingle();
      expect(item.deletedAtMs, isNotNull);
      expect(item.dirty, isTrue);
    });

    test('lines order open first, ticked after', () {
      final ordered = orderedItems(const [
        NoteItem(id: 'a', noteId: 'l', content: 'a', position: 2),
        NoteItem(id: 'b', noteId: 'l', content: 'b', position: 1, done: true),
        NoteItem(id: 'c', noteId: 'l', content: 'c', position: 1),
      ]);
      expect(ordered.map((i) => i.id), ['c', 'a', 'b']);
    });
  });

  testWidgets('typing a date offers "Takvime ekle", which makes the event', (tester) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.lifebase.mobile/platform'),
      (call) async => call.method == 'googleStatus' ? <String, Object?>{} : <Object?>[],
    );
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: const NoteEditorPage()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Dişçi');
    await tester.enterText(find.byType(TextField).at(1), 'yarın 15:00 kontrol');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final chip = find.textContaining('Takvime ekle: Yarın 15:00');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    final event = await db.select(db.localEvents).getSingle();
    expect(event.title, 'Dişçi');
    expect(find.textContaining('Takvimde: Yarın 15:00'), findsOneWidget);
    final note = await db.select(db.localNotes).getSingle();
    expect(note.eventId, event.id);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
