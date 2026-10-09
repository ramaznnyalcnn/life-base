import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData build(LbPalette palette, Brightness brightness, {bool reduceMotion = false}) {
    final t = LbTokens.resolve(palette, brightness, reduceMotion: reduceMotion);
    final scheme = ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: t.brightness,
    ).copyWith(
      primary: t.accent,
      onPrimary: t.onAccent,
      surface: t.base,
      onSurface: t.onBase,
      onSurfaceVariant: t.muted,
      error: t.danger,
      surfaceContainerLowest: t.base,
      surfaceContainerLow: t.base,
      surfaceContainer: t.base,
      surfaceContainerHigh: t.sunken,
      surfaceContainerHighest: t.sunken,
    );
    final transitions = reduceMotion ? const _FadePageTransitionsBuilder() : const _CalmSharedAxisBuilder();
    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.base,
      canvasColor: t.base,
      fontFamily: 'Manrope',
      extensions: [t],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values) platform: transitions,
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: t.base,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.onBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: t.onBase,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.base,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LbTokens.radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.sunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.base,
        selectedColor: t.accent.withValues(alpha: .18),
        side: BorderSide(color: t.shade.withValues(alpha: .6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LbTokens.radiusSmall)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LbTokens.radiusSmall)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LbTokens.radiusSmall)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.base,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.base,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: t.shade.withValues(alpha: .5), space: 1),
    );
  }
}

/// In-tab page change: a short horizontal slide with a cross-fade, so one
/// screen hands over to the next rather than shoving it away.
class _CalmSharedAxisBuilder extends PageTransitionsBuilder {
  const _CalmSharedAxisBuilder();

  @override
  Duration get transitionDuration => LbTokens.motion;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      );
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => LbTokens.motionShort;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(opacity: animation, child: child);
}
