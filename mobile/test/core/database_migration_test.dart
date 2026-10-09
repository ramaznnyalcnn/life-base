import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('a schema v1 database upgrades to the latest schema and keeps its cache and queue', () async {
    final dir = await Directory.systemTemp.createTemp('lifebase-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/lifebase.sqlite');

    // The v1 schema as shipped before local-first tables existed.
    sqlite3.open(file.path)
      ..execute('CREATE TABLE cached_documents (key TEXT NOT NULL, payload TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (key));')
      ..execute('CREATE TABLE queued_operations (request_id TEXT NOT NULL, operation_key TEXT NOT NULL, '
          "payload TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending', conflict_payload TEXT NULL, "
          'attempts INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, PRIMARY KEY (request_id));')
      ..execute("INSERT INTO cached_documents VALUES ('agenda', '{}', 0);")
      ..execute('INSERT INTO queued_operations (request_id, operation_key, payload, created_at) '
          "VALUES ('r1', 'finance.expense.record', '{}', 0);")
      ..execute('PRAGMA user_version = 1;')
      ..dispose();

    final db = AppDatabase(executor: NativeDatabase(file));
    addTearDown(db.close);

    expect(await db.cached('agenda'), '{}');
    expect((await db.pending()).single.requestId, 'r1');
    expect(await db.select(db.localEvents).get(), isEmpty);
    expect(await db.select(db.walletOutbox).get(), isEmpty);
    expect(await db.select(db.walletAccounts).get(), isEmpty);
    expect(await db.select(db.localNotes).get(), isEmpty);
    await db.setSyncState('sync.cursor', '7');
    expect(await db.syncState('sync.cursor'), '7');
  });
}
