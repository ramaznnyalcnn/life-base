import 'package:flutter/material.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';

/// Placeholder until this module's own form lands.
class WalletAddPage extends StatelessWidget {
  const WalletAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return AddPageScaffold(
      title: 'Yeni hareket',
      body: ListView(padding: const EdgeInsets.all(20), children: [
        NeuSurface(
          child: Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: t.muted),
            const SizedBox(width: 14),
            Expanded(child: Text('Gider, gelir, transfer ve kart ödemesi bu sayfada girilecek (5. aşama).', style: TextStyle(color: t.muted))),
          ]),
        ),
      ]),
    );
  }
}
