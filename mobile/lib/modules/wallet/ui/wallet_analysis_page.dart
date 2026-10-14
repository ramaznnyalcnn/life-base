import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import 'spending_summary_section.dart';

/// The full spending analysis of [accountIds]: periods, totals, categories,
/// months, people and the biggest expenses.
class WalletAnalysisPage extends ConsumerWidget {
  const WalletAnalysisPage({super.key, required this.accountIds});

  final Set<String> accountIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    return Scaffold(
      appBar: AppBar(title: const Text('Analiz')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        SpendingSummarySection(accountIds: accountIds, wallet: wallet, now: DateTime.now(), mode: SummaryMode.wallet),
      ]),
    );
  }
}
