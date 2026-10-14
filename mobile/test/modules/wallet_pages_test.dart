import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import 'package:lifebase_mobile/modules/wallet/ui/all_entries_page.dart';
import 'package:lifebase_mobile/modules/wallet/ui/wallet_analysis_page.dart';
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

  testWidgets('recent movements fade after three; a tap lists them all, and the analysis opens below', (tester) async {
    await pump(tester, const SizedBox());
    await db.into(db.walletAccounts).insert(WalletAccountsCompanion.insert(id: 'bank', ownerId: 1, name: 'Banka', type: 'bank', balanceCents: 0));
    final today = DateTime.now();
    for (var i = 0; i < 8; i++) {
      await db.into(db.walletTransactions).insert(WalletTransactionsCompanion.insert(
            id: 't$i',
            accountId: 'bank',
            kind: 'expense',
            amountCents: (i + 1) * 1000,
            occurredAt: DateTime(today.year, today.month, today.day, 8, i).toUtc(),
            createdBy: 1,
            category: Value(i.isEven ? 'Market' : 'Yemek'),
          ));
    }
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: const WalletScreen()),
    ));
    await tester.pumpAndSettle();

    // Six of eight rows show; the last three are faded.
    final faded = find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1);
    expect(faded, findsNWidgets(3));
    final fadedRow = find.ancestor(of: faded.first, matching: find.byType(GestureDetector)).first;
    await tester.ensureVisible(fadedRow);
    await tester.pumpAndSettle();
    await tester.tap(fadedRow);
    await tester.pumpAndSettle();
    expect(find.byType(AllEntriesPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Detaylı analiz'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detaylı analiz'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletAnalysisPage), findsOneWidget);
    expect(find.text('En büyük harcamalar'), findsOneWidget);
    await unmount(tester);
  });

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

  testWidgets('a monthly payment is planned from the wallet and paid with one tap', (tester) async {
    await pump(tester, const SizedBox());
    await db.into(db.walletAccounts).insert(WalletAccountsCompanion.insert(
          id: 'bank', ownerId: 1, name: 'Maaş hesabı', type: 'bank', balanceCents: 2000000));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: const WalletScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('düzenli ödemeleri ekle'), findsOneWidget);
    await tester.tap(find.byTooltip('Planlı ödeme ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ne ödenecek?'), 'Kira');
    await tester.enterText(find.widgetWithText(TextField, 'Tutar'), '15.000');
    await tester.tap(find.text('Market'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final [saved] = await outbox();
    expect(saved.key, 'wallet.payment.save');
    expect((saved.values['title'], saved.values['amount'], saved.values['kind']), ('Kira', '15000.00', 'expense'));
    expect((saved.values['account_id'], saved.values['category_id'], saved.values['repeat_monthly']), ('bank', 3, true));
    expect(find.text('Kira'), findsOneWidget);
    expect(find.textContaining('Yarın · ₺15.000,00 · her ay'), findsOneWidget);

    await tester.tap(find.text('Ödendi'));
    await tester.pumpAndSettle();
    expect(find.text('Kira ödendi mi?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Ödendi')));
    await tester.pumpAndSettle();

    final ops = await outbox();
    expect(ops.last.key, 'wallet.payment.complete');
    expect(ops.last.values['id'], saved.values['id']);
    // The expense shows at once and the payment moves to next month.
    expect(find.text('₺5.000,00'), findsWidgets);
    expect(find.textContaining('Yarın'), findsNothing);
    await unmount(tester);
  });
}
