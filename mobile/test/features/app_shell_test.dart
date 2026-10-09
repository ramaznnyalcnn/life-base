import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/features/shell/app_shell.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('primary navigation contains the five daily-use destinations', (tester) async {
    await initializeDateFormatting('tr_TR');
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AppShell()),
    ));
    await tester.pump();

    for (final label in ['Bugün', 'Takvim', 'Ekle', 'Finans', 'Sağlık']) {
      expect(find.text(label), findsWidgets);
    }
  });
}
