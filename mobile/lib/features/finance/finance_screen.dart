import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final financeProvider = FutureProvider<({Map<String, Object?> summary, List<Map<String, Object?>> accounts})>((ref) async {
  final api = ref.watch(apiClientProvider)!;
  final values = await Future.wait([api.walletSummary(), api.accounts()]);
  return (summary: values[0] as Map<String, Object?>, accounts: values[1] as List<Map<String, Object?>>);
});

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(financeProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('Finans özeti alınamadı.')),
        data: (data) {
          final total = data.summary['total_balance'] ?? data.summary['net_worth'] ?? '0';
          return RefreshIndicator(
            onRefresh: () => ref.refresh(financeProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Card(
                color: AppTheme.finance.withValues(alpha: .14),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TOPLAM BAKİYE', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_money(total), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.finance)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text('Hesaplar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...data.accounts.map((account) => Card(child: ListTile(
                    minTileHeight: 72,
                    leading: CircleAvatar(backgroundColor: AppTheme.finance.withValues(alpha: .16), child: const Icon(Icons.account_balance_wallet, color: AppTheme.finance)),
                    title: Text(account['name'] as String? ?? 'Hesap'),
                    subtitle: Text(_type(account['type'] as String?)),
                    trailing: Text(_money(account['balance']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ))),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Planlı ödemeler'),
              ),
            ]),
          );
        },
      );

  static String _money(Object? value) {
    final amount = num.tryParse('$value') ?? 0;
    return NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(amount);
  }

  static String _type(String? value) => switch (value) {
        'cash' => 'Nakit', 'bank' => 'Banka', 'credit_card' => 'Kredi kartı', _ => 'Hesap',
      };
}
