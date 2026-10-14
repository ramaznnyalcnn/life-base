import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import 'wallet_format.dart';
import 'wallet_screen.dart';

/// Every movement of [accountIds], newest first, grouped by day.
class AllEntriesPage extends ConsumerStatefulWidget {
  const AllEntriesPage({super.key, required this.accountIds});

  final Set<String> accountIds;

  @override
  ConsumerState<AllEntriesPage> createState() => _AllEntriesPageState();
}

class _AllEntriesPageState extends ConsumerState<AllEntriesPage> {
  int _shown = 60;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final now = DateTime.now();
    final entries = entriesOf(wallet, widget.accountIds, now);
    final today = DateUtils.dateOnly(now);

    final rows = <Widget>[];
    DateTime? day;
    for (final entry in entries.take(_shown)) {
      final entryDay = DateUtils.dateOnly(entry.at);
      if (entryDay != day) {
        day = entryDay;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(dayLabel(entryDay, today), style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        ));
      }
      rows.add(EntryTile(entry: entry, wallet: wallet));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hareketler')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        if (entries.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text('Henüz hareket yok.', style: TextStyle(color: t.muted))),
        ...rows,
        if (entries.length > _shown) TextButton(onPressed: () => setState(() => _shown += 60), child: const Text('Daha fazla göster')),
      ]),
    );
  }
}
