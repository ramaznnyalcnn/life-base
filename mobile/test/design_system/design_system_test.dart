import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/design_system/add_page_scaffold.dart';
import 'package:lifebase_mobile/core/design_system/app_theme.dart';
import 'package:lifebase_mobile/core/design_system/appearance.dart';
import 'package:lifebase_mobile/core/design_system/tokens.dart';
import 'package:lifebase_mobile/core/providers.dart';
import 'package:lifebase_mobile/modules/account/ui/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('appearance choices persist across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(appearanceProvider.notifier);

    await controller.setPalette(LbPalette.okyanus);
    await controller.setMode(ThemeMode.dark);
    await controller.setReduceMotion(true);

    final restored = await AppearanceController.load();
    expect(restored, const Appearance(palette: LbPalette.okyanus, mode: ThemeMode.dark, reduceMotion: true));
  });

  test('Gece is always dark, other palettes follow the requested brightness', () {
    expect(LbTokens.resolve(LbPalette.gece, Brightness.light).brightness, Brightness.dark);
    expect(LbTokens.resolve(LbPalette.kum, Brightness.light).brightness, Brightness.light);
    expect(LbTokens.resolve(LbPalette.kum, Brightness.dark).brightness, Brightness.dark);
  });

  test('text colours keep WCAG AA contrast on every surface', () {
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
    }

    for (final palette in LbPalette.values) {
      for (final brightness in Brightness.values) {
        final t = LbTokens.resolve(palette, brightness);
        expect(ratio(t.onBase, t.base), greaterThanOrEqualTo(4.5), reason: '$palette $brightness onBase');
        expect(ratio(t.muted, t.base), greaterThanOrEqualTo(4.5), reason: '$palette $brightness muted');
        for (final module in LbModule.values) {
          expect(ratio(t.onAccent, t.module(module)), greaterThanOrEqualTo(4.5), reason: '$palette $brightness $module button');
        }
      }
    }
  });

  testWidgets('unsaved add page asks before discarding', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(LbPalette.kum, Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const AddPageScaffold(title: 'Yeni', dirty: true, body: SizedBox())),
          ),
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Vazgeçilsin mi?'), findsOneWidget);

    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni'), findsOneWidget);

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni'), findsNothing);
  });

  testWidgets('switching through every palette and mode animates without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [outstandingOperationsProvider.overrideWith((ref) => Stream.value(0))],
      child: Consumer(builder: (context, ref, _) {
        final a = ref.watch(appearanceProvider);
        return MaterialApp(
          theme: AppTheme.build(a.palette, Brightness.light),
          darkTheme: AppTheme.build(a.palette, Brightness.dark),
          themeMode: a.palette.darkOnly ? ThemeMode.dark : a.mode,
          home: const AccountScreen(),
        );
      }),
    ));
    await tester.pumpAndSettle();

    for (final palette in [...LbPalette.values.reversed, LbPalette.kum]) {
      await tester.tap(find.bySemanticsLabel('${palette.label} renk şeması'));
      // Pump through the middle of the theme/swatch animations.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
    }
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
