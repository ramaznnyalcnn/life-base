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
import 'package:lifebase_mobile/core/wallet/card_secrets.dart';
import 'package:lifebase_mobile/core/wallet/wallet_models.dart';
import 'package:lifebase_mobile/core/wallet/wallet_outbox.dart';
import 'package:drift/drift.dart' show Value;
import 'package:lifebase_mobile/modules/wallet/ui/account_detail_page.dart';
import 'package:lifebase_mobile/modules/wallet/ui/account_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryCardSecrets implements CardSecretsStore {
  final saved = <String, CardSecrets>{};

  @override
  bool get supported => true;
  @override
  Future<bool> has(String accountId) async => saved.containsKey(accountId);
  @override
  Future<CardSecrets?> read(String accountId) async => saved[accountId];
  @override
  Future<void> write(String accountId, CardSecrets? secrets) async =>
      secrets == null ? saved.remove(accountId) : saved[accountId] = secrets;
  @override
  Future<void> clear() async => saved.clear();
}

class FakeUnlocker implements CardUnlocker {
  String? answer;
  int asked = 0;

  @override
  Future<String?> unlock(String reason) async {
    asked++;
    return answer;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  late AppDatabase db;
  late MemoryCardSecrets secrets;
  late FakeUnlocker unlocker;
  late List<bool> secureCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secrets = MemoryCardSecrets();
    unlocker = FakeUnlocker();
    secureCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.lifebase.mobile/platform'),
      (call) async {
        if (call.method == 'setSecure') secureCalls.add((call.arguments as Map)['enabled'] as bool);
        return null;
      },
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
    await db.into(db.walletAccounts).insert(WalletAccountsCompanion.insert(
          id: 'card', ownerId: 1, name: 'Bonus', type: 'credit_card', balanceCents: 0, last4: const Value('9012')));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        cardSecretsStoreProvider.overrideWithValue(secrets),
        cardUnlockerProvider.overrideWithValue(unlocker),
      ],
      child: MaterialApp(theme: AppTheme.build(LbPalette.kum, Brightness.light), home: home),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  test('numbers are grouped like on the card', () {
    expect(const CardSecrets(number: '4543123456789012').groupedNumber, '4543 1234 5678 9012');
    expect(const CardSecrets(number: '378282246310005').groupedNumber, '3782 822463 10005');
    expect(const CardSecrets(number: '4543123456789012').last4, '9012');
  });

  testWidgets('card details are kept on the device; only the last four digits are sent', (tester) async {
    // Opened from a page, as in the app, so saving can pop back.
    await pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AccountEditPage(initialType: AccountType.creditCard))),
        child: const Text('aç'),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    Future<void> type(String label, String text) async {
      final field = find.widgetWithText(TextField, label);
      await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, text);
    }

    await type('Kart adı (örn. Bonus)', 'Axess');
    await type('Kart numarası', '4543 1234 5678 4321');
    await type('SKT', '13/29');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('SKT AA/YY biçiminde olmalı'), findsOneWidget);

    await type('SKT', '12/29');
    await type('CVV', '123');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final [op] = [for (final row in await db.select(db.walletOutbox).get()) WalletOp.fromRow(row)];
    final sent = jsonEncode(op.envelope);
    expect((op.values['account']! as Map)['last4'], '4321');
    expect(sent, isNot(contains('4543')));
    expect(sent, isNot(contains('123')));
    final id = (op.values['account']! as Map)['id']! as String;
    expect(secrets.saved[id], const CardSecrets(number: '4543123456784321', expiry: '12/29', cvv: '123'));
    expect(secureCalls, isNotEmpty, reason: 'no screenshots while card details are typed');
    expect(secureCalls.first, isTrue);
    await unmount(tester);
    await tester.idle();
    expect(secureCalls.last, isFalse, reason: 'screenshots allowed again after leaving');
  });

  testWidgets('the back opens only after unlocking and closes by itself', (tester) async {
    secrets.saved['card'] = const CardSecrets(number: '4543123456789012', expiry: '08/28', cvv: '987', holder: 'AYSE YILMAZ');
    await pump(tester, const AccountDetailPage(accountId: 'card'));

    unlocker.answer = 'Vazgeçildi.';
    await tester.tap(find.text('•••• 9012'));
    await tester.pumpAndSettle();
    expect(find.text('Vazgeçildi.'), findsOneWidget);
    expect(find.text('4543 1234 5678 9012'), findsNothing);

    unlocker.answer = null;
    await tester.tap(find.text('•••• 9012'));
    await tester.pumpAndSettle();
    expect(find.text('4543 1234 5678 9012'), findsOneWidget);
    expect(find.text('987'), findsOneWidget);
    expect(secureCalls, [true]);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('4543 1234 5678 9012'), findsNothing);
    expect(find.text('•••• 9012'), findsOneWidget);
    expect(secureCalls, [true, false]);
    await unmount(tester);
  });

  testWidgets('a card without details on this device says so instead of asking to unlock', (tester) async {
    await pump(tester, const AccountDetailPage(accountId: 'card'));
    await tester.tap(find.text('•••• 9012'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bu cihazda kayıtlı değil'), findsOneWidget);
    expect(unlocker.asked, 0);
    await unmount(tester);
  });
}
