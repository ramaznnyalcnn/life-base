import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/providers.dart';
import 'wallet_add_page.dart';

final financeProvider = FutureProvider<({Map<String, Object?> summary, List<Map<String, Object?>> accounts})>((ref) async {
  final api = ref.watch(apiClientProvider)!;
  final values = await Future.wait([api.walletSummary(), api.accounts()]);
  return (summary: values[0] as Map<String, Object?>, accounts: values[1] as List<Map<String, Object?>>);
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    return ModuleScaffold(
      module: LbModule.wallet,
      title: 'Cüzdan',
      addLabel: 'Hareket',
      addPageBuilder: (context) => const WalletAddPage(),
      body: ref.watch(financeProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Finans özeti alınamadı.', style: TextStyle(color: t.muted))),
            data: (data) {
              final total = data.summary['total_balance'] ?? data.summary['net_worth'] ?? '0';
              return RefreshIndicator(
                onRefresh: () => ref.refresh(financeProvider.future),
                child: ListView(padding: moduleListPadding(context, hasAddButton: true), children: [
                  NeuSurface(
                    padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TOPLAM BAKİYE',
                          style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 12, color: t.module(LbModule.wallet))),
                      const SizedBox(height: 8),
                      Text(_money(total),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: t.onBase)),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  Text('Hesaplar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: t.onBase)),
                  const SizedBox(height: 12),
                  for (final account in data.accounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NeuSurface(
                        depth: 4,
                        radius: LbTokens.radiusSmall + 4,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Icon(_icon(account['type'] as String?), color: t.module(LbModule.wallet)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(account['name'] as String? ?? 'Hesap',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
                              Text(_type(account['type'] as String?), style: TextStyle(color: t.muted, fontSize: 12)),
                            ]),
                          ),
                          Text(_money(account['balance']), style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase)),
                        ]),
                      ),
                    ),
                ]),
              );
            },
          ),
    );
  }

  static String _money(Object? value) {
    final amount = num.tryParse('$value') ?? 0;
    return NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(amount);
  }

  static IconData _icon(String? value) => switch (value) {
        'cash' => Icons.payments_rounded,
        'credit_card' => Icons.credit_card_rounded,
        _ => Icons.account_balance_rounded,
      };

  static String _type(String? value) => switch (value) {
        'cash' => 'Nakit',
        'bank' => 'Banka',
        'credit_card' => 'Kredi kartı',
        _ => 'Hesap',
      };
}
