import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/core/storage/app_database.dart';
import 'package:lifebase_mobile/core/wallet/wallet_outbox.dart';
import 'package:lifebase_mobile/modules/wallet/ui/entry_page.dart';
import 'package:lifebase_mobile/modules/wallet/ui/wallet_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.lifebase.mobile/platform'),
      (call) async => call.method == 'googleStatus' ? <String, Object?>{} : <Object?>[],
    );
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSyncState('wallet.members', jsonEncode([
      {'user_id': 1, 'name': 'Ali', 'is_me': true},
    ]));
    await db.setSyncState('wallet.categories', jsonEncode([
      {'id': 3, 'name': 'Market', 'kind': 'expense'},
      {'id': 9, 'name': 'Maas', 'kind': 'income'},
    ]));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: home),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<List<WalletOp>> outbox() async => [for (final row in await db.select(db.walletOutbox).get()) WalletOp.fromRow(row)];

  testWidgets('a card added offline shows at once, marked as an estimate', (tester) async {
    await pump(tester, const WalletScreen());

    await tester.tap(find.text('Hesap veya kart ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kredi kartı'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kart adı (örn. Bonus)'), 'Bonus');
    await tester.enterText(find.widgetWithText(TextField, 'Güncel borç'), '1500');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final [op] = await outbox();
    expect(op.key, 'wallet.account.save');
    final account = op.values['account']! as Map;
    expect(account['type'], 'credit_card');
    expect(account['opening_balance'], '-1500.00');

    expect(find.text('tahmini'), findsOneWidget);
    expect(find.text('-₺1.500,00'), findsOneWidget);
    expect(find.text('Bonus'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('an expense is typed on the keypad and queued with its reason', (tester) async {
    await pump(tester, const SizedBox());
    await db.into(db.walletAccounts).insert(WalletAccountsCompanion.insert(
          id: 'bank', ownerId: 1, name: 'Maaş hesabı', type: 'bank', balanceCents: 100000));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: const EntryPage()),
    ));
    await tester.pumpAndSettle();

    for (final key in ['1', '2', '5', ',', '5']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(find.text('₺125,5'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Market'));
    await tester.enterText(find.widgetWithText(TextField, 'örn. Haftalık alışveriş'), 'Haftalık alışveriş');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final [op] = await outbox();
    expect(op.key, 'wallet.transaction.save');
    expect(op.values['amount'], '125.50');
    expect(op.values['account_id'], 'bank', reason: 'the only account is picked by default');
    expect(op.values['category_id'], 3);
    expect(op.values['note'], 'Haftalık alışveriş');
    expect(op.accountKeys, ['bank']);
    await unmount(tester);
  });
}
