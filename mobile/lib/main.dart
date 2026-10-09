import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/design_system/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final appearance = await AppearanceController.load();
  runApp(ProviderScope(
    overrides: [initialAppearanceProvider.overrideWithValue(appearance)],
    child: const LifeBaseApp(),
  ));
}
