import 'package:flutter/material.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';

/// Placeholder until this module's own form lands.
class MedsAddPage extends StatelessWidget {
  const MedsAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return AddPageScaffold(
      title: 'Yeni ilaç',
      body: ListView(padding: const EdgeInsets.all(20), children: [
        NeuSurface(
          child: Row(children: [
            Icon(Icons.medication_rounded, color: t.muted),
            const SizedBox(width: 14),
            Expanded(child: Text('Doz, sıklık, stok ve alarm ayarları bu sayfada girilecek (4. aşama).', style: TextStyle(color: t.muted))),
          ]),
        ),
      ]),
    );
  }
}
