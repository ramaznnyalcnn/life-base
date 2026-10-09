import 'package:flutter/material.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';

/// Placeholder until this module's own form lands.
class CalendarAddPage extends StatelessWidget {
  const CalendarAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return AddPageScaffold(
      title: 'Yeni etkinlik',
      body: ListView(padding: const EdgeInsets.all(20), children: [
        NeuSurface(
          child: Row(children: [
            Icon(Icons.event_rounded, color: t.muted),
            const SizedBox(width: 14),
            Expanded(child: Text('Başlık, not, tekrar ve sınırsız hatırlatma bu sayfada girilecek (3. aşama).', style: TextStyle(color: t.muted))),
          ]),
        ),
      ]),
    );
  }
}
