import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/module_scaffold.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';

void main() {
  testWidgets('an add page opened from the button can close with a result', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(LbPalette.kum, Brightness.light),
      home: ModuleScaffold(
        module: LbModule.meds,
        title: 'İlaç',
        addLabel: 'İlaç',
        addPageBuilder: (context) => Scaffold(
          body: TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Kaydet')),
        ),
        body: const SizedBox(),
      ),
    ));
    await tester.tap(find.text('İlaç').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kaydet'), findsNothing);
  });
}
