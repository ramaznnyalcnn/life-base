import 'package:flutter/material.dart';

import 'tokens.dart';

/// Frame for a module's own add/edit page.
///
/// While [dirty], leaving (back button, gesture or close icon) first asks
/// whether to discard the unsaved input.
class AddPageScaffold extends StatelessWidget {
  const AddPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.dirty = false,
    this.onSave,
    this.saveLabel = 'Kaydet',
  });

  final String title;
  final Widget body;
  final bool dirty;
  final VoidCallback? onSave;
  final String saveLabel;

  static Future<bool> confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vazgeçilsin mi?'),
          content: const Text('Girdiğin bilgiler kaydedilmedi.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Devam et')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Vazgeç')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kapat',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(title),
          actions: [
            if (onSave != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(onPressed: onSave, child: Text(saveLabel)),
              ),
          ],
        ),
        body: DefaultTextStyle.merge(style: TextStyle(color: t.onBase), child: body),
      ),
    );
  }
}
