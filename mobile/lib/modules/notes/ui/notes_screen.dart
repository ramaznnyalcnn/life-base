import 'package:flutter/material.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return ModuleScaffold(
      module: LbModule.notes,
      title: 'Notlar',
      body: ListView(padding: moduleListPadding(context), children: [
        NeuSurface(
          child: Row(children: [
            Icon(Icons.sticky_note_2_rounded, color: t.module(LbModule.notes), size: 32),
            const SizedBox(width: 14),
            Expanded(child: Text('Notlar ve listeler burada olacak.', style: TextStyle(color: t.muted))),
          ]),
        ),
      ]),
    );
  }
}
